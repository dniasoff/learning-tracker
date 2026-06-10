import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/notifications/data/services/sacred_window_repository.dart';
import 'package:learning_tracker/features/notifications/domain/models/reminder_preferences.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart'
    show NotificationPreferencesRepository;
import 'package:learning_tracker/features/notifications/domain/services/notification_gateway.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_scheduler.dart';
import 'package:learning_tracker/features/notifications/domain/services/streak_alert_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_providers.g.dart';

// ---------------------------------------------------------------------------
// Defaults — re-exported from [ReminderPreferences] for backward compat.
// ---------------------------------------------------------------------------

/// Default reminder time: 7:00 PM.
const int defaultReminderHour = ReminderPreferences.defaultReminderHour;
const int defaultReminderMinute = ReminderPreferences.defaultReminderMinute;

/// Default streak alert time: 9:00 PM.
const int defaultStreakAlertHour = ReminderPreferences.defaultStreakAlertHour;
const int defaultStreakAlertMinute =
    ReminderPreferences.defaultStreakAlertMinute;

/// Provides the [NotificationGateway] singleton.
@Riverpod(keepAlive: true)
NotificationGateway notificationService(Ref ref) {
  return NotificationGateway();
}

/// Manages the daily reminder enabled state.
///
/// (WS5.key-prefs) Reads/writes a per-profile namespaced SharedPrefs key
/// by watching [activeProfileIdProvider] — rebuilds automatically on profile
/// switch, isolating each profile's reminder toggle.
@riverpod
class ReminderEnabled extends _$ReminderEnabled {
  @override
  bool build() {
    // Watch so that when the profile resolves (e.g. 0 → real id on cold start)
    // or switches, build() is re-invoked and _loadFromPrefs runs under the
    // correct profile id. Fixes the cold-start race where ref.read returned 0
    // before the real profile id was available (iter10/iter11).
    final profileId = ref.watch(activeProfileIdProvider);
    _loadFromPrefs(profileId);
    return true; // synchronous default; overwritten once prefs load completes
  }

  Future<void> _loadFromPrefs(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state =
        prefs.getBool(
          NotificationPreferencesRepository.reminderEnabledKey(profileId),
        ) ??
        true;
  }

  Future<void> toggle() async {
    state = !state;
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      NotificationPreferencesRepository.reminderEnabledKey(profileId),
      state,
    );
  }
}

/// Manages the daily reminder time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
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
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour =
        prefs.getInt(
          NotificationPreferencesRepository.reminderHourKey(profileId),
        ) ??
        defaultReminderHour;
    final minute =
        prefs.getInt(
          NotificationPreferencesRepository.reminderMinuteKey(profileId),
        ) ??
        defaultReminderMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      NotificationPreferencesRepository.reminderHourKey(profileId),
      time.hour,
    );
    await prefs.setInt(
      NotificationPreferencesRepository.reminderMinuteKey(profileId),
      time.minute,
    );
  }
}

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
@riverpod
class StreakAlertEnabled extends _$StreakAlertEnabled {
  @override
  bool build() {
    // Watch so that a cold-start profile-id change (0 → real id) or a profile
    // switch triggers a rebuild and re-reads prefs under the correct id.
    final profileId = ref.watch(activeProfileIdProvider);
    _loadFromPrefs(profileId);
    return true; // synchronous default; overwritten once prefs load completes
  }

  Future<void> _loadFromPrefs(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state =
        prefs.getBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
        ) ??
        true;
  }

  Future<void> toggle() async {
    state = !state;
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
      state,
    );
  }
}

/// Manages the streak alert time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
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
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final hour =
        prefs.getInt(
          NotificationPreferencesRepository.streakAlertHourKey(profileId),
        ) ??
        defaultStreakAlertHour;
    final minute =
        prefs.getInt(
          NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
        ) ??
        defaultStreakAlertMinute;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      NotificationPreferencesRepository.streakAlertHourKey(profileId),
      time.hour,
    );
    await prefs.setInt(
      NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
      time.minute,
    );
  }
}

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
@riverpod
class RewardNotificationEnabled extends _$RewardNotificationEnabled {
  @override
  bool build() {
    // Watch so that a cold-start profile-id change (0 → real id) or a profile
    // switch triggers a rebuild and re-reads prefs under the correct id.
    final profileId = ref.watch(activeProfileIdProvider);
    _loadFromPrefs(profileId);
    return true; // synchronous default; overwritten once prefs load completes
  }

  Future<void> _loadFromPrefs(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    state =
        prefs.getBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(
            profileId,
          ),
        ) ??
        true;
  }

  Future<void> toggle() async {
    state = !state;
    final profileId = ref.read(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      NotificationPreferencesRepository.rewardNotificationEnabledKey(profileId),
      state,
    );
  }
}

/// Persist the current notification preference set to Firestore for
/// cloud-born accounts. Local-born accounts remain local-only.
///
/// Phase 1 — routes through [OutboxSyncWriteFacade.enqueueNotificationSettings]
/// so a write made offline is retained and pushed by the next drain. Direct
/// gateway pushes silently lost writes when the device was offline.
Future<void> _persistNotificationSettingsToCloud(
  Ref ref, {
  required SharedPreferences prefs,
  required int profileId,
}) async {
  final outboxFacade = () {
    try {
      return ref.read(outboxSyncWriteFacadeProvider);
    } catch (_) {
      // Some tests build notification providers without full sync dependencies.
      return null;
    }
  }();
  if (outboxFacade == null) return;

  // M2 fix: build a stable signature of the current settings (excluding the
  // timestamp). Only bump updated_at + enqueue a push when this signature
  // differs from the last value we pushed. Pushing unconditionally on every
  // launch/switch advanced updated_at even when nothing changed, letting a
  // stale local win LWW over a newer remote.
  final reminderEnabled =
      prefs.getBool(
        NotificationPreferencesRepository.reminderEnabledKey(profileId),
      ) ??
      true;
  final reminderHour =
      prefs.getInt(
        NotificationPreferencesRepository.reminderHourKey(profileId),
      ) ??
      defaultReminderHour;
  final reminderMinute =
      prefs.getInt(
        NotificationPreferencesRepository.reminderMinuteKey(profileId),
      ) ??
      defaultReminderMinute;
  final streakEnabled =
      prefs.getBool(
        NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
      ) ??
      true;
  final streakHour =
      prefs.getInt(
        NotificationPreferencesRepository.streakAlertHourKey(profileId),
      ) ??
      defaultStreakAlertHour;
  final streakMinute =
      prefs.getInt(
        NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
      ) ??
      defaultStreakAlertMinute;
  final rewardEnabled =
      prefs.getBool(
        NotificationPreferencesRepository.rewardNotificationEnabledKey(
          profileId,
        ),
      ) ??
      true;

  final signature =
      'r:$reminderEnabled:$reminderHour:$reminderMinute|'
      's:$streakEnabled:$streakHour:$streakMinute|'
      'w:$rewardEnabled';
  final lastPushed = prefs.getString(
    NotificationPreferencesRepository.lastPushedSettingsHashKey(profileId),
  );
  if (lastPushed == signature) {
    // Nothing changed since the last push — do not bump updated_at or enqueue.
    return;
  }

  final updatedAtMs = DateTimeFactory.nowUtc().millisecondsSinceEpoch;
  await prefs.setInt(
    NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
      profileId,
    ),
    updatedAtMs,
  );
  await prefs.setString(
    NotificationPreferencesRepository.lastPushedSettingsHashKey(profileId),
    signature,
  );

  await outboxFacade.enqueueNotificationSettings({
    'schema_version': 1,
    'daily_reminder': {
      'enabled': reminderEnabled,
      'hour': reminderHour,
      'minute': reminderMinute,
    },
    'streak_alert': {
      'enabled': streakEnabled,
      'hour': streakHour,
      'minute': streakMinute,
    },
    'reward_notifications': {'enabled': rewardEnabled},
    'updated_at': DateTime.fromMillisecondsSinceEpoch(
      updatedAtMs,
      isUtc: true,
    ).toIso8601String(),
  });
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

  final profileId = ref.watch(activeProfileIdProvider);
  final prefs = await SharedPreferences.getInstance();
  await _persistNotificationSettingsToCloud(
    ref,
    prefs: prefs,
    profileId: profileId,
  );
});

/// Watches reminder settings and daily tasks, then schedules or cancels
/// the notification accordingly.
///
/// DNI-367 (Story 26.24): now schedules a rolling 14-day batch of pre-filtered
/// one-shots instead of a repeating notification. Sacred Time windows are
/// checked per-fire-time by [NotificationScheduler.scheduleReminder].
///
/// Shabbos quiet mode is enforced PER FIRE-TIME inside
/// [NotificationScheduler.buildFireTimesForTest] — any fire-time that falls
/// inside a Sacred Time window is dropped from the batch. We deliberately do
/// NOT blanket-cancel the whole 14-day batch while a window is live: doing so
/// would also drop the surrounding non-Shabbos weekday reminders, which only
/// get re-scheduled when the app is next resumed (or the in-isolate window
/// timer flips). If the app is closed over Shabbos, those weekday reminders
/// would silently never fire. Always (re)scheduling the per-fire-time-filtered
/// batch keeps Shabbos fire-times suppressed while weekday reminders survive.
///
/// Kept alive so that time/enable changes always trigger a reschedule,
/// even if no UI is watching this provider at the moment.
@Riverpod(keepAlive: true)
Future<void> reminderSyncEffect(Ref ref) async {
  // Watch the notifiers so any preference change re-runs this effect, but read
  // the authoritative values from SharedPreferences below.
  ref.watch(reminderEnabledProvider);
  ref.watch(reminderTimeProvider);
  // Watch (but do not branch on) Sacred Time so that a window opening/closing
  // re-runs this effect and rebuilds the per-fire-time-filtered batch: when a
  // window opens the affected fire-times are dropped; when it closes they are
  // restored — all without cancelling the surrounding weekday reminders.
  ref.watch(isSacredTimeActiveProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  // M3 fix: the pref notifiers return defaults (enabled=true, 19:00)
  // synchronously, then async-load the real values. Watching them schedules
  // with DEFAULTS first, briefly scheduling reminders for a profile that has
  // them disabled. Read the real persisted values directly so we never act on
  // the transient default state.
  final prefs = await SharedPreferences.getInstance();
  final enabled =
      prefs.getBool(
        NotificationPreferencesRepository.reminderEnabledKey(profileId),
      ) ??
      true;
  final time = TimeOfDay(
    hour:
        prefs.getInt(
          NotificationPreferencesRepository.reminderHourKey(profileId),
        ) ??
        defaultReminderHour,
    minute:
        prefs.getInt(
          NotificationPreferencesRepository.reminderMinuteKey(profileId),
        ) ??
        defaultReminderMinute,
  );

  if (!enabled) {
    // H1 fix: cancel under the active profile's per-profile ID block.
    await scheduler.cancelForProfile(profileId);
    return;
  }

  // Note: we no longer blanket-cancel the batch when Sacred Time is active.
  // Per-fire-time suppression inside the scheduler drops only the fire-times
  // that actually fall inside a Sacred Time window, so non-Shabbos weekday
  // reminders survive even if the app is closed over Shabbos.

  // Get daily tasks to determine counts for notification body.
  final tasks = await ref.watch(allDailyTasksProvider.future);

  // D1 fix: count only today's units (non-overdue, non-review).
  // Overdue tasks (isOverdue: true) are excluded by the first condition;
  // scheduledChazara tasks (isOverdue: false) are excluded explicitly.
  // Note: overdueChazara tasks have isOverdue: true in production
  // (scheduler_engine.dart:238) so they are already caught by !t.isOverdue —
  // a redundant overdueChazara priority check is not needed here (F-M4).
  final todayTasks = tasks
      .where(
        (t) => !t.isOverdue && t.priority != DailyTaskPriority.scheduledChazara,
      )
      .toList();
  final taskCount = todayTasks.length;
  final curriculumCount = todayTasks.map((t) => t.curriculumId).toSet().length;

  // D2 fix: when there are no tasks today, cancel any existing reminder
  // rather than scheduling "0 tasks today".
  if (taskCount == 0) {
    await scheduler.cancelForProfile(profileId);
    return;
  }

  // Resolve Sacred Location for per-fire-time window filtering (DNI-367).
  final location = ref.read(sacredLocationProvider);
  final inIsrael = ref.read(inIsraelProvider);

  // Build locale-aware notification body (UX-DR7). The active UI locale is
  // resolved from the locale provider and looked up via lookupAppLocalizations,
  // so the background-scheduled body matches the user's chosen language.
  final l10n = lookupAppLocalizations(ref.read(currentAppLocaleProvider));
  final body = l10n.notificationReminderBody(taskCount, curriculumCount);

  // H1 fix: schedule under the active profile's per-profile batch ID block so
  // there is exactly ONE daily-reminder scheme for every profile (the
  // bootstrap below skips the active profile, deferring to this reactive path).
  await scheduler.scheduleReminderForProfile(
    profileId: profileId,
    time: time,
    title: l10n.notificationReminderTitle,
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

// ---------------------------------------------------------------------------
// WS5.per-profile — Schedule reminders for ALL profiles on startup (DEC-28)
//
// Each profile has its own reminder schedule that must fire whether or not
// that profile is the currently-active one. [allProfilesReminderBootstrap]
// iterates every profile in the current account and schedules daily reminder
// notifications using that profile's stored SharedPreferences prefs. The
// payload embeds the profileId so [NotificationInitializer._handleNotificationTap]
// can switch into the correct profile before navigating.
//
// This provider is kept alive and observed at bootstrap alongside
// [reminderSyncEffectProvider]. It does NOT replace [reminderSyncEffect] —
// the two work together: [reminderSyncEffect] handles the active profile
// reactively (responding to preference changes), while
// [allProfilesReminderBootstrap] ensures inactive profiles are also scheduled.
// ---------------------------------------------------------------------------

/// Schedules daily reminder notifications for every profile in the current
/// account, using each profile's own stored notification preferences.
///
/// (WS5.per-profile / DEC-28) Inactive profiles' reminders must still fire.
///
/// Called once at login / app startup. Does not interfere with
/// [reminderSyncEffectProvider] which handles live-reactivity for the active
/// profile.
@Riverpod(keepAlive: true)
Future<void> allProfilesReminderBootstrap(Ref ref) async {
  // (H3) Watch the reactive profile stream so a profile add/delete re-runs the
  // reconcile without a cold restart.
  final profiles = await ref.watch(profileListStreamProvider.future);
  final gateway = ref.read(notificationServiceProvider);
  final scheduler = ref.read(notificationSchedulerProvider);
  final db = ref.read(userDatabaseProvider);
  final analytics = ref.read(analyticsServiceProvider);
  final sacredTimeActive = ref.watch(isSacredTimeActiveProvider);
  final activeProfileId = ref.watch(activeProfileIdProvider);

  // L2: resolve Sacred Location so per-profile reminders get the SAME per-fire
  // Sacred-Time suppression the active path uses (not just a one-time global
  // check).
  final location = ref.read(sacredLocationProvider);
  final inIsrael = ref.read(inIsraelProvider);

  // Locale-aware notification copy (UX-DR7) resolved from the active UI locale.
  final l10n = lookupAppLocalizations(ref.read(currentAppLocaleProvider));

  final prefs = await SharedPreferences.getInstance();

  final presentIds = profiles.map((p) => p.id).toSet();

  // (H3) Reconcile against the previously-scheduled set: cancel reminders +
  // streak alerts for any profile that has since been removed, so a deleted
  // profile's repeating reminder no longer fires (and no longer tries to switch
  // into a nonexistent profile when tapped).
  final previousIds =
      (prefs.getString(
                NotificationPreferencesRepository.scheduledProfileIdsKey,
              ) ??
              '')
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toSet();

  for (final removedId in previousIds.difference(presentIds)) {
    await scheduler.cancelForProfile(removedId);
    await gateway.cancelStreakAlertForProfile(removedId);
  }

  for (final profile in profiles) {
    final profileId = profile.id;

    // (H1) The active profile's daily reminder is owned by
    // [reminderSyncEffect], which schedules under the same per-profile batch ID
    // block. Skipping it here prevents the active profile receiving two
    // competing daily reminders. Streak alerts for the active profile are owned
    // by [streakAlertSyncEffect]; only inactive profiles need bootstrapping.
    if (profileId == activeProfileId) continue;

    // --- Daily reminder (inactive profile) ---
    final reminderEnabled =
        prefs.getBool(
          NotificationPreferencesRepository.reminderEnabledKey(profileId),
        ) ??
        true;
    // Do NOT blanket-cancel on sacredTimeActive: the batch path below filters
    // each fire-time against the Sacred-Time window, so weekday reminders
    // survive while Shabbos fire-times stay suppressed even if the app is
    // closed over Shabbos.
    if (!reminderEnabled) {
      await scheduler.cancelForProfile(profileId);
    } else {
      final hour =
          prefs.getInt(
            NotificationPreferencesRepository.reminderHourKey(profileId),
          ) ??
          defaultReminderHour;
      final minute =
          prefs.getInt(
            NotificationPreferencesRepository.reminderMinuteKey(profileId),
          ) ??
          defaultReminderMinute;

      // L2: route through the scheduler's batch path so each fire-time is
      // filtered against the Sacred-Time window, identical to the active path.
      await scheduler.scheduleReminderForProfile(
        profileId: profileId,
        time: TimeOfDay(hour: hour, minute: minute),
        title: l10n.notificationReminderTitle,
        body: l10n.notificationReminderGenericBody,
        location: location,
        inIsrael: inIsrael,
      );
    }

    // --- Streak alert (inactive profile, H2) ---
    final streakEnabled =
        prefs.getBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
        ) ??
        true;
    final streakService = StreakAlertService(
      db: db,
      notificationService: gateway,
      profileId: profileId,
      analytics: analytics,
    );
    if (!streakEnabled || sacredTimeActive) {
      await streakService.cancelAlert();
    } else {
      final streakHour =
          prefs.getInt(
            NotificationPreferencesRepository.streakAlertHourKey(profileId),
          ) ??
          defaultStreakAlertHour;
      final streakMinute =
          prefs.getInt(
            NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
          ) ??
          defaultStreakAlertMinute;
      await streakService.evaluate(
        hour: streakHour,
        minute: streakMinute,
        title: l10n.notificationStreakTitle,
        localizedBody: l10n.notificationStreakBody,
      );
    }
  }

  // Record the full present set for the next reconcile (H3).
  await prefs.setString(
    NotificationPreferencesRepository.scheduledProfileIdsKey,
    presentIds.join(','),
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

  final l10n = lookupAppLocalizations(ref.read(currentAppLocaleProvider));
  await service.evaluate(
    hour: time.hour,
    minute: time.minute,
    title: l10n.notificationStreakTitle,
    localizedBody: l10n.notificationStreakBody,
  );
}
