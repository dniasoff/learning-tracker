// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [NotificationGateway] singleton.

@ProviderFor(notificationService)
final notificationServiceProvider = NotificationServiceProvider._();

/// Provides the [NotificationGateway] singleton.

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationGateway,
          NotificationGateway,
          NotificationGateway
        >
    with $Provider<NotificationGateway> {
  /// Provides the [NotificationGateway] singleton.
  NotificationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationServiceHash();

  @$internal
  @override
  $ProviderElement<NotificationGateway> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationGateway create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationGateway>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'80ef32c7c0cd079a947bfaacca19025a6273f7dd';

/// Manages the daily reminder enabled state.
///
/// (WS5.key-prefs) Reads/writes a per-profile namespaced SharedPrefs key
/// by watching [activeProfileIdProvider] — rebuilds automatically on profile
/// switch, isolating each profile's reminder toggle.

@ProviderFor(ReminderEnabled)
final reminderEnabledProvider = ReminderEnabledProvider._();

/// Manages the daily reminder enabled state.
///
/// (WS5.key-prefs) Reads/writes a per-profile namespaced SharedPrefs key
/// by watching [activeProfileIdProvider] — rebuilds automatically on profile
/// switch, isolating each profile's reminder toggle.
final class ReminderEnabledProvider
    extends $NotifierProvider<ReminderEnabled, bool> {
  /// Manages the daily reminder enabled state.
  ///
  /// (WS5.key-prefs) Reads/writes a per-profile namespaced SharedPrefs key
  /// by watching [activeProfileIdProvider] — rebuilds automatically on profile
  /// switch, isolating each profile's reminder toggle.
  ReminderEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderEnabledHash();

  @$internal
  @override
  ReminderEnabled create() => ReminderEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$reminderEnabledHash() => r'36f73bfff7fadc6154219fb3ccd91426d263ff39';

/// Manages the daily reminder enabled state.
///
/// (WS5.key-prefs) Reads/writes a per-profile namespaced SharedPrefs key
/// by watching [activeProfileIdProvider] — rebuilds automatically on profile
/// switch, isolating each profile's reminder toggle.

abstract class _$ReminderEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the daily reminder time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.

@ProviderFor(ReminderTime)
final reminderTimeProvider = ReminderTimeProvider._();

/// Manages the daily reminder time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.
final class ReminderTimeProvider
    extends $NotifierProvider<ReminderTime, TimeOfDay> {
  /// Manages the daily reminder time.
  ///
  /// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
  ///
  /// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
  /// 0→real-id transition or a mid-session profile switch triggers a rebuild
  /// and re-reads the stored time from the correct per-profile key.
  ReminderTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderTimeHash();

  @$internal
  @override
  ReminderTime create() => ReminderTime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeOfDay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeOfDay>(value),
    );
  }
}

String _$reminderTimeHash() => r'67e64420ba80e954cb1bdcc0f46ecf9233aabe2d';

/// Manages the daily reminder time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.

abstract class _$ReminderTime extends $Notifier<TimeOfDay> {
  TimeOfDay build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TimeOfDay, TimeOfDay>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TimeOfDay, TimeOfDay>,
              TimeOfDay,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.

@ProviderFor(StreakAlertEnabled)
final streakAlertEnabledProvider = StreakAlertEnabledProvider._();

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
final class StreakAlertEnabledProvider
    extends $NotifierProvider<StreakAlertEnabled, bool> {
  /// Manages the streak alert enabled state.
  ///
  /// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
  StreakAlertEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakAlertEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakAlertEnabledHash();

  @$internal
  @override
  StreakAlertEnabled create() => StreakAlertEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$streakAlertEnabledHash() =>
    r'a4c5b0e07de04ba3c25215a0efe66898fc85be00';

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.

abstract class _$StreakAlertEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the streak alert time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.

@ProviderFor(StreakAlertTime)
final streakAlertTimeProvider = StreakAlertTimeProvider._();

/// Manages the streak alert time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.
final class StreakAlertTimeProvider
    extends $NotifierProvider<StreakAlertTime, TimeOfDay> {
  /// Manages the streak alert time.
  ///
  /// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
  ///
  /// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
  /// 0→real-id transition or a mid-session profile switch triggers a rebuild
  /// and re-reads the stored time from the correct per-profile key.
  StreakAlertTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakAlertTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakAlertTimeHash();

  @$internal
  @override
  StreakAlertTime create() => StreakAlertTime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeOfDay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeOfDay>(value),
    );
  }
}

String _$streakAlertTimeHash() => r'a1c8b0b8c41a878b46c544f8aa9d6ee03e4222c4';

/// Manages the streak alert time.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// ST-1 fix: watch [activeProfileIdProvider] (not read) so that a cold-start
/// 0→real-id transition or a mid-session profile switch triggers a rebuild
/// and re-reads the stored time from the correct per-profile key.

abstract class _$StreakAlertTime extends $Notifier<TimeOfDay> {
  TimeOfDay build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<TimeOfDay, TimeOfDay>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TimeOfDay, TimeOfDay>,
              TimeOfDay,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.

@ProviderFor(RewardNotificationEnabled)
final rewardNotificationEnabledProvider = RewardNotificationEnabledProvider._();

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
final class RewardNotificationEnabledProvider
    extends $NotifierProvider<RewardNotificationEnabled, bool> {
  /// Manages the reward notification enabled state.
  ///
  /// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
  RewardNotificationEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rewardNotificationEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rewardNotificationEnabledHash();

  @$internal
  @override
  RewardNotificationEnabled create() => RewardNotificationEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$rewardNotificationEnabledHash() =>
    r'a22303b86b385025ffb19c0b7263426b24b05a7b';

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.

abstract class _$RewardNotificationEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Returns true if notifications should currently be suppressed because
/// Sacred Time is active. Backed by [currentSacredWindowProvider] —
/// notifications follow the same window the lock screen does.

@ProviderFor(isSacredTimeActive)
final isSacredTimeActiveProvider = IsSacredTimeActiveProvider._();

/// Returns true if notifications should currently be suppressed because
/// Sacred Time is active. Backed by [currentSacredWindowProvider] —
/// notifications follow the same window the lock screen does.

final class IsSacredTimeActiveProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Returns true if notifications should currently be suppressed because
  /// Sacred Time is active. Backed by [currentSacredWindowProvider] —
  /// notifications follow the same window the lock screen does.
  IsSacredTimeActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isSacredTimeActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isSacredTimeActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isSacredTimeActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isSacredTimeActiveHash() =>
    r'd1c02e4f2f10995baf550dbfde9fbfd589492dc6';

/// Provides the [SacredWindowRepository] singleton.
///
/// Kept alive so the in-memory cache survives across provider rebuilds.
/// [TimezoneLifecycleObserver] calls [SacredWindowRepository.invalidate]
/// on resume (DNI-367).
///
/// The [SacredWindowDao] is injected so computed windows are persisted to
/// the user DB, enabling background notification fire-time checks on
/// cold-start without the Flutter engine (DNI-367 AC 26.24 requirement 4).

@ProviderFor(sacredWindowRepository)
final sacredWindowRepositoryProvider = SacredWindowRepositoryProvider._();

/// Provides the [SacredWindowRepository] singleton.
///
/// Kept alive so the in-memory cache survives across provider rebuilds.
/// [TimezoneLifecycleObserver] calls [SacredWindowRepository.invalidate]
/// on resume (DNI-367).
///
/// The [SacredWindowDao] is injected so computed windows are persisted to
/// the user DB, enabling background notification fire-time checks on
/// cold-start without the Flutter engine (DNI-367 AC 26.24 requirement 4).

final class SacredWindowRepositoryProvider
    extends
        $FunctionalProvider<
          SacredWindowRepository,
          SacredWindowRepository,
          SacredWindowRepository
        >
    with $Provider<SacredWindowRepository> {
  /// Provides the [SacredWindowRepository] singleton.
  ///
  /// Kept alive so the in-memory cache survives across provider rebuilds.
  /// [TimezoneLifecycleObserver] calls [SacredWindowRepository.invalidate]
  /// on resume (DNI-367).
  ///
  /// The [SacredWindowDao] is injected so computed windows are persisted to
  /// the user DB, enabling background notification fire-time checks on
  /// cold-start without the Flutter engine (DNI-367 AC 26.24 requirement 4).
  SacredWindowRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sacredWindowRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sacredWindowRepositoryHash();

  @$internal
  @override
  $ProviderElement<SacredWindowRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SacredWindowRepository create(Ref ref) {
    return sacredWindowRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SacredWindowRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SacredWindowRepository>(value),
    );
  }
}

String _$sacredWindowRepositoryHash() =>
    r'13530eafd0fbfd2938f84a78941349af7d86d81f';

/// Provides the [NotificationScheduler] instance.

@ProviderFor(notificationScheduler)
final notificationSchedulerProvider = NotificationSchedulerProvider._();

/// Provides the [NotificationScheduler] instance.

final class NotificationSchedulerProvider
    extends
        $FunctionalProvider<
          NotificationScheduler,
          NotificationScheduler,
          NotificationScheduler
        >
    with $Provider<NotificationScheduler> {
  /// Provides the [NotificationScheduler] instance.
  NotificationSchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationSchedulerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationSchedulerHash();

  @$internal
  @override
  $ProviderElement<NotificationScheduler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationScheduler create(Ref ref) {
    return notificationScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationScheduler>(value),
    );
  }
}

String _$notificationSchedulerHash() =>
    r'03597a17d9f0f098a5e5e09a941b7b808db154bb';

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

@ProviderFor(reminderSyncEffect)
final reminderSyncEffectProvider = ReminderSyncEffectProvider._();

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

final class ReminderSyncEffectProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
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
  ReminderSyncEffectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderSyncEffectProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderSyncEffectHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return reminderSyncEffect(ref);
  }
}

String _$reminderSyncEffectHash() =>
    r'd15feea3b70e6f676c213817e7b29ba1cf72fa84';

/// Provides the [StreakAlertService] instance.

@ProviderFor(streakAlertService)
final streakAlertServiceProvider = StreakAlertServiceProvider._();

/// Provides the [StreakAlertService] instance.

final class StreakAlertServiceProvider
    extends
        $FunctionalProvider<
          StreakAlertService,
          StreakAlertService,
          StreakAlertService
        >
    with $Provider<StreakAlertService> {
  /// Provides the [StreakAlertService] instance.
  StreakAlertServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakAlertServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakAlertServiceHash();

  @$internal
  @override
  $ProviderElement<StreakAlertService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StreakAlertService create(Ref ref) {
    return streakAlertService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreakAlertService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreakAlertService>(value),
    );
  }
}

String _$streakAlertServiceHash() =>
    r'095dcecb6259740ab0957146fc6abde80d0f8d7a';

/// Schedules daily reminder notifications for every profile in the current
/// account, using each profile's own stored notification preferences.
///
/// (WS5.per-profile / DEC-28) Inactive profiles' reminders must still fire.
///
/// Called once at login / app startup. Does not interfere with
/// [reminderSyncEffectProvider] which handles live-reactivity for the active
/// profile.

@ProviderFor(allProfilesReminderBootstrap)
final allProfilesReminderBootstrapProvider =
    AllProfilesReminderBootstrapProvider._();

/// Schedules daily reminder notifications for every profile in the current
/// account, using each profile's own stored notification preferences.
///
/// (WS5.per-profile / DEC-28) Inactive profiles' reminders must still fire.
///
/// Called once at login / app startup. Does not interfere with
/// [reminderSyncEffectProvider] which handles live-reactivity for the active
/// profile.

final class AllProfilesReminderBootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Schedules daily reminder notifications for every profile in the current
  /// account, using each profile's own stored notification preferences.
  ///
  /// (WS5.per-profile / DEC-28) Inactive profiles' reminders must still fire.
  ///
  /// Called once at login / app startup. Does not interfere with
  /// [reminderSyncEffectProvider] which handles live-reactivity for the active
  /// profile.
  AllProfilesReminderBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allProfilesReminderBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allProfilesReminderBootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return allProfilesReminderBootstrap(ref);
  }
}

String _$allProfilesReminderBootstrapHash() =>
    r'1b677e4d36fb8a0f0186f88c04a24bf8a2519224';

/// Watches streak alert settings and evaluates whether to schedule or cancel
/// the streak protection alert.
///
/// Also respects sacred time mode — cancels alerts during Shabbos.
///
/// Kept alive so that time/enable changes always trigger a reschedule,
/// even if no UI is watching this provider at the moment.

@ProviderFor(streakAlertSyncEffect)
final streakAlertSyncEffectProvider = StreakAlertSyncEffectProvider._();

/// Watches streak alert settings and evaluates whether to schedule or cancel
/// the streak protection alert.
///
/// Also respects sacred time mode — cancels alerts during Shabbos.
///
/// Kept alive so that time/enable changes always trigger a reschedule,
/// even if no UI is watching this provider at the moment.

final class StreakAlertSyncEffectProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Watches streak alert settings and evaluates whether to schedule or cancel
  /// the streak protection alert.
  ///
  /// Also respects sacred time mode — cancels alerts during Shabbos.
  ///
  /// Kept alive so that time/enable changes always trigger a reschedule,
  /// even if no UI is watching this provider at the moment.
  StreakAlertSyncEffectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakAlertSyncEffectProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streakAlertSyncEffectHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return streakAlertSyncEffect(ref);
  }
}

String _$streakAlertSyncEffectHash() =>
    r'028c42b23c60d7d010feab2502f9b09955c0b7ef';
