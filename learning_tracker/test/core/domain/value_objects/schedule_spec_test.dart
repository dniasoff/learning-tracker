import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';

/// Regression coverage for AUD-core-domain-03: the delayDays/daysOfWeek/
/// rollingWindowSize convenience getters on [ScheduleSpec] must remain
/// exhaustive over DelaySchedule/WeeklySchedule/RollingSchedule with no
/// `_`/`default` arm, so a future 4th variant fails to compile here instead
/// of silently falling through to 0/null. These tests pin the per-variant
/// values so that requirement can never quietly regress behaviorally either.
void main() {
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
