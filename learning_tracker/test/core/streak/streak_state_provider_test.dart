// Tests for StreakStateProvider.watch() — the reactive stream path (lines 50-68)
// that was uncovered because only read() had tests via StreakService.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/streak/streak_state_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

import '../../helpers/drift_memory.dart';

void main() {
  late FakeLocalDayClock clock;

  setUp(() {
    clock = FakeLocalDayClock(DateTime.utc(2026, 3, 15, 12));
  });

  group('StreakStateProvider.read', () {
    test('returns zero streak when no events exist', () async {
      final db = inMemoryDb();
      final provider = StreakStateProvider(db: db, clock: clock);

      final state = await provider.read(profileId: 1);

      expect(state.currentStreak, 0);
      await db.close();
    });
  });

  group('StreakStateProvider.watch', () {
    test('emits streak state as a stream', () async {
      final db = inMemoryDb();
      final provider = StreakStateProvider(db: db, clock: clock);

      // First emission should be the initial state (no events = 0 streak).
      final firstState = await provider.watch(profileId: 1).first;

      expect(firstState.currentStreak, 0);
      await db.close();
    });

    test('emits zero streak when profile has no events', () async {
      final db = inMemoryDb();
      final provider = StreakStateProvider(db: db, clock: clock);

      final states = provider.watch(profileId: 99);
      final first = await states.first;

      expect(first.currentStreak, 0);
      await db.close();
    });
  });
}
