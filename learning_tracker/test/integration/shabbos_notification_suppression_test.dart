/// Integration test for Story 26.24 (DNI-367):
/// Rolling 14-day batch with Sacred Time suppression.
///
/// Acceptance criterion 5:
///   Given Erev Shabbos, candle lighting ~19:18 EDT in Lakewood NJ,
///   When the reminder is set for 19:30 EDT (23:30 UTC),
///   Then the 19:30 fire-time on Friday is suppressed (falls inside the
///   Sacred Time window which opens ~23:18 UTC / 19:18 EDT).
///
/// Also verifies:
///   AC1 — batch produces ≤12 entries (Friday 19:30 + Saturday 19:30 removed).
///   AC2 — non-window times are NOT suppressed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/data/services/sacred_window_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_location.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  // Lakewood, NJ: 40.0959° N, 74.2222° W — a common reference location.
  const lakewoodLat = 40.0959;
  const lakewoodLong = -74.2222;

  // Known Shabbos: Friday 1 May 2026 → Saturday 2 May 2026.
  // Sunset in Lakewood ~19:55 EDT, candle lighting ~19:37 EDT,
  // window opens ~19:18 EDT (23:18 UTC) with 15-min cushion.
  //
  // A 19:30 EDT reminder (= 23:30 UTC) IS inside the [23:18, 00:52] UTC window.
  // A 19:00 EDT reminder (= 23:00 UTC) is NOT inside (starts at 23:18 UTC).

  setUpAll(() {
    tz.initializeTimeZones();
    // Set timezone to America/New_York (EDT, UTC-4) for these tests.
    tz_lib.setLocalLocation(tz_lib.getLocation('America/New_York'));

    registerFallbackValue(<tz_lib.TZDateTime>[]);
  });

  group('Story 26.24 — Sacred Time Shabbos suppression', () {
    late MockNotificationService mockService;
    late SacredWindowRepository repository;
    late NotificationScheduler scheduler;

    setUp(() {
      mockService = MockNotificationService();
      repository = SacredWindowRepository();
      scheduler = NotificationScheduler(
        service: mockService,
        sacredWindowRepository: repository,
      );

      when(
        () => mockService.scheduleBatchReminders(
          fireTimes: any(named: 'fireTimes'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});

      when(() => mockService.cancelBatchReminders()).thenAnswer((_) async {});
      when(() => mockService.cancelDailyReminder()).thenAnswer((_) async {});
    });

    test(
      'AC5 — Erev Shabbos, 19:30 EDT reminder → fire on Friday suppressed '
      '(window opens ~19:18 EDT = 23:18 UTC)',
      () {
        // 1 May 2026 is a Friday.
        // Shabbos window opens ~23:18 UTC (19:18 EDT) with 15-min cushion.
        // 19:30 EDT = 23:30 UTC — inside the window.
        final fridayNineteenThirtyUtc = DateTime.utc(2026, 5, 1, 23, 30);

        final location = SacredLocation(
          latitude: lakewoodLat,
          longitude: lakewoodLong,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 5, 1),
        );

        final suppressed = repository.isWindowActive(
          fridayNineteenThirtyUtc,
          location: location,
          inIsrael: false,
        );

        expect(
          suppressed,
          isTrue,
          reason:
              'A 19:30 EDT reminder on Erev Shabbos (1 May 2026, Lakewood NJ) '
              'should be suppressed — Shabbos window opens ~23:18 UTC / 19:18 EDT',
        );
      },
    );

    test(
      'AC5b — 19:00 EDT (23:00 UTC) on Friday is NOT suppressed (before window)',
      () {
        // 19:00 EDT = 23:00 UTC — before the window (~23:18 UTC)
        final fridayNineteenUtc = DateTime.utc(2026, 5, 1, 23, 0);

        final location = SacredLocation(
          latitude: lakewoodLat,
          longitude: lakewoodLong,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 5, 1),
        );

        final suppressed = repository.isWindowActive(
          fridayNineteenUtc,
          location: location,
          inIsrael: false,
        );

        expect(
          suppressed,
          isFalse,
          reason:
              'A 19:00 EDT reminder should NOT be suppressed — '
              'window opens ~19:18 EDT (23:18 UTC)',
        );
      },
    );

    test(
      'AC1 — batch builds ≤12 entries with some suppressed on Shabbos week',
      () async {
        tz_lib.setLocalLocation(tz_lib.getLocation('America/New_York'));

        final location = SacredLocation(
          latitude: lakewoodLat,
          longitude: lakewoodLong,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 4, 30),
        );

        // Reminder at 19:30 EDT — inside the Shabbos window on both Friday
        // and Saturday. So Friday 23:30 UTC and Saturday 23:30 UTC should
        // both be suppressed, giving ≤12 entries from a 14-day batch.
        final fireTimes = scheduler.buildFireTimesForTest(
          time: const TimeOfDay(hour: 19, minute: 30),
          location: location,
          inIsrael: false,
          fromDay: DateTime(2026, 4, 30), // Thursday
        );

        // Should have at most 12 entries (14 - 2 suppressed for Fri + Sat).
        expect(fireTimes.length, lessThanOrEqualTo(12));
        expect(fireTimes.length, greaterThan(0));

        // Verify Friday 19:30 EDT (23:30 UTC) and Saturday 19:30 EDT are NOT
        // in the list.
        final friUtc = DateTime.utc(2026, 5, 1, 23, 30);
        final satUtc = DateTime.utc(2026, 5, 2, 23, 30);

        for (final ft in fireTimes) {
          final utc = ft.toUtc();
          expect(
            utc,
            isNot(equals(friUtc)),
            reason: 'Friday 19:30 EDT should be suppressed (inside Shabbos window)',
          );
          expect(
            utc,
            isNot(equals(satUtc)),
            reason:
                'Saturday 19:30 EDT should be suppressed (inside Shabbos window)',
          );
        }
      },
    );

    test('AC2 — weekday reminder times are NOT suppressed', () {
      // Sunday morning 7:00 AM EDT = 11:00 AM UTC — never Sacred Time.
      final sundayMorningUtc = DateTime.utc(2026, 5, 3, 11, 0);

      final location = SacredLocation(
        latitude: lakewoodLat,
        longitude: lakewoodLong,
        source: SacredLocationSource.detected,
        fixedAt: DateTime.utc(2026, 5, 3),
      );

      final suppressed = repository.isWindowActive(
        sundayMorningUtc,
        location: location,
        inIsrael: false,
      );

      expect(suppressed, isFalse, reason: 'Sunday morning should not be suppressed');
    });

    test(
      'scheduleReminder — calls scheduleBatchReminders with filtered list',
      () async {
        final location = SacredLocation(
          latitude: lakewoodLat,
          longitude: lakewoodLong,
          source: SacredLocationSource.detected,
          fixedAt: DateTime.utc(2026, 5, 1),
        );

        await scheduler.scheduleReminder(
          time: const TimeOfDay(hour: 20, minute: 0),
          title: 'Learning Reminder',
          body: 'You have 3 tasks today',
          location: location,
          inIsrael: false,
        );

        final captured = verify(
          () => mockService.scheduleBatchReminders(
            fireTimes: captureAny(named: 'fireTimes'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).captured;

        final fireTimes = captured.first as List<tz_lib.TZDateTime>;
        // Should be ≤14 (may be fewer if some fall in Shabbos).
        expect(fireTimes.length, lessThanOrEqualTo(14));
      },
    );

    test('SacredWindowRepository.invalidate clears cache', () {
      final location = SacredLocation(
        latitude: lakewoodLat,
        longitude: lakewoodLong,
        source: SacredLocationSource.detected,
        fixedAt: DateTime.utc(2026, 5, 1),
      );

      // Prime the cache with a time inside the window.
      final insideWindow = DateTime.utc(2026, 5, 1, 23, 30);
      repository.isWindowActive(
        insideWindow,
        location: location,
        inIsrael: false,
      );

      // Invalidate.
      repository.invalidate();

      // After invalidation, should recompute and still return correct answer.
      final result = repository.isWindowActive(
        insideWindow,
        location: location,
        inIsrael: false,
      );
      expect(
        result,
        isTrue,
        reason: 'After cache invalidation, 23:30 UTC Fri May 1 is still in window',
      );
    });

    test('null location → isWindowActive returns false (no suppression)', () {
      final result = repository.isWindowActive(
        DateTime.utc(2026, 5, 1, 23, 30),
        location: null,
        inIsrael: false,
      );
      expect(result, isFalse);
    });
  });
}
