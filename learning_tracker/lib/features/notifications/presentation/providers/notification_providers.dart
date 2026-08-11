import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/notifications/data/repositories/firestore_notifications_completion_adapter.dart';
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
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_providers.g.dart';

/// AUD-core-preferences-04 (SM-5): wraps [body] the way `AsyncValue.guard`
/// does — but also logs the failure via [AppLogger] under [event] before it
/// becomes the notifier's terminal `AsyncError` state. Plain `AsyncValue.guard`
/// alone drops the failure on the floor with no diagnostic trail, which is
/// exactly the gap this finding closes for [ReminderEnabled], [ReminderTime],
/// [StreakAlertEnabled], [StreakAlertTime], and [RewardNotificationEnabled]'s
/// mutation methods: previously each set `state = AsyncData(next)`
/// optimistically and then awaited the SharedPreferences write with no
/// try/catch anywhere in the chain, so a write failure was an unobserved
/// Future rejection and the toggle silently reverted on next launch.
Future<AsyncValue<T>> _guardedPersist<T>(
  String event,
  Future<T> Function() body,
) {
  return AsyncValue.guard(() async {
    try {
      return await body();
    } catch (e, st) {
      AppLogger.instance.error(event: event, exception: e, stackTrace: st);
      rethrow;
    }
  });
}

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
///
/// AUD-notifications-02 (SM-2): [build] is an [AsyncNotifier] `Future<bool>`
/// that genuinely awaits SharedPreferences before resolving — it never emits
/// a hardcoded `true` default first and then silently flips to the real
/// persisted value. A prior version returned `true` synchronously from
/// `build()` and corrected it once the load completed; any dependent
/// FutureProvider watching the raw value bare could observe (and act on) the
/// wrong default, and Riverpod would tear down/rebuild the dependent mid
/// flight when the value flipped. Consumers now await
/// `reminderEnabledProvider.future` to get the settled value directly.
@riverpod
class ReminderEnabled extends _$ReminderEnabled {
  @override
  Future<bool> build() async {
    // Watch so that when the profile resolves (e.g. 0 → real id on cold start)
    // or switches, build() is re-invoked and re-reads under the correct
    // profile id. Fixes the cold-start race where ref.read returned 0 before
    // the real profile id was available (iter10/iter11).
    final profileId = ref.watch(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          NotificationPreferencesRepository.reminderEnabledKey(profileId),
        ) ??
        true;
  }

  Future<void> toggle() async {
    final next = !(state.value ?? true);
    final profileId = ref.read(activeProfileIdProvider);
    // AUD-core-preferences-04 (SM-5): derive the terminal state from a single
    // guarded call instead of optimistically assigning `state = AsyncData(next)`
    // and then awaiting an unguarded SharedPreferences write — see
    // [_guardedPersist]'s doc comment.
    state = await _guardedPersist(
      'reminder_enabled_toggle_persist_failed',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          NotificationPreferencesRepository.reminderEnabledKey(profileId),
          next,
        );
        return next;
      },
    );
  }
}

/// Manages the daily reminder time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.
@riverpod
class ReminderTime extends _$ReminderTime {
  @override
  Future<TimeOfDay> build() async {
    // Watch so that when the profile resolves (e.g. 0 → real id on cold start)
    // or switches, build() is re-invoked and re-reads under the correct
    // profile id.  Matches the pattern used by [ReminderEnabled].
    final profileId = ref.watch(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
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
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    final profileId = ref.read(activeProfileIdProvider);
    // AUD-core-preferences-04 (SM-5): see [ReminderEnabled.toggle].
    state = await _guardedPersist('reminder_time_set_persist_failed', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        NotificationPreferencesRepository.reminderHourKey(profileId),
        time.hour,
      );
      await prefs.setInt(
        NotificationPreferencesRepository.reminderMinuteKey(profileId),
        time.minute,
      );
      return time;
    });
  }
}

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.
@riverpod
class StreakAlertEnabled extends _$StreakAlertEnabled {
  @override
  Future<bool> build() async {
    // Watch so that a cold-start profile-id change (0 → real id) or a profile
    // switch triggers a rebuild and re-reads prefs under the correct id.
    final profileId = ref.watch(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
        ) ??
        true;
  }

  Future<void> toggle() async {
    final next = !(state.value ?? true);
    final profileId = ref.read(activeProfileIdProvider);
    // AUD-core-preferences-04 (SM-5): see [ReminderEnabled.toggle].
    state = await _guardedPersist(
      'streak_alert_enabled_toggle_persist_failed',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          NotificationPreferencesRepository.streakAlertEnabledKey(profileId),
          next,
        );
        return next;
      },
    );
  }
}

/// Manages the streak alert time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.
@riverpod
class StreakAlertTime extends _$StreakAlertTime {
  @override
  Future<TimeOfDay> build() async {
    // Watch so that when the profile resolves (e.g. 0 → real id on cold start)
    // or switches, build() is re-invoked and re-reads under the correct
    // profile id.  Matches the pattern used by [StreakAlertEnabled].
    final profileId = ref.watch(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
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
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    final profileId = ref.read(activeProfileIdProvider);
    // AUD-core-preferences-04 (SM-5): see [ReminderEnabled.toggle].
    state = await _guardedPersist(
      'streak_alert_time_set_persist_failed',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          NotificationPreferencesRepository.streakAlertHourKey(profileId),
          time.hour,
        );
        await prefs.setInt(
          NotificationPreferencesRepository.streakAlertMinuteKey(profileId),
          time.minute,
        );
        return time;
      },
    );
  }
}

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.
@riverpod
class RewardNotificationEnabled extends _$RewardNotificationEnabled {
  @override
  Future<bool> build() async {
    // Watch so that a cold-start profile-id change (0 → real id) or a profile
    // switch triggers a rebuild and re-reads prefs under the correct id.
    final profileId = ref.watch(activeProfileIdProvider);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(
            profileId,
          ),
        ) ??
        true;
  }

  Future<void> toggle() async {
    final next = !(state.value ?? true);
    final profileId = ref.read(activeProfileIdProvider);
    // AUD-core-preferences-04 (SM-5): see [ReminderEnabled.toggle].
    state = await _guardedPersist(
      'reward_notification_enabled_toggle_persist_failed',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          NotificationPreferencesRepository.rewardNotificationEnabledKey(
            profileId,
          ),
          next,
        );
        return next;
      },
    );
  }
}

/// Builds the canonical settings signature used by [_persistNotificationSettingsToCloud]'s
/// M2 no-op-skip check (below) to decide whether the notification settings
/// have changed since the last cloud push.
///
/// `@visibleForTesting` (AUD-t-notifications-02): extracted from an inline
/// string interpolation inside [_persistNotificationSettingsToCloud] so
/// tests can assert against the REAL signature-building logic instead of
/// hand-copying its format. A hand-copied literal in a test file stays
/// green even if this function drops a field or changes its separator,
/// silently breaking the no-op-skip contract the client-clock LWW fix
/// (FB-2) depends on.
@visibleForTesting
String buildNotificationSettingsSignature({
  required bool reminderEnabled,
  required int reminderHour,
  required int reminderMinute,
  required bool streakEnabled,
  required int streakHour,
  required int streakMinute,
  required bool rewardEnabled,
}) {
  return 'r:$reminderEnabled:$reminderHour:$reminderMinute|'
      's:$streakEnabled:$streakHour:$streakMinute|'
      'w:$rewardEnabled';
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
/// No DB tier: the Drift-era `SacredWindowDao` persistence is deleted (proven
/// dead — nothing in Dart read the windows back, and no native SQLite reader
/// exists), and `docs/firestore-rewrite-map.md` keeps the derived zmanim cache
/// device-local ("Stays local, never leaves the device") — it is not a
/// Firestore migration target, so the repository is constructed bare.
@Riverpod(keepAlive: true)
SacredWindowRepository sacredWindowRepository(Ref ref) {
  return SacredWindowRepository();
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

/// Watches all notification preference providers so the bootstrapper
/// ([notifications_bootstrap.dart]) settles them once at startup.
///
/// The former cloud-sync half of this effect is gone: it enqueued a
/// profile-scoped `notification_settings` document through
/// [OutboxSyncWriteFacade], and the Drift outbox engine it depended on is
/// deleted. Notification settings are SharedPreferences-local per
/// AD-15/AD-27 — `docs/firestore-rewrite-map.md` has no `notification_settings`
/// Firestore target — and the SDK's offline write queue owns any future
/// cloud replication, so there is no push facade to thread here.
final notificationSettingsCloudSyncEffectProvider = FutureProvider<void>((
  ref,
) async {
  // AUD-notifications-02: await each AsyncNotifier's resolved value (not a
  // bare ref.watch) so this effect isn't torn down mid-flight by their own
  // Loading→Data transition on every cold start — mirrors reminderSyncEffect
  // /streakAlertSyncEffect. A bare `ref.watch(reminderEnabledProvider)` here
  // observes that first Loading→Data settle as a "changed" event and
  // reruns/disposes this very build before it can complete (AUD-notifications-01,
  // SM-4: guard after each await, before touching ref again).
  await ref.watch(reminderEnabledProvider.future);
  if (!ref.mounted) return;
  await ref.watch(reminderTimeProvider.future);
  if (!ref.mounted) return;
  await ref.watch(streakAlertEnabledProvider.future);
  if (!ref.mounted) return;
  await ref.watch(streakAlertTimeProvider.future);
  if (!ref.mounted) return;
  await ref.watch(rewardNotificationEnabledProvider.future);
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
  // Watch (but do not branch on) Sacred Time so that a window opening/closing
  // re-runs this effect and rebuilds the per-fire-time-filtered batch: when a
  // window opens the affected fire-times are dropped; when it closes they are
  // restored — all without cancelling the surrounding weekday reminders.
  ref.watch(isSacredTimeActiveProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  // AUD-notifications-02: await the AsyncNotifiers' resolved values directly
  // instead of watching the bare (formerly synchronous-default) providers and
  // re-reading SharedPreferences by hand (the old "M3 fix" workaround).
  // reminderEnabledProvider/reminderTimeProvider now genuinely await their
  // persisted value before resolving, so there is no default-then-flip race
  // to work around here.
  final enabled = await ref.watch(reminderEnabledProvider.future);
  // AUD-notifications-01 (SM-4): guard before touching ref again — this
  // keepAlive effect can be invalidated (profile switch, container teardown)
  // while the await above was in flight.
  if (!ref.mounted) return;
  final time = await ref.watch(reminderTimeProvider.future);
  if (!ref.mounted) return;

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
  // AUD-notifications-01 (SM-4): guard again — another await just completed.
  if (!ref.mounted) return;

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

/// Provides the [StreakAlertService] instance for [profileId].
///
/// AUD-notifications-03 (SM-7): family-parameterized by [profileId] so
/// [allProfilesReminderBootstrap] — which must handle every INACTIVE profile,
/// not just the active one — can construct its per-profile [StreakAlertService]
/// through this same provider seam instead of hand-constructing a second
/// instance. A test overriding this family for a specific inactive profileId
/// now observably changes bootstrap's behavior for that profile.
@riverpod
StreakAlertService streakAlertService(Ref ref, int profileId) {
  final notifService = ref.watch(notificationServiceProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  // The date-range read is injected rather than resolved inside the service:
  // its Firestore implementation lives in the data-access ring, which
  // AD-23/AD-28 forbid a `domain/` file from importing. This provider is the
  // composition root, so the dependency belongs here.
  //
  // The adapter applies the P3-32 cold-cache gate on a `false` answer, which
  // matters more here than on a progress screen: "no completions in range" read
  // from an unsynced cache would fire a SPURIOUS streak-at-risk notification,
  // telling a learner they have not studied when they have.
  final completions = FirestoreNotificationsCompletionAdapter(ref: ref);
  return StreakAlertService(
    ref: ref,
    hasCompletionsInRange: completions.hasCompletionsInRange,
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
  // AUD-notifications-01 (SM-4): this keepAlive effect can be invalidated
  // (e.g. container teardown during navigation/tests) while the above await
  // was in flight — guard before touching ref again.
  if (!ref.mounted) return;
  final gateway = ref.read(notificationServiceProvider);
  final scheduler = ref.read(notificationSchedulerProvider);
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
    // AUD-notifications-03 (SM-7): construct through the family provider seam
    // (not a hand-rolled StreakAlertService(...)) so a test override reaches
    // inactive-profile scheduling too.
    final streakService = ref.read(streakAlertServiceProvider(profileId));
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
  // AUD-notifications-02: await the AsyncNotifiers' resolved values directly
  // (mirrors reminderSyncEffect) so this effect never acts on the
  // synchronous-default-then-flip race a hand-rolled `bool build()` used to
  // produce — see [StreakAlertEnabled]'s doc comment.
  final enabled = await ref.watch(streakAlertEnabledProvider.future);
  // AUD-notifications-01 (SM-4): guard before touching ref again — this
  // keepAlive effect can be invalidated (profile switch, container teardown)
  // while the await above was in flight.
  if (!ref.mounted) return;
  final time = await ref.watch(streakAlertTimeProvider.future);
  if (!ref.mounted) return;
  final profileId = ref.watch(activeProfileIdProvider);
  final service = ref.watch(streakAlertServiceProvider(profileId));
  final sacredTimeActive = ref.watch(isSacredTimeActiveProvider);

  if (!enabled) {
    await service.cancelAlert();
    return;
  }
  if (sacredTimeActive) {
    // Story 27.14 (DNI-390): fire suppression event when sacred time blocks.
    await service.cancelAlert();
    // AUD-notifications-01 (SM-4): guard again — another await just completed.
    if (!ref.mounted) return;
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
