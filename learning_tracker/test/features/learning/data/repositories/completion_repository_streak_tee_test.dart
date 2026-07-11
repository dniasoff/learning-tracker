/// Phase 1 — streak event tee.
///
/// The streak-event tee in [CompletionRepositoryImpl._appendStreakEvent] used
/// to write only into the local `streak_events` Drift table. Day-to-day
/// streaks never replicated to Firestore and a second device saw a frozen
/// streak. The Phase 1 fix routes the streak event through the outbox
/// alongside the local insert — `markComplete` now enqueues a `streak` outbox
/// row whose payload matches `streak_event_codec.dart`'s shape.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late UserDatabase db;
  late int profileId;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    final profile = (await db.select(db.learnerProfiles).get()).first;
    profileId = profile.id;
    trackId = await seedTrack(
      db,
      profileId: profileId,
      curriculumId: 'mishnayos',
    );
    // One stage definition so the repository's stage validation passes.
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
  });

  tearDown(() async => db.close());

  test(
    'markComplete enqueues a streak outbox row alongside the local write',
    () async {
      // Real OutboxSyncWriteFacade — the test wants to assert the end-to-end
      // wiring (markComplete → _appendStreakEvent → outbox row inserted).
      final outboxFacade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        resolveProfileId: () => profileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
      );
      final contentRepo = _MockContentRepository();
      // Bookmark advancement path queries the content repo — returning an empty
      // list short-circuits cleanly.
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => const []);

      final repo = CompletionRepositoryImpl(
        database: db,
        syncEngine: null,
        outboxFacade: outboxFacade,
        contentRepository: contentRepo,
        activeProfileId: profileId,
      );

      await repo.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah_Berakhot_1',
          stageId: 1,
          trackType: 'personal',
        ),
      );

      // Local streak_events row landed.
      final localStreaks = await db.select(db.streakEvents).get();
      expect(
        localStreaks,
        hasLength(1),
        reason: 'local streak event must still be appended',
      );

      // Outbox streak row was also enqueued (closes the cloud-sync gap).
      final outboxStreakRows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.streak,
        profileId,
      );
      expect(
        outboxStreakRows,
        hasLength(1),
        reason: 'streak tee must enqueue an outbox row',
      );
      expect(
        outboxStreakRows.single.payload,
        contains('"event_type":"completion"'),
      );
    },
  );

  test(
    'markComplete with null outboxFacade still writes the local streak event',
    () async {
      // Local-born accounts get null. The tee must not crash.
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => const []);
      final repo = CompletionRepositoryImpl(
        database: db,
        syncEngine: null,
        outboxFacade: null,
        contentRepository: contentRepo,
        activeProfileId: profileId,
      );

      await repo.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah_Berakhot_1',
          stageId: 1,
          trackType: 'personal',
        ),
      );

      final localStreaks = await db.select(db.streakEvents).get();
      expect(localStreaks, hasLength(1));

      final outboxStreakRows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.streak,
        profileId,
      );
      expect(
        outboxStreakRows,
        isEmpty,
        reason: 'no facade → no outbox row, and no crash',
      );
    },
  );

  group('AUD-learning-06 — streak tee failure is logged, not swallowed', () {
    setUp(() => AppLogger.init());

    test('enqueueStreakPayload throwing is logged via AppLogger, and '
        'markComplete still succeeds', () async {
      final outboxFacade = _MockOutboxFacade();
      when(
        () => outboxFacade.enqueueStreakPayload(any()),
      ).thenThrow(Exception('simulated outbox enqueue failure'));

      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => const []);

      final repo = CompletionRepositoryImpl(
        database: db,
        syncEngine: null,
        outboxFacade: outboxFacade,
        contentRepository: contentRepo,
        activeProfileId: profileId,
      );

      // Must NOT throw: _appendStreakEvent runs inside markComplete's
      // transaction — a "telemetry tee" failure must never roll back or
      // fail the primary completion write.
      final result = await repo.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah_Berakhot_1',
          stageId: 1,
          trackType: 'personal',
        ),
      );
      expect(result.completion.sefariaRef, 'Mishnah_Berakhot_1');

      // The local streak_events insert happens before the failing outbox
      // enqueue, so it must still have landed.
      final localStreaks = await db.select(db.streakEvents).get();
      expect(
        localStreaks,
        hasLength(1),
        reason: 'local streak event must still be appended',
      );

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any((m) => m.contains('completion_streak_tee_failed')),
        isTrue,
        reason:
            'Expected the enqueueStreakPayload failure to be logged via '
            'AppLogger instead of silently dropped by catch (_) {}. '
            'Talker history: $history',
      );
    });
  });
}
