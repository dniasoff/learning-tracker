// Mirror test for `curriculum_streak_alerts.dart` (DNI-479 AC-2): one
// notification identity per (profile, curriculum), one-shot alerts.
@Tags(['notifications', 'unit'])
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/notifications/domain/services/curriculum_streak_alerts.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _profile = '01JQ8M9Y7V3K2N6P4R5T8W0X1Z';
const _other = '01JQ8M9Y7V3K2N6P4R5T8W0X2A';

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.now(tz.UTC));
    registerFallbackValue(AndroidScheduleMode.exactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  group('streakAlertIdForCurriculum', () {
    test('each (profile, curriculum) has its own id in the profile block', () {
      final base = notificationBlockBaseForProfile(_profile);
      final ids = {
        for (final c in ['mishnayos', 'bavli', 'tanach', 'some_new_one'])
          streakAlertIdForCurriculum(_profile, c),
      };
      expect(ids, hasLength(4));
      for (final id in ids) {
        expect(id - base, inInclusiveRange(100, 999));
      }
      expect(
        streakAlertIdForCurriculum(_other, 'mishnayos'),
        isNot(streakAlertIdForCurriculum(_profile, 'mishnayos')),
      );
      expect(
        streakAlertIdForCurriculum(_profile, 'mishnayos'),
        isNot(streakAlertIdForProfile(_profile)),
      );
    });

    test('is pinned (a scheduled alert must stay cancellable)', () {
      final base = notificationBlockBaseForProfile(_profile);
      expect(streakAlertIdForCurriculum(_profile, 'chumash') - base, 100);
      expect(streakAlertIdForCurriculum(_profile, 'mishnayos') - base, 103);
      expect(streakAlertIdForCurriculum(_profile, 'mussar') - base, 108);
    });
  });

  group('LocalStreakAlertNotifications', () {
    late _MockPlugin plugin;
    late LocalStreakAlertNotifications alerts;

    setUp(() {
      plugin = _MockPlugin();
      alerts = LocalStreakAlertNotifications(plugin: plugin);
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
    });

    test('schedules a one-shot alert under the curriculum identity', () async {
      final fireAt = DateTime.utc(2026, 3, 26, 1);
      await alerts.schedule(
        profileId: _profile,
        curriculumId: 'bavli',
        fireAtUtc: fireAt,
        title: 'Streak at risk',
        body: 'body',
      );
      final call = verify(
        () => plugin.zonedSchedule(
          id: captureAny(named: 'id'),
          scheduledDate: captureAny(named: 'scheduledDate'),
          notificationDetails: any(named: 'notificationDetails'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          title: 'Streak at risk',
          body: 'body',
          payload: '$streakAlertPayload:$_profile',
          matchDateTimeComponents: captureAny(named: 'matchDateTimeComponents'),
        ),
      )..called(1);
      expect(call.captured[0], streakAlertIdForCurriculum(_profile, 'bavli'));
      expect(
        (call.captured[1] as tz.TZDateTime).isAtSameMomentAs(fireAt),
        isTrue,
      );
      // No repeat: at most one alert per civil day.
      expect(call.captured[2], isNull);
    });

    test('cancelAll cancels every curriculum and the retired '
        'profile-wide alert', () async {
      await alerts.cancelAll(_profile);
      final ids = verify(
        () => plugin.cancel(id: captureAny(named: 'id')),
      ).captured;
      expect(ids, contains(streakAlertIdForProfile(_profile)));
      expect(ids, contains(streakAlertIdForCurriculum(_profile, 'mishnayos')));
      expect(ids, hasLength(10));
    });
  });
}
