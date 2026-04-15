import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/sync/domain/reducers/streak_reducer.dart';
import 'package:learning_tracker/features/sync/domain/reducers/xp_reducer.dart';

StreakEvent _se({
  required DateTime at,
  String type = 'completion',
  int profileId = 1,
}) {
  return StreakEvent(
    id: 0,
    profileId: profileId,
    eventType: type,
    eventTimestamp: at,
    clientDeviceId: null,
    createdAt: at,
  );
}

XpEvent _xpe({required int delta, String source = 'completion'}) {
  return XpEvent(
    id: 0,
    profileId: 1,
    xpDelta: delta,
    source: source,
    eventTimestamp: DateTime.utc(2026, 1, 1),
    clientDeviceId: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('reduceStreakEvents', () {
    test('empty log → zero streak', () {
      final state = reduceStreakEvents(const []);
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.lastCompletionDate, isNull);
    });

    test('single completion → streak of 1', () {
      final state = reduceStreakEvents([_se(at: DateTime.utc(2026, 1, 1, 10))]);
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 1);
    });

    test('consecutive days → streak increments', () {
      final state = reduceStreakEvents([
        _se(at: DateTime.utc(2026, 1, 1)),
        _se(at: DateTime.utc(2026, 1, 2)),
        _se(at: DateTime.utc(2026, 1, 3)),
      ]);
      expect(state.currentStreak, 3);
      expect(state.longestStreak, 3);
    });

    test('same-day duplicates do not increment', () {
      final state = reduceStreakEvents([
        _se(at: DateTime.utc(2026, 1, 1, 8)),
        _se(at: DateTime.utc(2026, 1, 1, 15)),
        _se(at: DateTime.utc(2026, 1, 1, 22)),
      ]);
      expect(state.currentStreak, 1);
    });

    test('gap of more than 1 day → streak resets', () {
      final state = reduceStreakEvents([
        _se(at: DateTime.utc(2026, 1, 1)),
        _se(at: DateTime.utc(2026, 1, 2)),
        _se(at: DateTime.utc(2026, 1, 5)), // gap
        _se(at: DateTime.utc(2026, 1, 6)),
      ]);
      expect(state.currentStreak, 2);
      expect(state.longestStreak, 2);
    });

    test('out-of-order input still produces correct state', () {
      final state = reduceStreakEvents([
        _se(at: DateTime.utc(2026, 1, 3)),
        _se(at: DateTime.utc(2026, 1, 1)),
        _se(at: DateTime.utc(2026, 1, 2)),
      ]);
      expect(state.currentStreak, 3);
    });

    test('two-device convergence: unioned logs produce identical state', () {
      // Device A records 1/1, 1/2
      final a = [
        _se(at: DateTime.utc(2026, 1, 1)),
        _se(at: DateTime.utc(2026, 1, 2)),
      ];
      // Device B records 1/3 independently (offline gap)
      final b = [_se(at: DateTime.utc(2026, 1, 3))];
      final merged = [...a, ...b];

      final reducerA = reduceStreakEvents(merged);
      final reducerB = reduceStreakEvents(merged.reversed);
      expect(reducerA.currentStreak, reducerB.currentStreak);
      expect(reducerA.longestStreak, reducerB.longestStreak);
      expect(reducerA.currentStreak, 3);
    });
  });

  group('reduceXpEvents', () {
    test('empty log → 0 XP', () {
      expect(reduceXpEvents(const []), 0);
    });

    test('positive deltas sum correctly', () {
      expect(reduceXpEvents([_xpe(delta: 5), _xpe(delta: 10)]), 15);
    });

    test('negative deltas are honoured (admin adjust)', () {
      expect(
        reduceXpEvents([
          _xpe(delta: 100),
          _xpe(delta: -30, source: 'admin_adjust'),
        ]),
        70,
      );
    });
  });

  group('StreakEvents table migration', () {
    test('UserDatabase exposes streakEvents and xpEvents', () async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: DateTime.utc(2026, 1, 1),
            ),
          );
      await db
          .into(db.xpEvents)
          .insert(
            XpEventsCompanion.insert(
              profileId: 1,
              xpDelta: 10,
              source: 'completion',
              eventTimestamp: DateTime.utc(2026, 1, 1),
            ),
          );

      final streakRows = await db.select(db.streakEvents).get();
      final xpRows = await db.select(db.xpEvents).get();
      expect(streakRows, hasLength(1));
      expect(xpRows, hasLength(1));
      expect(streakRows.first.profileId, 1);
      expect(xpRows.first.xpDelta, 10);
    });

    test('unique constraint rejects duplicate (profile, ts, type)', () async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final ts = DateTime.utc(2026, 1, 1, 12);
      await db
          .into(db.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: 1,
              eventType: 'completion',
              eventTimestamp: ts,
            ),
          );
      expect(
        () => db
            .into(db.streakEvents)
            .insert(
              StreakEventsCompanion.insert(
                profileId: 1,
                eventType: 'completion',
                eventTimestamp: ts,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
