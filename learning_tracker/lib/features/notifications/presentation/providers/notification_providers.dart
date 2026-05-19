import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/notifications/data/services/sacred_window_repository.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_providers.g.dart';

/// SharedPreferences keys for reminder settings.
const String _reminderEnabledKey = 'daily_reminder_enabled';
const String _reminderHourKey = 'daily_reminder_hour';
const String _reminderMinuteKey = 'daily_reminder_minute';

/// SharedPreferences keys for streak alert settings.
const String _streakAlertEnabledKey = 'streak_alert_enabled';
const String _streakAlertHourKey = 'streak_alert_hour';
const String _streakAlertMinuteKey = 'streak_alert_minute';

/// SharedPreferences keys for reward notification settings.
const String _rewardNotificationEnabledKey = 'reward_notification_enabled';

const String _notificationSettingsUpdatedAtMsKey =
    'notification_settings_updated_at_ms';

/// Default reminder time: 7:00 PM.
const int defaultReminderHour = 19;
const int defaultReminderMinute = 0;

/// Default streak alert time: 9:00 PM.
const int defaultStreakAlertHour = 21;
const int defaultStreakAlertMinute = 0;

/// Provides the [NotificationService] singleton.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

/// Manages the daily reminder enabled state.
@riverpod
class ReminderEnabled extends _$ReminderEnabled {
  @override
  bool build() {
    _loadFromPrefs();
    return true; // default enabled
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_reminderEnabledKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, state);
  }
}

/// Manages the daily reminder time.
@riverpod
class ReminderTime extends _$ReminderTime {
  @override
  TimeOfDay build() {
    _loadFromPrefs();
    return const TimeOfDay(
      hour: defaultReminderHour,
      minute: defaultReminderMinute,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour = prefs.getInt(_reminderHourKey) ?? defaultReminderHour;
    final minute = prefs.getInt(_reminderMinuteKey) ?? defaultReminderMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, time.hour);
    await prefs.setInt(_reminderMinuteKey, time.minute);
  }
}

/// Manages the streak alert enabled state.
@riverpod
class StreakAlertEnabled extends _$StreakAlertEnabled {
  @override
  bool build() {
    _loadFromPrefs();
    return true; // default enabled
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_streakAlertEnabledKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_streakAlertEnabledKey, state);
  }
}

/// Manages the streak alert time.
@riverpod
class StreakAlertTime extends _$StreakAlertTime {
  @override
  TimeOfDay build() {
    _loadFromPrefs();
    return const TimeOfDay(
      hour: defaultStreakAlertHour,
      minute: defaultStreakAlertMinute,
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour = prefs.getInt(_streakAlertHourKey) ?? defaultStreakAlertHour;
    final minute =
        prefs.getInt(_streakAlertMinuteKey) ?? defaultStreakAlertMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streakAlertHourKey, time.hour);
    await prefs.setInt(_streakAlertMinuteKey, time.minute);
  }
}

/// Manages the reward notification enabled state.
@riverpod
class RewardNotificationEnabled extends _$RewardNotificationEnabled {
  @override
  bool build() {
    _loadFromPrefs();
    return true; // default enabled
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state = prefs.getBool(_rewardNotificationEnabledKey) ?? true;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rewardNotificationEnabledKey, state);
  }
}

/// Persist the current notification preference set to Firestore for
/// cloud-born accounts. Local-born accounts remain local-only.
Future<void> _persistNotificationSettingsToCloud(
  Ref ref, {
  required SharedPreferences prefs,
}) async {
  // P2a: use FirestoreGateway directly instead of SyncEngine for this write.
  final gateway = () {
    try {
      return ref.read(firestoreGatewayProvider);
    } catch (_) {
      // Some tests build notification providers without full sync dependencies.
      return null;
    }
  }();
  if (gateway == null) return;

  final profileId = ref.read(activeProfileIdProvider);
  final updatedAtMs = DateTimeFactory.nowUtc().millisecondsSinceEpoch;
  await prefs.setInt(_notificationSettingsUpdatedAtMsKey, updatedAtMs);

  await gateway.pushNotificationSettings(
    profileId: profileId,
    data: {
      'schema_version': 1,
      'daily_reminder': {
        'enabled': prefs.getBool(_reminderEnabledKey) ?? true,
        'hour': prefs.getInt(_reminderHourKey) ?? defaultReminderHour,
        'minute': prefs.getInt(_reminderMinuteKey) ?? defaultReminderMinute,
      },
      'streak_alert': {
        'enabled': prefs.getBool(_streakAlertEnabledKey) ?? true,
        'hour': prefs.getInt(_streakAlertHourKey) ?? defaultStreakAlertHour,
        'minute':
            prefs.getInt(_streakAlertMinuteKey) ?? defaultStreakAlertMinute,
      },
      'reward_notifications': {
        'enabled': prefs.getBool(_rewardNotificationEnabledKey) ?? true,
      },
      'updated_at': DateTime.fromMillisecondsSinceEpoch(
        updatedAtMs,
        isUtc: true,
      ).toIso8601String(),
    },
  );
}

/// Returns true if notifications should currently be suppressed because
/// Sacred Time is active. Backed by [currentSacredWindowProvider] —
/// notifications follow the same window the lock screen does.
@riverpod
bool isSacredTimeActive(Ref ref) {
  return ref.watch(currentSacredWindowProvider) != null;
}

/// Provides the [SacredWindowRepository] singleton.
///
/// Kept alive so the in-memory cache survives across provider rebuilds.
/// [TimezoneLifecycleObserver] calls [SacredWindowRepository.invalidate]
/// on resume (DNI-367).
///
/// The [SacredWindowDao] is injected so computed windows are persisted to
/// the user DB, enabling background notification fire-time checks on
/// cold-start without the Flutter engine (DNI-367 AC 26.24 requirement 4).
@Riverpod(keepAlive: true)
SacredWindowRepository sacredWindowRepository(Ref ref) {
  final dao = ref.watch(userDatabaseProvider).sacredWindowDao;
  return SacredWindowRepository(dao: dao);
}

/// Provides the [NotificationScheduler] instance.
@riverpod
NotificationScheduler notificationScheduler(Ref ref) {
  final service = ref.watch(notificationServiceProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  final sacredRepo = ref.watch(sacredWindowRepositoryProvider);
  return NotificationScheduler(
    service: service,
    sacredWindowRepository: sacredRepo,
    analytics: analytics,
  );
}

/// Watches all notification preference providers and syncs the composite
/// profile-scoped notification_settings document for cloud-born accounts.
final notificationSettingsCloudSyncEffectProvider = FutureProvider<void>((
  ref,
) async {
  // Track all preference providers so any change re-runs this effect.
  ref.watch(reminderEnabledProvider);
  ref.watch(reminderTimeProvider);
  ref.watch(streakAlertEnabledProvider);
  ref.watch(streakAlertTimeProvider);
  ref.watch(rewardNotificationEnabledProvider);

  final prefs = await SharedPreferences.getInstance();
  await _persistNotificationSettingsToCloud(ref, prefs: prefs);
});

/// Watches reminder settings and daily tasks, then schedules or cancels
/// the notification accordingly.
///
/// DNI-367 (Story 26.24): now schedules a rolling 14-day batch of pre-filtered
/// one-shots instead of a repeating notification. Sacred Time windows are
/// checked per-fire-time by [NotificationScheduler.scheduleReminder].
///
/// Also respects Shabbos quiet mode — cancels all notifications when Sacred
/// Time is currently active (the live lock-screen guard).
///
/// Kept alive so that time/enable changes always trigger a reschedule,
/// even if no UI is watching this provider at the moment.
@Riverpod(keepAlive: true)
Future<void> reminderSyncEffect(Ref ref) async {
  final enabled = ref.watch(reminderEnabledProvider);
  final time = ref.watch(reminderTimeProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);
  final sacredTimeActive = ref.watch(isSacredTimeActiveProvider);

  if (!enabled) {
    await scheduler.cancel();
    return;
  }
  if (sacredTimeActive) {
    // Story 27.14 (DNI-390): fire suppression event when sacred time blocks.
    await scheduler.cancelForSacredTime();
    return;
  }

  // Get daily tasks to determine counts for notification body.
  final tasks = await ref.watch(allDailyTasksProvider.future);

  // D1 fix: count only today's units (non-overdue, non-review).
  // Overdue tasks (isOverdue: true) and review/chazara tasks
  // (overdueChazara, scheduledChazara) are excluded so the body count
  // honestly represents items the user is scheduled to learn today.
  final todayTasks = tasks
      .where(
        (t) =>
            !t.isOverdue &&
            t.priority != DailyTaskPriority.overdueChazara &&
            t.priority != DailyTaskPriority.scheduledChazara,
      )
      .toList();
  final taskCount = todayTasks.length;
  final curriculumCount = todayTasks.map((t) => t.curriculumId).toSet().length;

  // D2 fix: when there are no tasks today, cancel any existing reminder
  // rather than scheduling "0 tasks today".
  if (taskCount == 0) {
    await scheduler.cancel();
    return;
  }

  // Resolve Sacred Location for per-fire-time window filtering (DNI-367).
  final location = ref.read(sacredLocationProvider);
  final inIsrael = ref.read(inIsraelProvider);

  // Build locale-aware notification body.
  // NOTE: We build a plain-English body here since locale context is not
  // available in providers. For fully locale-aware bodies, callers that have
  // BuildContext should use AppLocalizations and call scheduler.scheduleReminder
  // directly with a pre-resolved body string (UX-DR7).
  final body =
      'You have $taskCount '
      'task${taskCount == 1 ? '' : 's'} across '
      '$curriculumCount curricul${curriculumCount == 1 ? 'um' : 'a'} today';

  await scheduler.scheduleReminder(
    time: time,
    title: 'Learning Reminder',
    body: body,
    location: location,
    inIsrael: inIsrael,
  );
}

/// Provides the [StreakAlertService] instance.
@riverpod
StreakAlertService streakAlertService(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final notifService = ref.watch(notificationServiceProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  return StreakAlertService(
    db: db,
    notificationService: notifService,
    profileId: profileId,
    analytics: analytics,
  );
}

/// Watches streak alert settings and evaluates whether to schedule or cancel
/// the streak protection alert.
///
/// Also respects sacred time mode — cancels alerts during Shabbos.
///
/// Kept alive so that time/enable changes always trigger a reschedule,
/// even if no UI is watching this provider at the moment.
@Riverpod(keepAlive: true)
Future<void> streakAlertSyncEffect(Ref ref) async {
  final enabled = ref.watch(streakAlertEnabledProvider);
  final time = ref.watch(streakAlertTimeProvider);
  final service = ref.watch(streakAlertServiceProvider);
  final sacredTimeActive = ref.watch(isSacredTimeActiveProvider);

  if (!enabled) {
    await service.cancelAlert();
    return;
  }
  if (sacredTimeActive) {
    // Story 27.14 (DNI-390): fire suppression event when sacred time blocks.
    await service.cancelAlert();
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(
      analytics.logNotificationSuppressedSacredTime(
        notificationType: 'streak_alert',
      ),
    );
    return;
  }

  await service.evaluate(hour: time.hour, minute: time.minute);
}
