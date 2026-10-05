/// Integration test for Story 26.24 (DNI-367), rewired by DNI-481 (1.19):
/// the rolling 14-day reminder batch is filtered by the SAME lock the
/// overlay uses — `lockWindows` (10 min before candle-lighting until 10 min
/// after tzeis, AD-36) over the account's learner settings, fail-closed.
///
///   AC-5 (1.19) — a reminder inside a lock is suppressed, at the start, in
///   the middle and at the end; an unlocked fire time stays eligible.
///   Product ruling 2026-10-05 — no location means no Sacred-Time lock or
///   reminder suppression; a configured location still suppresses normally.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/sacred_lock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_lib;

import '../helpers/learner_state/lock_fixtures.dart';

class MockNotificationGateway extends Mock implements NotificationGateway {}

NotificationScheduler _scheduler(List<LearnerSettingsHistory> histories) =>
    NotificationScheduler(
      service: MockNotificationGateway(),
      isLockedAt: (utc) => isLockedAt(histories, utc),
    );

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    // The device is in New York (EDT, UTC−4) like the learner.
    tz_lib.setLocalLocation(tz_lib.getLocation('America/New_York'));
  });

  // Shabbos 1–2 May 2026 in Lakewood, NJ.
  final lakewoodH = constantHistory(lakewood);
  final lock = lockWindows(
    lakewoodH,
    DateTime.utc(2026, 5, 2, 12),
    DateTime.utc(2026, 5, 2, 12),
  ).single;

  group('1.19 AC-5 — reminders inside a lock are suppressed', () {
    test('the lock opens 10 min before candle-lighting: a 19:30 EDT Friday '
        'reminder is inside it, 19:00 is not', () {
      final scheduler = _scheduler([lakewoodH]);
      expect(scheduler.isLockedAt!(DateTime.utc(2026, 5, 1, 23, 30)), isTrue);
      expect(scheduler.isLockedAt!(DateTime.utc(2026, 5, 1, 23)), isFalse);
    });

    test('start, inside and end of the lock are suppressed; just outside '
        'is eligible', () {
      final isLocked = _scheduler([lakewoodH]).isLockedAt!;
      expect(isLocked(lock.startUtc), isTrue);
      expect(isLocked(lock.startUtc.add(const Duration(hours: 12))), isTrue);
      expect(isLocked(lock.endUtc), isTrue);
      expect(
        isLocked(lock.startUtc.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(isLocked(lock.endUtc.add(const Duration(seconds: 1))), isFalse);
    });

    test('a 14-day 19:30 batch keeps exactly the evenings outside a lock '
        '(both Shabbos evenings of week one dropped)', () {
      final scheduler = _scheduler([lakewoodH]);
      final all = NotificationScheduler(service: MockNotificationGateway())
          .buildFireTimesForTest(
            time: const TimeOfDay(hour: 19, minute: 30),
            fromDay: DateTime(2026, 4, 26), // Sunday; the batch starts Monday
          );
      final kept = scheduler.buildFireTimesForTest(
        time: const TimeOfDay(hour: 19, minute: 30),
        fromDay: DateTime(2026, 4, 26),
      );
      expect(kept, [
        for (final t in all)
          if (!scheduler.isLockedAt!(t.toUtc())) t,
      ]);
      // Friday 1 May 19:30 (inside, candle-lighting − 10 ≈ 19:27) and
      // Saturday 2 May 19:30 (before tzeis + 10) are dropped.
      final dropped = all.where((t) => !kept.contains(t)).toList();
      expect(
        dropped.map((t) => (t.month, t.day)),
        containsAll([(5, 1), (5, 2)]),
      );
      // Friday 8 May 19:30 is still before that week's lock (≈ 19:34).
      expect(kept.map((t) => (t.month, t.day)), contains((5, 8)));
    });
  });

  group('no configured location does not suppress reminders', () {
    test('Friday and Shabbos reminders remain eligible', () {
      final isLocked = _scheduler([
        constantHistory(newYorkNoLocation),
      ]).isLockedAt!;
      // Friday 1 May 2026, 13:00 EDT.
      expect(isLocked(DateTime.utc(2026, 5, 1, 17)), isFalse);
      expect(isLocked(DateTime.utc(2026, 5, 2, 19)), isFalse);
    });

    test(
      'a sibling without location adds nothing beside a configured lock',
      () {
        final isLocked = _scheduler([
          lakewoodH,
          constantHistory(newYorkNoLocation),
        ]).isLockedAt!;
        // 19:45 EDT in Lakewood, after that configured location's candle
        // lighting; the sibling's absent location contributes no window.
        expect(isLocked(DateTime.utc(2026, 5, 1, 23, 45)), isTrue);
      },
    );
  });
}
