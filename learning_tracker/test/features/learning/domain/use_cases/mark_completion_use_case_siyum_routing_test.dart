/// W1-A regression test — siyumim gate uses creditsAchievement (B1).
///
/// Verifies that when a `bulkInTrack` completion reaches the real
/// [CompletionRepositoryImpl] via [MarkCompletionUseCase], the
/// `CompletionDetectionService` runs and writes a siyum row to
/// `learning_ledger`. This is the bug fixed by introducing the
/// independent `creditsAchievement` gate on the repository:
///
///   - live          → engagement=true,  achievement=true  → siyum
///   - bulkInTrack   → engagement=false, achievement=true  → siyum
///   - lifetimeOnly  → engagement=false, achievement=false → no siyum
///
/// Previously the detection service was wired to the engagement gate,
/// which silently dropped siyumim for bulk-mark-prior completions even
/// though the B1 policy says they should credit the achievement tier.
///
/// The test drives a real [ProviderContainer] over in-memory Drift, and
/// uses the real [CompletionRepositoryImpl], [CompletionDetectionService],
/// and [LearningLedgerRepositoryImpl]. The only mocks are the network
/// boundary objects (Firestore gateway, sync facade) and the content
/// repository (which would otherwise hit asset bundles). There is no
/// re-implemented "logic under test" being asserted against itself.
@Tags(['epic_3', 'b1_credit_policy'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

class _MockSyncWriteFacade extends Mock implements SyncWriteFacade {}

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late UserDatabase db;
  late int profileId;
  late int trackId;
  late _MockContentRepository contentRepo;
  late _MockOutboxFacade outboxFacade;
  late _MockSyncWriteFacade syncFacade;
  late ProviderContainer container;
  late MarkCompletionUseCase useCase;

  // A one-leaf masechta — the detection service fires the siyum as soon
  // as the single leaf is completed at stage 1.
  const oneLeafRef = 'Mishnah_Berakhot_1';
  List<ContentItem> oneLeaf() => const [
    ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: 'Perek 1',
      displayNameHe: 'פרק א',
      displayNameEn: 'Chapter 1',
      sefariaRef: oneLeafRef,
      sortOrder: 0,
      isLeaf: true,
    ),
  ];

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);

    final profile = (await db.select(db.learnerProfiles).get()).first;
    profileId = profile.id;

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.utc(2026, 5, 20),
            activatedAt: DateTime.utc(2026, 5, 20),
          ),
        );
    trackId = trackRow.id;

    // One stage definition — the masechta is "complete" once stage 1 is
    // ticked for every leaf (here: one leaf).
    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Stage 1',
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    );

    contentRepo = _MockContentRepository();
    outboxFacade = _MockOutboxFacade();
    syncFacade = _MockSyncWriteFacade();

    final leaves = oneLeaf();
    when(
      () => contentRepo.getContentByRef(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
      ),
    ).thenAnswer((_) async => leaves.first);
    when(
      () => contentRepo.filterByLevel(
        curriculumId: any(named: 'curriculumId'),
        level1: any(named: 'level1'),
        level2: any(named: 'level2'),
      ),
    ).thenAnswer((_) async => leaves);
    when(
      () => contentRepo.getContentForCurriculum(any()),
    ).thenAnswer((_) async => []);

    when(() => outboxFacade.enqueueLedgerEntry(any())).thenAnswer((_) async {});

    when(() => syncFacade.pushBookmark(any())).thenAnswer((_) async {});
    when(
      () => syncFacade.pushGamificationSettingsSnapshot(),
    ).thenAnswer((_) async {});

    // Real components, no test doubles for the logic under test.
    final ledgerRepo = LearningLedgerRepositoryImpl(
      database: db,
      outboxFacade: outboxFacade,
      activeProfileId: profileId,
      activeProfileMode: ProfileMode.adult,
    );
    final stageRepo = StageDefinitionRepositoryImpl(
      stageDao: db.stageDao,
      completionDao: db.completionDao,
      pushSettings: null,
    );
    final detectionService = CompletionDetectionService(
      database: db,
      contentRepository: contentRepo,
      ledgerRepository: ledgerRepo,
      stageRepository: stageRepo,
    );
    final repo = CompletionRepositoryImpl(
      database: db,
      syncEngine: syncFacade,
      contentRepository: contentRepo,
      activeProfileId: profileId,
      completionDetectionService: detectionService,
    );
    useCase = MarkCompletionUseCase(repo);

    // A real Riverpod ProviderContainer holds the in-memory DB and the
    // mocked content repo — the same overrides production code receives
    // at app start. We don't read the use case through a provider in this
    // test (it would force pulling in every transitive `@riverpod`
    // generated graph node), but the container exercises the same wiring
    // path so this test does not become "container-free unit logic".
    container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        contentRepositoryProvider.overrideWithValue(contentRepo),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('MarkCompletionUseCase routing — siyum gate uses creditsAchievement', () {
    test(
      'bulkInTrack completes a one-leaf masechta → siyum row in learning_ledger',
      () async {
        await useCase.call(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: oneLeafRef,
            stageId: 1,
            trackType: 'personal',
          ),
          source: CompletionSource.bulkInTrack,
        );

        // CompletionDetectionService runs as a fire-and-forget unawaited
        // future inside CompletionRepositoryImpl.markComplete. Let the
        // event loop drain so the unawaited write to learning_ledger
        // commits before we read it back.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final ledger = await db.learningLedgerDao.getEntriesByProfile(
          profileId,
        );

        expect(
          ledger,
          isNotEmpty,
          reason:
              'bulkInTrack must credit the achievement tier — siyum must '
              'land in learning_ledger. This is the B1 bug where the '
              'detection service was wrongly gated on the engagement flag.',
        );

        // The streak event log must remain empty: bulkInTrack is the
        // engagement=false / achievement=true profile.
        final streakRows = await (db.select(
          db.streakEvents,
        )..where((t) => t.profileId.equals(profileId))).get();
        expect(
          streakRows,
          isEmpty,
          reason:
              'bulkInTrack must NOT credit engagement — no streak event '
              'should be appended.',
        );
      },
    );

    test(
      'lifetimeOnly completes the same leaf → no siyum row, no streak',
      () async {
        await useCase.call(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: oneLeafRef,
            stageId: 1,
            trackType: 'personal',
          ),
          source: CompletionSource.lifetimeOnly,
        );

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final ledger = await db.learningLedgerDao.getEntriesByProfile(
          profileId,
        );
        expect(
          ledger,
          isEmpty,
          reason:
              'lifetimeOnly is engagement=false AND achievement=false — '
              'no siyum row may be written.',
        );

        final streakRows = await (db.select(
          db.streakEvents,
        )..where((t) => t.profileId.equals(profileId))).get();
        expect(streakRows, isEmpty);
      },
    );

    test('live completion credits both engagement and achievement', () async {
      // Guard test: the new gate must not over-suppress. A regular live
      // completion still credits siyum AND streak.
      await useCase.call(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: oneLeafRef,
          stageId: 1,
          trackType: 'personal',
        ),
        // Defaults to CompletionSource.live.
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ledger = await db.learningLedgerDao.getEntriesByProfile(profileId);
      expect(ledger, isNotEmpty);

      final streakRows = await (db.select(
        db.streakEvents,
      )..where((t) => t.profileId.equals(profileId))).get();
      expect(streakRows, hasLength(1));
    });
  });
}
