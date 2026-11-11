import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_saver_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _Plugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime(tz.UTC, 2026));
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
  });

  test('schedule decision respects learning, toggle, lock and cutoff', () {
    final now = DateTime.utc(2026, 3, 25, 20);
    final fireAt = DateTime.utc(2026, 3, 26, 2);
    bool check({
      bool atRisk = true,
      bool enabled = true,
      bool sacred = false,
      bool locked = false,
      DateTime? fire,
    }) => shouldScheduleStreakSaver(
      nowUtc: now,
      fireAtUtc: fire ?? fireAt,
      atRisk: atRisk,
      enabled: enabled,
      sacredTime: sacred,
      deviceLocked: locked,
    );
    expect(check(), isTrue);
    expect(check(atRisk: false), isFalse);
    expect(check(enabled: false), isFalse);
    expect(check(sacred: true), isFalse);
    expect(check(locked: true), isFalse);
    expect(check(fire: now), isFalse);
  });

  test('schedules separate per-profile countdown and can cancel it', () async {
    final plugin = _Plugin();
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ),
    ).thenAnswer((_) async {});
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
    final service = StreakSaverNotifications(plugin: plugin);
    const profile = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
    final fireAt = DateTime.utc(2026, 3, 26, 2);
    final midnight = DateTime.utc(2026, 3, 26, 4);
    await service.schedule(
      profileId: profile,
      fireAtUtc: fireAt,
      midnightUtc: midnight,
      title: 'Streak Saver',
      body: 'Keep your streak',
    );
    final details =
        verify(
              () => plugin.zonedSchedule(
                id: streakSaverNotificationId(profile),
                scheduledDate: any(named: 'scheduledDate'),
                notificationDetails: captureAny(named: 'notificationDetails'),
                androidScheduleMode: any(named: 'androidScheduleMode'),
                title: any(named: 'title'),
                body: any(named: 'body'),
                payload: 'streak_saver:$profile',
                matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
              ),
            ).captured.single
            as NotificationDetails;
    expect(
      streakSaverNotificationId(profile),
      isNot(streakAlertIdForProfile(profile)),
    );
    expect(details.android!.channelId, 'streak_saver');
    expect(details.android!.usesChronometer, isTrue);
    expect(details.android!.chronometerCountDown, isTrue);
    expect(details.android!.when, midnight.millisecondsSinceEpoch);
    await service.cancel(profile);
    verify(
      () => plugin.cancel(id: streakSaverNotificationId(profile)),
    ).called(1);
  });
}
