import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/notifications/domain/models/parent_push_message.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Callback type for switching the active profile.
///
/// WS5.per-profile: the tap handler needs to be able to switch into the
/// profile whose reminder was tapped, so the caller wires in this callback
/// from the provider / router layer. Receives the profileId (AD-24 ULID
/// string) parsed from the notification payload.
typedef ProfileSwitchCallback = void Function(String profileId);

/// Callback for a tapped tutor-change push (Story 4.7 / DNI-515). The app
/// layer decides whether to open the learner's Change history; the route's
/// parent PIN gate still applies.
typedef ParentPushTapCallback = void Function(ParentPushTap tap);

/// Initializes the notification system at app startup.
///
/// Call once from [main] after [WidgetsFlutterBinding.ensureInitialized].
class NotificationInitializer {
  NotificationInitializer({
    required this.service,
    required this.router,
    this.onSwitchProfile,
    this.onParentPushTap,
    this.readLaunchPayload,
  });

  final NotificationGateway service;
  final AppRouter router;

  /// Optional callback invoked when a notification tap identifies a specific
  /// profile (via the `daily_reminder:<profileId>` payload). The callback
  /// should select that profile in the provider tree so the user lands in the
  /// correct profile's Scheduler.
  ///
  /// If `null`, the tap opens the Scheduler for whatever profile is currently
  /// active (pre-WS5 behaviour, fine for single-profile setups).
  final ProfileSwitchCallback? onSwitchProfile;

  /// Receives tapped tutor-change pushes — including the one that launched
  /// the app, if any.
  final ParentPushTapCallback? onParentPushTap;

  /// Reads the payload of the notification whose tap launched the app (null
  /// when none). Defaults to the plugin's launch details; injectable for
  /// tests.
  final Future<String?> Function()? readLaunchPayload;

  static Future<String?> _pluginLaunchPayload() async {
    final details = await FlutterLocalNotificationsPlugin()
        .getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

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
    } catch (e, stackTrace) {
      // AUD-notifications-05 (EH-3): leave tz.local as UTC rather than
      // crash (reminders fire at UTC wall-clock in this fallback), but log
      // so a real platform-query failure leaves a diagnostic trail.
      AppLogger.instance.warning(
        event: 'timezone_detect_on_init_failed',
        exception: e,
        stackTrace: stackTrace,
      );
    }

    await service.initialize(onNotificationTap: _handleNotificationTap);
    final parentPushTap = onParentPushTap;
    if (parentPushTap != null) {
      try {
        final launch = ParentPushTap.tryParsePayload(
          await (readLaunchPayload ?? _pluginLaunchPayload)(),
        );
        if (launch != null) parentPushTap(launch);
      } on Object catch (e, stackTrace) {
        AppLogger.instance.warning(
          event: 'notification_launch_details_failed',
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    final parentPush = ParentPushTap.tryParsePayload(payload);
    if (parentPush != null) {
      onParentPushTap?.call(parentPush);
      return;
    }

    // WS5.per-profile: payloads for per-profile notifications have the form
    // `daily_reminder:<profileId>` or `streak_protection:<profileId>`.
    // Parse the profileId and switch to that profile before navigating.
    if (payload.startsWith('$dailyReminderPayload:') ||
        payload.startsWith('$streakAlertPayload:')) {
      final parts = payload.split(':');
      if (parts.length == 2) {
        final profileId = parts[1];
        if (profileId.isNotEmpty && onSwitchProfile != null) {
          onSwitchProfile!(profileId);
        }
      }
      router.navigate(const SchedulerRoute());
    } else if (payload == dailyReminderPayload ||
        payload == streakAlertPayload) {
      // Legacy payload (no profileId suffix) — open Scheduler for active profile.
      router.navigate(const SchedulerRoute());
    } else if (payload == rewardMilestonePayload) {
      router.navigate(const GamificationRoute());
    }
  }
}
