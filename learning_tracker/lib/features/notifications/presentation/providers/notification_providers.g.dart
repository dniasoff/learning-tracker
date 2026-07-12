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

@ProviderFor(ReminderEnabled)
final reminderEnabledProvider = ReminderEnabledProvider._();

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
final class ReminderEnabledProvider
    extends $AsyncNotifierProvider<ReminderEnabled, bool> {
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
}

String _$reminderEnabledHash() => r'160b694c254c841797f255f15baa9715abff49eb';

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

abstract class _$ReminderEnabled extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
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
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.

@ProviderFor(ReminderTime)
final reminderTimeProvider = ReminderTimeProvider._();

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
final class ReminderTimeProvider
    extends $AsyncNotifierProvider<ReminderTime, TimeOfDay> {
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
}

String _$reminderTimeHash() => r'96baa67da8060b4131242e5b08b8ac98f4860d71';

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

abstract class _$ReminderTime extends $AsyncNotifier<TimeOfDay> {
  FutureOr<TimeOfDay> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TimeOfDay>, TimeOfDay>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TimeOfDay>, TimeOfDay>,
              AsyncValue<TimeOfDay>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.

@ProviderFor(StreakAlertEnabled)
final streakAlertEnabledProvider = StreakAlertEnabledProvider._();

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.
final class StreakAlertEnabledProvider
    extends $AsyncNotifierProvider<StreakAlertEnabled, bool> {
  /// Manages the streak alert enabled state.
  ///
  /// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
  ///
  /// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
  /// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
  /// instead of emitting a hardcoded default first.
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
}

String _$streakAlertEnabledHash() =>
    r'5ed88c67ff82e55dea525f0689deb8a5e435bcd1';

/// Manages the streak alert enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.

abstract class _$StreakAlertEnabled extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
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
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.

@ProviderFor(StreakAlertTime)
final streakAlertTimeProvider = StreakAlertTimeProvider._();

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
final class StreakAlertTimeProvider
    extends $AsyncNotifierProvider<StreakAlertTime, TimeOfDay> {
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
}

String _$streakAlertTimeHash() => r'13e0d7cd28474cc48e3d58e502e2f1b9d38cc378';

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

abstract class _$StreakAlertTime extends $AsyncNotifier<TimeOfDay> {
  FutureOr<TimeOfDay> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TimeOfDay>, TimeOfDay>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TimeOfDay>, TimeOfDay>,
              AsyncValue<TimeOfDay>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.

@ProviderFor(RewardNotificationEnabled)
final rewardNotificationEnabledProvider = RewardNotificationEnabledProvider._();

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.
final class RewardNotificationEnabledProvider
    extends $AsyncNotifierProvider<RewardNotificationEnabled, bool> {
  /// Manages the reward notification enabled state.
  ///
  /// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
  ///
  /// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
  /// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
  /// instead of emitting a hardcoded default first.
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
}

String _$rewardNotificationEnabledHash() =>
    r'0ae063f87c19dbab80a75c524de81f9aca07465e';

/// Manages the reward notification enabled state.
///
/// (WS5.key-prefs) Per-profile namespaced SharedPrefs key.
///
/// AUD-notifications-02 (SM-2): see [ReminderEnabled]'s doc comment — this
/// [AsyncNotifier] genuinely awaits SharedPreferences before resolving
/// instead of emitting a hardcoded default first.

abstract class _$RewardNotificationEnabled extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
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
    r'fdaaf0ac3f6331fe7eb38ccbb31290a62d8cf4c2';

/// Provides the [StreakAlertService] instance for [profileId].
///
/// AUD-notifications-03 (SM-7): family-parameterized by [profileId] so
/// [allProfilesReminderBootstrap] — which must handle every INACTIVE profile,
/// not just the active one — can construct its per-profile [StreakAlertService]
/// through this same provider seam instead of hand-constructing a second
/// instance. A test overriding this family for a specific inactive profileId
/// now observably changes bootstrap's behavior for that profile.

@ProviderFor(streakAlertService)
final streakAlertServiceProvider = StreakAlertServiceFamily._();

/// Provides the [StreakAlertService] instance for [profileId].
///
/// AUD-notifications-03 (SM-7): family-parameterized by [profileId] so
/// [allProfilesReminderBootstrap] — which must handle every INACTIVE profile,
/// not just the active one — can construct its per-profile [StreakAlertService]
/// through this same provider seam instead of hand-constructing a second
/// instance. A test overriding this family for a specific inactive profileId
/// now observably changes bootstrap's behavior for that profile.

final class StreakAlertServiceProvider
    extends
        $FunctionalProvider<
          StreakAlertService,
          StreakAlertService,
          StreakAlertService
        >
    with $Provider<StreakAlertService> {
  /// Provides the [StreakAlertService] instance for [profileId].
  ///
  /// AUD-notifications-03 (SM-7): family-parameterized by [profileId] so
  /// [allProfilesReminderBootstrap] — which must handle every INACTIVE profile,
  /// not just the active one — can construct its per-profile [StreakAlertService]
  /// through this same provider seam instead of hand-constructing a second
  /// instance. A test overriding this family for a specific inactive profileId
  /// now observably changes bootstrap's behavior for that profile.
  StreakAlertServiceProvider._({
    required StreakAlertServiceFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'streakAlertServiceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$streakAlertServiceHash();

  @override
  String toString() {
    return r'streakAlertServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<StreakAlertService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StreakAlertService create(Ref ref) {
    final argument = this.argument as int;
    return streakAlertService(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreakAlertService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreakAlertService>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StreakAlertServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$streakAlertServiceHash() =>
    r'ab2f3dc7c951f97b7eeee2c8bad4c1bcc91b5042';

/// Provides the [StreakAlertService] instance for [profileId].
///
/// AUD-notifications-03 (SM-7): family-parameterized by [profileId] so
/// [allProfilesReminderBootstrap] — which must handle every INACTIVE profile,
/// not just the active one — can construct its per-profile [StreakAlertService]
/// through this same provider seam instead of hand-constructing a second
/// instance. A test overriding this family for a specific inactive profileId
/// now observably changes bootstrap's behavior for that profile.

final class StreakAlertServiceFamily extends $Family
    with $FunctionalFamilyOverride<StreakAlertService, int> {
  StreakAlertServiceFamily._()
    : super(
        retry: null,
        name: r'streakAlertServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides the [StreakAlertService] instance for [profileId].
  ///
  /// AUD-notifications-03 (SM-7): family-parameterized by [profileId] so
  /// [allProfilesReminderBootstrap] — which must handle every INACTIVE profile,
  /// not just the active one — can construct its per-profile [StreakAlertService]
  /// through this same provider seam instead of hand-constructing a second
  /// instance. A test overriding this family for a specific inactive profileId
  /// now observably changes bootstrap's behavior for that profile.

  StreakAlertServiceProvider call(int profileId) =>
      StreakAlertServiceProvider._(argument: profileId, from: this);

  @override
  String toString() => r'streakAlertServiceProvider';
}

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
    r'151499711b34a302a529628b96f0f2967f2c5d72';

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
    r'11c2bf2a4e12459c883390a1e00f1a3aebb4d3ef';
