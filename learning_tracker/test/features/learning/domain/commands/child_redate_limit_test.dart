// Mirror test for
// `lib/features/learning/domain/commands/child_redate_limit.dart`
// (DNI-469 AC-5).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/child_redate_limit.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';

// UTC, no location: the Shabbos lock is Fri 2026-09-04 12:00Z → Sun
// 2026-09-06 01:00Z; its only locked day is Sat 2026-09-05, and its
// catch-up window runs to the end of Mon 2026-09-07 (UTC).
const _shabbos = '2026-09-05';

bool _may(String? learnedOn, DateTime now) => childMayRedate(
  learnedOn: learnedOn,
  settingsHistory: c0SettingsHistory(),
  nowUtc: now,
);

void main() {
  test('allowed inside the catch-up window of the lock that locked the '
      'day', () {
    expect(_may(_shabbos, DateTime.utc(2026, 9, 6, 10)), isTrue);
    expect(_may(_shabbos, DateTime.utc(2026, 9, 7, 23, 59)), isTrue);
  });

  test('rejected at and after the end of that window', () {
    expect(_may(_shabbos, DateTime.utc(2026, 9, 8)), isFalse);
    expect(_may(_shabbos, DateTime.utc(2026, 9, 9, 12)), isFalse);
  });

  test('rejected for a day that is not a locked day, and for null', () {
    expect(_may('2026-09-04', DateTime.utc(2026, 9, 6, 10)), isFalse);
    expect(_may('2026-09-06', DateTime.utc(2026, 9, 6, 10)), isFalse);
    expect(_may(null, DateTime.utc(2026, 9, 6, 10)), isFalse);
  });

  test('rejected while the lock is still open (no catch-up yet)', () {
    expect(_may(_shabbos, DateTime.utc(2026, 9, 5, 20)), isFalse);
  });
}
