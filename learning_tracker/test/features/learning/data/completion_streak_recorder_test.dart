/// Tests for [DriftCompletionStreakRecorder] — the Drift-backed
/// [CompletionStreakPort] implementation.
///
/// Relocated from `completion_repository_streak_tee_test.dart` as part of
/// the completion-orchestrator lift (`docs/firestore-rewrite-map.md`, owner
/// decision 1): streak recording used to be
/// `CompletionRepositoryImpl._appendStreakEvent`, exercised only by driving
/// `markComplete` end-to-end. It is now this standalone, directly-injectable
/// class — see [CompletionStreakPort]'s doc comment for why the repository
/// no longer knows about streaks at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/learning/data/completion_streak_recorder.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/drift_memory.dart';

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

void main() {
  late UserDatabase db;
  late int profileId;

  setUp(() async {
    db = inMemoryDb();
    addTearDown(db.close);
    await seedProfile(db);
    final profile = (await db.select(db.learnerProfiles).get()).first;
    profileId = profile.id;
  });

  test('recordStudyDay writes a local streak_events row and enqueues an '
      'outbox streak row', () async {
    // Real OutboxSyncWriteFacade — the test wants to assert the end-to-end
    // wiring (recordStudyDay → local insert → outbox row inserted).
    final outboxFacade = OutboxSyncWriteFacade(
      outboxDao: db.outboxDao,
      database: db,
      resolveProfileId: () => profileId,
      clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
    );
    final recorder = DriftCompletionStreakRecorder(
      database: db,
      outboxFacade: outboxFacade,
    );

    await recorder.recordStudyDay(
      profileId: profileId,
      at: DateTime.utc(2026, 5, 21, 10),
    );

    final localStreaks = await db.select(db.streakEvents).get();
    expect(
      localStreaks,
      hasLength(1),
      reason: 'local streak event must be appended',
    );

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
  });

  test('recordStudyDay with null outboxFacade still writes the local streak '
      'event', () async {
    // Local-born accounts get null. The tee must not crash.
    final recorder = DriftCompletionStreakRecorder(
      database: db,
      outboxFacade: null,
    );

    await recorder.recordStudyDay(
      profileId: profileId,
      at: DateTime.utc(2026, 5, 21, 10),
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
  });

  test('recordStudyDay is idempotent per (profileId, day) — a second call the '
      'same day is a silent no-op', () async {
    final recorder = DriftCompletionStreakRecorder(
      database: db,
      outboxFacade: null,
    );

    await recorder.recordStudyDay(
      profileId: profileId,
      at: DateTime.utc(2026, 5, 21, 9),
    );
    await recorder.recordStudyDay(
      profileId: profileId,
      at: DateTime.utc(2026, 5, 21, 18),
    );

    final localStreaks = await db.select(db.streakEvents).get();
    expect(
      localStreaks,
      hasLength(1),
      reason:
          'the UNIQUE (profileId, dayUtc, eventType) index must collapse '
          'a second same-day call to a no-op, per CompletionStreakPort\'s '
          'idempotency contract',
    );
  });

  group('AUD-learning-06 — streak tee failure is logged, not swallowed', () {
    setUp(() => AppLogger.init());

    test('enqueueStreakPayload throwing is logged via AppLogger, and '
        'recordStudyDay still completes without throwing', () async {
      final outboxFacade = _MockOutboxFacade();
      when(
        () => outboxFacade.enqueueStreakPayload(any()),
      ).thenThrow(Exception('simulated outbox enqueue failure'));

      final recorder = DriftCompletionStreakRecorder(
        database: db,
        outboxFacade: outboxFacade,
      );

      // Must NOT throw: a "telemetry tee" failure must never fail the
      // caller (CompletionOrchestrator's post-write side effects are
      // already independently caught, but the port itself is also
      // defensive — matching the original _appendStreakEvent contract).
      await recorder.recordStudyDay(
        profileId: profileId,
        at: DateTime.utc(2026, 5, 21, 10),
      );

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
            'AppLogger instead of silently dropped. '
            'Talker history: $history',
      );
    });
  });
}
