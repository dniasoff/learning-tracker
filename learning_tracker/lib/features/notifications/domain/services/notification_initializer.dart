import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;

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

    await service.initialize(onNotificationTap: _handleNotificationTap);
  }

  void _handleNotificationTap(String? payload) {
    if (payload == dailyReminderPayload) {
      router.navigate(const SchedulerRoute());
    }
  }
}
