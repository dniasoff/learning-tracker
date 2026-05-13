// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [NotificationService] singleton.

@ProviderFor(notificationService)
final notificationServiceProvider = NotificationServiceProvider._();

/// Provides the [NotificationService] singleton.

final class NotificationServiceProvider
    extends
        $FunctionalProvider<
          NotificationService,
          NotificationService,
          NotificationService
        >
    with $Provider<NotificationService> {
  /// Provides the [NotificationService] singleton.
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
  $ProviderElement<NotificationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NotificationService create(Ref ref) {
    return notificationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationService>(value),
    );
  }
}

String _$notificationServiceHash() =>
    r'58da87941dbfa08925105dcc4d74091ee38c8593';

/// Manages the daily reminder enabled state.

@ProviderFor(ReminderEnabled)
final reminderEnabledProvider = ReminderEnabledProvider._();

/// Manages the daily reminder enabled state.
final class ReminderEnabledProvider
    extends $NotifierProvider<ReminderEnabled, bool> {
  /// Manages the daily reminder enabled state.
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

String _$reminderEnabledHash() => r'bace316ba99ddebd74e9a93df6bb2ff52d18ba72';

/// Manages the daily reminder enabled state.

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

@ProviderFor(ReminderTime)
final reminderTimeProvider = ReminderTimeProvider._();

/// Manages the daily reminder time.
final class ReminderTimeProvider
    extends $NotifierProvider<ReminderTime, TimeOfDay> {
  /// Manages the daily reminder time.
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

String _$reminderTimeHash() => r'ff7723948eac93bc575d9032f4bc1a7268e6f9a6';

/// Manages the daily reminder time.

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

@ProviderFor(StreakAlertEnabled)
final streakAlertEnabledProvider = StreakAlertEnabledProvider._();

/// Manages the streak alert enabled state.
final class StreakAlertEnabledProvider
    extends $NotifierProvider<StreakAlertEnabled, bool> {
  /// Manages the streak alert enabled state.
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
    r'39a8f700db151c6612bcfba58e6a0f9ff13f71aa';

/// Manages the streak alert enabled state.

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

@ProviderFor(StreakAlertTime)
final streakAlertTimeProvider = StreakAlertTimeProvider._();

/// Manages the streak alert time.
final class StreakAlertTimeProvider
    extends $NotifierProvider<StreakAlertTime, TimeOfDay> {
  /// Manages the streak alert time.
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

String _$streakAlertTimeHash() => r'089d764abf39cbfed3514f2b70015be2e2fa973c';

/// Manages the streak alert time.

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

@ProviderFor(RewardNotificationEnabled)
final rewardNotificationEnabledProvider = RewardNotificationEnabledProvider._();

/// Manages the reward notification enabled state.
final class RewardNotificationEnabledProvider
    extends $NotifierProvider<RewardNotificationEnabled, bool> {
  /// Manages the reward notification enabled state.
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
    r'6a07fd08218442a47f6990a3cb230b2054266252';

/// Manages the reward notification enabled state.

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
    r'605e8d4e6fe317d4c269b36a541f9aa9099e53b6';

/// Watches reminder settings and daily tasks, then schedules or cancels
/// the notification accordingly.
///
/// Also respects sacred time mode — cancels notifications during Shabbos.
///
/// Kept alive so that time/enable changes always trigger a reschedule,
/// even if no UI is watching this provider at the moment.

@ProviderFor(reminderSyncEffect)
final reminderSyncEffectProvider = ReminderSyncEffectProvider._();

/// Watches reminder settings and daily tasks, then schedules or cancels
/// the notification accordingly.
///
/// Also respects sacred time mode — cancels notifications during Shabbos.
///
/// Kept alive so that time/enable changes always trigger a reschedule,
/// even if no UI is watching this provider at the moment.

final class ReminderSyncEffectProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Watches reminder settings and daily tasks, then schedules or cancels
  /// the notification accordingly.
  ///
  /// Also respects sacred time mode — cancels notifications during Shabbos.
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
    r'881c307d8b416c6f28c58e0fe056491e42361e0e';

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
    r'7f4c477313f8129fe6b49a64be24a2d336a76030';
