import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Initializes the notification system at app startup.
///
/// Call once from [main] after [WidgetsFlutterBinding.ensureInitialized].
class NotificationInitializer {
  NotificationInitializer({required this.service, required this.router});

  final NotificationService service;
  final AppRouter router;

  /// Initialize timezone data and notification plugin.
  Future<void> initialize() async {
    tz.initializeTimeZones();
    // Without setLocalLocation, tz.local defaults to UTC and every
    // zonedSchedule fires at the wrong wall-clock time for the user.
    try {
      // flutter_timezone 5.x returns a TimezoneInfo struct; the IANA
      // identifier we feed to tz.getLocation lives on .identifier.
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Platform query failed — leave tz.local as UTC rather than crash.
      // Reminders will fire at UTC wall-clock in this fallback.
    }

    await service.initialize(onNotificationTap: _handleNotificationTap);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == dailyReminderPayload || payload == streakAlertPayload) {
      router.navigate(const SchedulerRoute());
    } else if (payload == rewardMilestonePayload) {
      router.navigate(const GamificationRoute());
    }
  }
}
