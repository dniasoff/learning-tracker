// Mirror test for `lib/domain/learner_state/learner_zone.dart` (DNI-466):
// civil-day arithmetic in the learner's IANA zone, never the device's.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';

void main() {
  group('LearnerZone', () {
    test('resolves a tz-database zone and UTC', () {
      expect(LearnerZone.of('America/New_York').isKnown, isTrue);
      expect(LearnerZone.of('UTC').isKnown, isTrue);
    });

    test('an id missing from the tz database is unknown and UTC-based', () {
      final zone = LearnerZone.of('Mars/Olympus_Mons');
      expect(zone.isKnown, isFalse);
      expect(
        zone.dayOf(DateTime.utc(2026, 9, 4, 23, 30)),
        DateTime.utc(2026, 9, 4),
      );
      expect(
        zone.at(DateTime.utc(2026, 9, 4), hour: 12),
        DateTime.utc(2026, 9, 4, 12),
      );
    });

    test('dayOf uses the zone offset on both sides of UTC midnight', () {
      final instant = DateTime.utc(2026, 9, 5, 2); // Fri 22:00 in New York
      expect(
        LearnerZone.of('America/New_York').dayOf(instant),
        DateTime.utc(2026, 9, 4),
      );
      expect(
        LearnerZone.of('Asia/Jerusalem').dayOf(instant),
        DateTime.utc(2026, 9, 5),
      );
      expect(
        LearnerZone.of('Pacific/Kiritimati').dayOf(instant),
        DateTime.utc(2026, 9, 5),
      );
    });

    test('at converts local wall time across DST changes', () {
      final ny = LearnerZone.of('America/New_York');
      // EST before the 2026-03-08 spring-forward, EDT after it.
      expect(
        ny.at(DateTime.utc(2026, 3, 7), hour: 12),
        DateTime.utc(2026, 3, 7, 17),
      );
      expect(
        ny.at(DateTime.utc(2026, 3, 9), hour: 12),
        DateTime.utc(2026, 3, 9, 16),
      );
      // The 2026-03-08 civil day is 23 hours long.
      expect(
        ny
            .startOf(DateTime.utc(2026, 3, 9))
            .difference(ny.startOf(DateTime.utc(2026, 3, 8))),
        const Duration(hours: 23),
      );
      // The 2026-11-01 civil day is 25 hours long.
      expect(
        ny
            .startOf(DateTime.utc(2026, 11, 2))
            .difference(ny.startOf(DateTime.utc(2026, 11, 1))),
        const Duration(hours: 25),
      );
    });
  });

  group('civil-day helpers', () {
    test('addCivilDays crosses month and year ends', () {
      expect(addCivilDays(DateTime.utc(2026, 12, 31), 1), DateTime.utc(2027));
      expect(
        addCivilDays(DateTime.utc(2026, 3, 1), -1),
        DateTime.utc(2026, 2, 28),
      );
    });

    test('format and parse round-trip YYYY-MM-DD', () {
      expect(formatCivilDay(DateTime.utc(2026, 4, 5)), '2026-04-05');
      expect(parseCivilDay('2026-04-05'), DateTime.utc(2026, 4, 5));
      expect(formatCivilDay(parseCivilDay('0999-01-09')), '0999-01-09');
    });
  });
}
