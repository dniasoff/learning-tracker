// Mirror test for `lib/domain/learner_state/civil_date.dart` (C0 DNI-524;
// DNI-466 AD-41 civil dates).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/lock_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('CivilDate is the YYYY-MM-DD string isCivilDate validates', () {
    bool valid(CivilDate day) => isCivilDate(day);
    expect(valid('2026-09-01'), isTrue);
    expect(valid('2026-9-1'), isFalse);
  });

  test('civilDate reads the time_zone in force (UTC fixture)', () {
    expect(civilDate(t0, c0SettingsHistory()), '2026-09-01');
  });

  test('civilDate is the learner-local date, not the UTC date', () {
    final instant = DateTime.utc(2026, 9, 5, 2); // 22:00 EDT on 09-04
    expect(civilDate(instant, constantHistory(lakewood)), '2026-09-04');
    expect(civilDate(instant, constantHistory(jerusalem)), '2026-09-05');
  });

  test('civilDate uses the zone in force at the instant', () {
    final move = DateTime.utc(2026, 9, 5, 2);
    final h = movedHistory(lakewood, move, jerusalem);
    final before = move.subtract(const Duration(microseconds: 1));
    expect(civilDate(before, h), '2026-09-04');
    // The change instant itself is judged by the new settings.
    expect(civilDate(move, h), '2026-09-05');
  });

  test('civilDate follows DST in the learner zone', () {
    final h = constantHistory(lakewood);
    // 23:30 EST on 03-07 and 23:30 EDT on 03-08.
    expect(civilDate(DateTime.utc(2026, 3, 8, 4, 30), h), '2026-03-07');
    expect(civilDate(DateTime.utc(2026, 3, 9, 3, 30), h), '2026-03-08');
  });

  test('an unknown zone falls back to UTC, never the device', () {
    final h = constantHistory(lockSettings(timeZone: 'Mars/Olympus_Mons'));
    expect(civilDate(DateTime.utc(2026, 9, 4, 23, 59), h), '2026-09-04');
    expect(civilDate(DateTime.utc(2026, 9, 5), h), '2026-09-05');
  });
}
