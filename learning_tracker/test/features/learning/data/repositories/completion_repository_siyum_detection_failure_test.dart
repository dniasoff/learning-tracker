/// AUD-learning-01 regression test — the unawaited
/// [CompletionDetectionService.checkAndRecordCompletions] call inside
/// [CompletionRepositoryImpl.markComplete] must not silently swallow a
/// failure.
///
/// `checkAndRecordCompletions` runs fire-and-forget (`unawaited(...)`) so a
/// slow siyum-detection scan never blocks the primary completion write. But
/// `completion_detection_service.dart` and `learning_ledger_repository_impl
/// .dart` contain zero try/catch blocks, so before this fix any exception
/// during detection (a closed DB mid profile-switch, a malformed content
/// lookup, …) became an unhandled Future error with no local diagnostic
/// trail and no signal that the B1 siyum credit for that unit was
/// permanently lost.
///
/// This test forces `getContentByRef` (the first call
/// `checkAndRecordCompletions` makes) to throw, then asserts:
///   (a) `markComplete` still returns successfully — the primary completion
///       write must never be blocked or failed by the detection side effect.
///   (b) The failure is logged via [AppLogger] instead of relying solely on
///       the global zone error handler to notice.
///
/// Red -> Green:
///   BEFORE the fix: the unawaited future had no `.catchError`, so nothing in
///   `completion_repository_impl.dart` logged the failure — this test's
///   AppLogger-history assertion failed (RED) even though `markComplete`
///   itself already returned cleanly.
///   AFTER the fix: the unawaited call chains `.catchError` and logs via
///   `AppLogger.instance.error(event: 'completion_siyum_detection_failed')`.
@Tags(['epic_3', 'b1_credit_policy'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  const oneLeafRef = 'Mishnah_Berakhot_1';

  late UserDatabase db;
  late int profileId;
  late _MockContentRepository contentRepo;
  late _MockOutboxFacade outboxFacade;
  late CompletionOrchestrator orchestrator;

  setUp(() async {
    // Fresh Talker per test so log history assertions never see a prior
    // test's entries (mirrors sign_in_verify_signout_throws_test.dart).
    AppLogger.init();

    db = createTestDatabase();
    await seedProfile(db);
    profileId = (await db.select(db.learnerProfiles).get()).first.id;

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

    await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: 'mishnayos',
        trackId: trackRow.id,
        stageOrder: 1,
        stageName: 'Stage 1',
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    );

    contentRepo = _MockContentRepository();
    outboxFacade = _MockOutboxFacade();

    // The detection service's very first call is getContentByRef — throwing
    // here simulates the "malformed content lookup" / closed-DB race the
    // finding describes, and is the simplest reliable way to make
    // checkAndRecordCompletions reject regardless of curriculum content.
    when(
      () => contentRepo.getContentByRef(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
      ),
    ).thenThrow(Exception('simulated content lookup failure'));

    // Bookmark advance (awaited, before the detection call) hits this path.
    when(
      () => contentRepo.getContentForCurriculum(any()),
    ).thenAnswer((_) async => []);

    when(() => outboxFacade.enqueueLedgerEntry(any())).thenAnswer((_) async {});

    final ledgerRepo = LearningLedgerRepositoryImpl(
      database: db,
      outboxFacade: outboxFacade,
      activeProfileId: profileId,
      activeProfileMode: ProfileMode.adult,
    );
    final stageRepo = StageDefinitionRepositoryImpl(
      stageDao: db.stageDao,
      completionDao: db.completionDao,
      pushStageDefinitions: null,
    );
    final repo = CompletionRepositoryImpl(
      database: db,
      activeProfileId: profileId,
    );
    final detectionService = CompletionDetectionService(
      completionRepository: repo,
      contentRepository: contentRepo,
      ledgerRepository: ledgerRepo,
      stageRepository: stageRepo,
    );
    // Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
    // owner decision 1): the unawaited-and-logged siyum dispatch under test
    // now lives in CompletionOrchestrator, not CompletionRepositoryImpl.
    orchestrator = CompletionOrchestrator(
      repository: repo,
      contentRepository: contentRepo,
      activeProfileId: profileId,
      completionDetectionService: detectionService,
    );
  });

  tearDown(() async => db.close());

  group('AUD-learning-01 — siyum detection failure is not silently lost', () {
    test(
      'markComplete returns successfully even when checkAndRecordCompletions throws',
      () async {
        // Must NOT throw — the fire-and-forget detection failure must never
        // fail (or block) the primary completion write.
        final result = await orchestrator.markComplete(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: oneLeafRef,
            stageId: 1,
            trackType: 'personal',
          ),
        );

        expect(result.completion.sefariaRef, oneLeafRef);
      },
    );

    test(
      'the swallowed detection failure is logged via AppLogger, not left silent',
      () async {
        await orchestrator.markComplete(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: oneLeafRef,
            stageId: 1,
            trackType: 'personal',
          ),
        );

        // Let the unawaited detection future run to completion and reject.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final history = AppLogger.instance.talker.history
            .map((e) => e.generateTextMessage())
            .toList();
        expect(
          history.any((m) => m.contains('completion_siyum_detection_failed')),
          isTrue,
          reason:
              'Expected the checkAndRecordCompletions failure to be logged '
              'via AppLogger (event: completion_siyum_detection_failed) '
              'instead of relying solely on the global zone error handler. '
              'Talker history: $history',
        );
      },
    );
  });
}
