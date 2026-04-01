import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';

/// Service for managing streak protection alert notifications.
///
/// Schedules a daily notification at a configurable time (default 9 PM).
/// The notification is cancelled when a completion is recorded today.
/// On app launch, the service evaluates whether to schedule or cancel.
class StreakAlertService {
  StreakAlertService({
    required UserDatabase db,
    required NotificationService notificationService,
    DateTime Function()? clock,
  }) : _db = db,
       _notificationService = notificationService,
       _clock = clock ?? DateTimeFactory.nowUtc;

  final UserDatabase _db;
  final NotificationService _notificationService;
  final DateTime Function() _clock;

  /// Evaluate streak state and schedule or cancel the alert accordingly.
  ///
  /// Call on app launch and after preference changes.
  Future<void> evaluate({required int hour, required int minute}) async {
    final streak = await _db.streakDao.getStreak();

    // No streak or streak is 0 → no alert needed
    if (streak == null || streak.currentStreak == 0) {
      await cancelAlert();
      return;
    }

    // Check if user already completed learning today
    if (await _hasCompletionsToday()) {
      await cancelAlert();
      return;
    }

    // Active streak + no completions today → schedule alert
    await scheduleAlert(
      hour: hour,
      minute: minute,
      currentStreak: streak.currentStreak,
    );
  }

  /// Schedule the streak protection alert notification.
  Future<void> scheduleAlert({
    required int hour,
    required int minute,
    required int currentStreak,
  }) async {
    final body = buildBody(currentStreak);

    await _notificationService.scheduleStreakAlert(
      hour: hour,
      minute: minute,
      body: body,
    );
  }

  /// Cancel the streak protection alert.
  Future<void> cancelAlert() async {
    await _notificationService.cancelStreakAlert();
  }

  /// Called when a completion is recorded. Cancels today's alert.
  Future<void> onCompletionRecorded() async {
    await cancelAlert();
  }

  /// Check if there are any completions for the current local day.
  Future<bool> _hasCompletionsToday() async {
    final now = _clock();
    final startOfDay = DateUtils.startOfLocalDay(now);
    final endOfDay = DateUtils.endOfLocalDay(now);

    return await _db.completionDao.hasCompletionsInDateRange(
      startOfDay,
      endOfDay,
    );
  }

  /// Build the notification body for a given streak count.
  static String buildBody(int currentStreak) {
    return 'Your $currentStreak-day streak is at risk!';
  }
}
