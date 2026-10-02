// Mirror test for `lib/domain/learner_state/lock_filter.dart` (DNI-466
// AC-4): the engine's lock-ignore stage.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/lock_fixtures.dart';

void main() {
  const us = Duration(microseconds: 1);
  final a = LockWindow(
    DateTime.utc(2026, 9, 4, 12),
    DateTime.utc(2026, 9, 6, 1),
  );
  final b = LockWindow(
    DateTime.utc(2026, 9, 11, 12),
    DateTime.utc(2026, 9, 13, 1),
  );

  group('insideLock', () {
    test('is closed at both bounds of every lock', () {
      final locks = [a, b];
      for (final lock in locks) {
        expect(insideLock(locks, lock.startUtc), isTrue);
        expect(insideLock(locks, lock.endUtc), isTrue);
        expect(insideLock(locks, lock.startUtc.subtract(us)), isFalse);
        expect(insideLock(locks, lock.endUtc.add(us)), isFalse);
      }
      expect(insideLock(locks, DateTime.utc(2026, 9, 8)), isFalse);
      expect(insideLock(const [], a.startUtc), isFalse);
    });
  });

  group('engineLockWindows', () {
    test('covers every event and the look-back before now', () {
      final h = constantHistory(newYorkNoLocation);
      final events = [
        engineLearn(1, 'x', minutes: 0), // Tue 2026-09-01
        engineLearn(2, 'y', minutes: 19 * 1440), // Sun 2026-09-20 00:00Z
      ];
      final locks = engineLockWindows(h, events, engineAt(10 * 1440));
      // Shabbos 09-05, Shabbos + Rosh Hashana 09-12/13, Shabbos 09-19.
      expect(locks, hasLength(3));
      expect(
        engineLockWindows(
          h,
          const [],
          engineAt(19 * 1440),
          lookBack: const Duration(days: 18),
        ),
        hasLength(3),
      );
      expect(engineLockWindows(h, const [], engineAt(0)), isEmpty);
    });
  });

  group('lockIgnoreHook', () {
    test('ignores an event iff its effectiveAt is inside a lock', () {
      final hook = lockIgnoreHook([a]);
      expect(hook(engineLearn(1, 'x', minutes: 6000)), isTrue);
      expect(hook(engineLearn(2, 'x', minutes: 100)), isFalse);
      expect(
        hook(engineLearn(3, 'x', minutes: 100, originalMinutes: 6000)),
        isTrue,
      );
      expect(hook(engineVoid(4, 1, minutes: 6000)), isTrue);
    });

    test('with no locks ignores nothing', () {
      expect(
        lockIgnoreHook(const [])(engineLearn(1, 'x', minutes: 6000)),
        isFalse,
      );
    });
  });
}
