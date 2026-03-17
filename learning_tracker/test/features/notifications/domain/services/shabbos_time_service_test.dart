import 'package:learning_tracker/features/notifications/domain/services/shabbos_time_service.dart';
import 'package:test/test.dart';

void main() {
  const service = ShabbosTimeService();

  group('isDuringShabbosWithFixedTimes', () {
    test('Friday after start time is Shabbos', () {
      // Friday 19:00
      final dt = DateTime(2026, 3, 20, 19, 0);
      expect(
        service.isDuringShabbosWithFixedTimes(
          dateTime: dt,
          startHour: 18,
          startMinute: 0,
          endHour: 20,
          endMinute: 0,
        ),
        isTrue,
      );
    });

    test('Friday before start time is not Shabbos', () {
      // Friday 16:00
      final dt = DateTime(2026, 3, 20, 16, 0);
      expect(
        service.isDuringShabbosWithFixedTimes(
          dateTime: dt,
          startHour: 18,
          startMinute: 0,
          endHour: 20,
          endMinute: 0,
        ),
        isFalse,
      );
    });

    test('Saturday before end time is Shabbos', () {
      // Saturday 12:00
      final dt = DateTime(2026, 3, 21, 12, 0);
      expect(
        service.isDuringShabbosWithFixedTimes(
          dateTime: dt,
          startHour: 18,
          startMinute: 0,
          endHour: 20,
          endMinute: 0,
        ),
        isTrue,
      );
    });

    test('Saturday after end time is not Shabbos', () {
      // Saturday 21:00
      final dt = DateTime(2026, 3, 21, 21, 0);
      expect(
        service.isDuringShabbosWithFixedTimes(
          dateTime: dt,
          startHour: 18,
          startMinute: 0,
          endHour: 20,
          endMinute: 0,
        ),
        isFalse,
      );
    });

    test('Wednesday is never Shabbos', () {
      final dt = DateTime(2026, 3, 18, 19, 0);
      expect(
        service.isDuringShabbosWithFixedTimes(
          dateTime: dt,
          startHour: 18,
          startMinute: 0,
          endHour: 20,
          endMinute: 0,
        ),
        isFalse,
      );
    });
  });

  group('isDuringShabbosWithLocation', () {
    // Jerusalem
    const lat = 31.7683;
    const lon = 35.2137;

    test('Saturday midday is Shabbos', () {
      final saturday = DateTime(2026, 3, 21, 12, 0);
      expect(
        service.isDuringShabbosWithLocation(
          dateTime: saturday,
          latitude: lat,
          longitude: lon,
        ),
        isTrue,
      );
    });

    test('Wednesday midday is not Shabbos', () {
      final wednesday = DateTime(2026, 3, 18, 12, 0);
      expect(
        service.isDuringShabbosWithLocation(
          dateTime: wednesday,
          latitude: lat,
          longitude: lon,
        ),
        isFalse,
      );
    });
  });

  group('getCandleLightingTime', () {
    test('returns time for Friday in Jerusalem', () {
      const lat = 31.7683;
      const lon = 35.2137;
      final friday = DateTime(2026, 3, 20, 12, 0);

      final result = service.getCandleLightingTime(
        date: friday,
        latitude: lat,
        longitude: lon,
      );

      expect(result, isNotNull);
      expect(result!.hour, greaterThanOrEqualTo(14));
      expect(result.hour, lessThanOrEqualTo(20));
    });
  });

  group('getHavdalahTime', () {
    test('returns time for Saturday in Jerusalem', () {
      const lat = 31.7683;
      const lon = 35.2137;
      final saturday = DateTime(2026, 3, 21, 12, 0);

      final result = service.getHavdalahTime(
        date: saturday,
        latitude: lat,
        longitude: lon,
      );

      expect(result, isNotNull);
      expect(result!.hour, greaterThanOrEqualTo(15));
      expect(result.hour, lessThanOrEqualTo(22));
    });
  });
}
