import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';

void main() {
  group('DelaySchedule', () {
    test('constructs with delayDays', () {
      expect(const DelaySchedule(7).delayDays, 7);
    });

    test('storageKey is "delay"', () {
      expect(const DelaySchedule(0).storageKey, 'delay');
    });

    test('accessors: daysOfWeek and rollingWindowSize are null', () {
      const spec = DelaySchedule(3);
      expect(spec.daysOfWeek, isNull);
      expect(spec.rollingWindowSize, isNull);
    });

    group('equality', () {
      test('equal for same delayDays', () {
        expect(const DelaySchedule(5), equals(const DelaySchedule(5)));
      });

      test('not equal for different delayDays', () {
        expect(const DelaySchedule(5), isNot(equals(const DelaySchedule(6))));
      });

      test('hashCode consistent with equality', () {
        expect(
          const DelaySchedule(5).hashCode,
          equals(const DelaySchedule(5).hashCode),
        );
      });
    });

    test('toString contains delayDays', () {
      expect(const DelaySchedule(4).toString(), contains('4'));
    });
  });

  group('WeeklySchedule', () {
    // -------------------------------------------------------------------------
    // Construction + validation — this is the release-mode regression guard.
    //
    // WeeklySchedule's factory docstring promises `Throws [ArgumentError]`.
    // Prior to the fix these invariants were enforced with `assert()`, which
    // the compiler strips from release/profile builds — the throw would
    // silently vanish exactly where users run the app. These tests assert
    // the *type* thrown (ArgumentError), not just "throws something", so
    // they fail against an assert()-based implementation even under
    // `flutter test`'s default debug/checked mode (assert throws
    // AssertionError, which is not an ArgumentError).
    // -------------------------------------------------------------------------

    group('construction', () {
      test('constructs with a single valid day', () {
        expect(WeeklySchedule([1]).daysOfWeek, [1]);
      });

      test('constructs with multiple valid days', () {
        expect(WeeklySchedule([1, 3, 7]).daysOfWeek, [1, 3, 7]);
      });

      test('throws ArgumentError for empty daysOfWeek', () {
        expect(() => WeeklySchedule([]), throwsArgumentError);
      });

      test('throws ArgumentError for a value below 1', () {
        expect(() => WeeklySchedule([0]), throwsArgumentError);
      });

      test('throws ArgumentError for a value above 7', () {
        expect(() => WeeklySchedule([8]), throwsArgumentError);
      });

      test(
        'throws ArgumentError when any value in a mixed list is out of range',
        () {
          expect(() => WeeklySchedule([1, 3, 9]), throwsArgumentError);
        },
      );

      test('daysOfWeek is unmodifiable', () {
        final spec = WeeklySchedule([1, 2]);
        expect(() => spec.daysOfWeek.add(3), throwsUnsupportedError);
      });
    });

    test('storageKey is "weekly"', () {
      expect(WeeklySchedule([1]).storageKey, 'weekly');
    });

    test('accessors: delayDays is 0, rollingWindowSize is null', () {
      final spec = WeeklySchedule([1, 2]);
      expect(spec.delayDays, 0);
      expect(spec.rollingWindowSize, isNull);
    });

    group('equality', () {
      test('equal for same daysOfWeek', () {
        expect(WeeklySchedule([1, 2]), equals(WeeklySchedule([1, 2])));
      });

      test('not equal for different daysOfWeek', () {
        expect(WeeklySchedule([1, 2]), isNot(equals(WeeklySchedule([1, 3]))));
      });

      test('hashCode consistent with equality', () {
        expect(
          WeeklySchedule([1, 2]).hashCode,
          equals(WeeklySchedule([1, 2]).hashCode),
        );
      });
    });

    test('toString contains daysOfWeek', () {
      expect(WeeklySchedule([1, 5]).toString(), contains('1'));
    });
  });

  group('RollingSchedule', () {
    // -------------------------------------------------------------------------
    // Construction + validation — same release-mode regression guard as
    // WeeklySchedule above.
    // -------------------------------------------------------------------------

    group('construction', () {
      test('constructs with a positive windowSize', () {
        expect(RollingSchedule(14).windowSize, 14);
      });

      test('constructs with windowSize == 1', () {
        expect(RollingSchedule(1).windowSize, 1);
      });

      test('throws ArgumentError for windowSize == 0', () {
        expect(() => RollingSchedule(0), throwsArgumentError);
      });

      test('throws ArgumentError for negative windowSize', () {
        expect(() => RollingSchedule(-1), throwsArgumentError);
      });
    });

    test('storageKey is "rolling"', () {
      expect(RollingSchedule(1).storageKey, 'rolling');
    });

    test(
      'accessors: delayDays is 0, daysOfWeek is null, rollingWindowSize mirrors windowSize',
      () {
        final spec = RollingSchedule(21);
        expect(spec.delayDays, 0);
        expect(spec.daysOfWeek, isNull);
        expect(spec.rollingWindowSize, 21);
      },
    );

    group('equality', () {
      test('equal for same windowSize', () {
        expect(RollingSchedule(14), equals(RollingSchedule(14)));
      });

      test('not equal for different windowSize', () {
        expect(RollingSchedule(14), isNot(equals(RollingSchedule(15))));
      });

      test('hashCode consistent with equality', () {
        expect(
          RollingSchedule(14).hashCode,
          equals(RollingSchedule(14).hashCode),
        );
      });
    });

    test('toString contains windowSize', () {
      expect(RollingSchedule(30).toString(), contains('30'));
    });
  });

  group('ScheduleSpec.fromParts', () {
    test('delay key returns DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'delay',
        delayDays: 7,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(7));
    });

    test('weekly key with valid daysOfWeek returns WeeklySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'weekly',
        delayDays: 0,
        daysOfWeek: [1, 5],
        rollingWindowSize: null,
      );
      expect(spec, WeeklySchedule([1, 5]));
    });

    test('weekly key with a null daysOfWeek column throws ArgumentError '
        '(release-mode regression guard: previously produced an invalid '
        'WeeklySchedule([]) silently)', () {
      expect(
        () => ScheduleSpec.fromParts(
          scheduleTypeKey: 'weekly',
          delayDays: 0,
          daysOfWeek: null,
          rollingWindowSize: null,
        ),
        throwsArgumentError,
      );
    });

    test('rolling key returns RollingSchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'rolling',
        delayDays: 0,
        daysOfWeek: null,
        rollingWindowSize: 14,
      );
      expect(spec, RollingSchedule(14));
    });

    test('rolling key with a null rollingWindowSize column defaults to 1', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'rolling',
        delayDays: 0,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, RollingSchedule(1));
    });

    test('unknown key falls back to DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'unknown_legacy',
        delayDays: 3,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(3));
    });
  });

  // ---------------------------------------------------------------------
  // AUD-core-domain-03: the delayDays/daysOfWeek/rollingWindowSize
  // convenience getters on [ScheduleSpec] must remain exhaustive over
  // DelaySchedule/WeeklySchedule/RollingSchedule with no `_`/`default`
  // arm, so a future 4th variant fails to compile here instead of
  // silently falling through to 0/null. These tests pin the per-variant
  // values so that requirement can never quietly regress behaviorally
  // either.
  // ---------------------------------------------------------------------
  group('ScheduleSpec convenience accessors', () {
    const delay = ScheduleSpec.delay(3);
    final weekly = ScheduleSpec.weekly([1, 3, 5]);
    final rolling = ScheduleSpec.rolling(7);

    group('delayDays', () {
      test('DelaySchedule returns its own delayDays', () {
        expect(delay.delayDays, 3);
      });

      test('WeeklySchedule returns 0', () {
        expect(weekly.delayDays, 0);
      });

      test('RollingSchedule returns 0', () {
        expect(rolling.delayDays, 0);
      });
    });

    group('daysOfWeek', () {
      test('DelaySchedule returns null', () {
        expect(delay.daysOfWeek, isNull);
      });

      test('WeeklySchedule returns its own daysOfWeek', () {
        expect(weekly.daysOfWeek, [1, 3, 5]);
      });

      test('RollingSchedule returns null', () {
        expect(rolling.daysOfWeek, isNull);
      });
    });

    group('rollingWindowSize', () {
      test('DelaySchedule returns null', () {
        expect(delay.rollingWindowSize, isNull);
      });

      test('WeeklySchedule returns null', () {
        expect(weekly.rollingWindowSize, isNull);
      });

      test('RollingSchedule returns its own windowSize', () {
        expect(rolling.rollingWindowSize, 7);
      });
    });
  });
}
