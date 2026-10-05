// Mirror test for
// `lib/features/learning/domain/commands/child_redate_limit.dart`
// (DNI-469 AC-5).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/child_redate_limit.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';

// A configured New York location: derive the Shabbos and catch-up intervals
// from the same lock-window source used by production.
const _shabbos = '2026-09-05';
final _history = c0SettingsHistory();
final _lock = lockWindows(
  _history,
  DateTime.utc(2026, 9, 4),
  DateTime.utc(2026, 9, 6),
).single;
final _catchUp = catchUpWindow(_lock, _history);

bool _may(String? learnedOn, DateTime now) => childMayRedate(
  learnedOn: learnedOn,
  settingsHistory: _history,
  nowUtc: now,
);

void main() {
  test('allowed inside the catch-up window of the lock that locked the '
      'day', () {
    expect(_may(_shabbos, _catchUp.startUtc), isTrue);
    expect(_may(_shabbos, _catchUp.endUtc), isTrue);
  });

  test('rejected at and after the end of that window', () {
    expect(
      _may(_shabbos, _catchUp.endUtc.add(const Duration(microseconds: 1))),
      isFalse,
    );
    expect(
      _may(_shabbos, _catchUp.endUtc.add(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('rejected for a day that is not a locked day, and for null', () {
    expect(_may('2026-09-04', DateTime.utc(2026, 9, 6, 10)), isFalse);
    expect(_may('2026-09-06', DateTime.utc(2026, 9, 6, 10)), isFalse);
    expect(_may(null, DateTime.utc(2026, 9, 6, 10)), isFalse);
  });

  test('rejected while the lock is still open (no catch-up yet)', () {
    expect(_may(_shabbos, _lock.endUtc), isFalse);
  });
}
