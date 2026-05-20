/// H4 regression test (V3-W1).
///
/// Before the fix, `CompletionRepositoryImpl.markComplete` called
/// `CompletionDetectionService.checkAndRecordCompletions` unconditionally
/// even when `awardGamificationPoints = false` (lifetimeOnly source).
/// Per the B1 completion-credit policy, historical imports MUST NOT generate
/// siyum ledger entries.
///
/// The fix gates the call on `awardGamificationPoints`. This test asserts:
///   1. awardGamificationPoints=true  → detection runs   (happy path unchanged)
///   2. awardGamificationPoints=false → detection is NOT called (lifetimeOnly)
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late UserDatabase db;
  late int profileId;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    final profiles = await db.select(db.learnerProfiles).get();
    profileId = profiles.first.id;

    final trackRow = await db.into(db.curriculumTracks).insertReturning(
      CurriculumTracksCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        stateChangedAt: DateTime.utc(2026),
        activatedAt: DateTime.utc(2026),
      ),
    );
    trackId = trackRow.id;
  });

  tearDown(() async => db.close());

  // Helper: 2-leaf masechta so detection can potentially fire.
  List<ContentItem> twoLeaves() => [
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: 'Perek 1',
      displayNameHe: 'פרק א',
      displayNameEn: 'Chapter 1',
      sefariaRef: 'Mishnah_Berakhot_1',
      sortOrder: 0,
      isLeaf: true,
    ),
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      level3: 'Perek 2',
      displayNameHe: 'פרק ב',
      displayNameEn: 'Chapter 2',
      sefariaRef: 'Mishnah_Berakhot_2',
      sortOrder: 1,
      isLeaf: true,
    ),
  ];

  CompletionRepositoryImpl buildRepo({
    required _MockContentRepository contentRepo,
    required _MockFirestoreGateway gateway,
  }) {
    final mockGateway = gateway;
    when(
      () => mockGateway.pushLedgerEntry(
        profileId: any(named: 'profileId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});
    // Stub getContentForCurriculum used by bookmark advance path.
    when(
      () => contentRepo.getContentForCurriculum(any()),
    ).thenAnswer((_) async => []);

    final ledgerRepo = LearningLedgerRepositoryImpl(
      database: db,
      firestoreGateway: gateway,
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
    return CompletionRepositoryImpl(
      database: db,
      syncEngine: null,
      contentRepository: contentRepo,
      activeProfileId: profileId,
      completionDetectionService: detectionService,
    );
  }

  Future<void> seedOneStage() async {
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
  }

  group('H4 — awardGamificationPoints gate on CompletionDetectionService', () {
    test(
      'lifetimeOnly (awardGamificationPoints=false): does NOT create siyum',
      () async {
        final contentRepo = _MockContentRepository();
        final gateway = _MockFirestoreGateway();
        final leaves = twoLeaves();

        // Both leaves exist in content repo.
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

        await seedOneStage();

        final repo = buildRepo(contentRepo: contentRepo, gateway: gateway);

        // Mark both leaves complete with awardGamificationPoints=false
        // (lifetimeOnly / historical import).
        for (final leaf in leaves) {
          await repo.markComplete(
            CompletionRequest(
              curriculumId: 'mishnayos',
              sefariaRef: leaf.sefariaRef,
              stageId: 1,
              trackType: 'personal',
            ),
            awardGamificationPoints: false,
          );
        }

        // Wait for any fire-and-forget unawaited futures to settle.
        await Future<void>.delayed(Duration.zero);

        // H4 assertion: no siyum ledger entry was created.
        final ledgerEntries =
            await db.learningLedgerDao.getEntriesByProfile(profileId);
        expect(
          ledgerEntries,
          isEmpty,
          reason:
              'lifetimeOnly completions must not generate siyum ledger entries',
        );
      },
    );

    test(
      'live completion (awardGamificationPoints=true): DOES create siyum',
      () async {
        final contentRepo = _MockContentRepository();
        final gateway = _MockFirestoreGateway();
        final leaves = twoLeaves();

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

        await seedOneStage();

        final repo = buildRepo(contentRepo: contentRepo, gateway: gateway);

        // Mark both leaves complete with default awardGamificationPoints=true.
        for (final leaf in leaves) {
          await repo.markComplete(
            CompletionRequest(
              curriculumId: 'mishnayos',
              sefariaRef: leaf.sefariaRef,
              stageId: 1,
              trackType: 'personal',
            ),
          );
        }

        await Future<void>.delayed(Duration.zero);

        // Live completions SHOULD trigger detection → siyum entry.
        final ledgerEntries =
            await db.learningLedgerDao.getEntriesByProfile(profileId);
        expect(
          ledgerEntries,
          isNotEmpty,
          reason: 'live completions must generate siyum ledger entries',
        );
      },
    );
  });
}
