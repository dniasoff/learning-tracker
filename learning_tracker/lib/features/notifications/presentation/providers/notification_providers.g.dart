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
        isAutoDispose: true,
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
    r'cda5ea9d196dce85bee56839a4a0f035021752e3';

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

/// Manages the Shabbos mode enabled state.

@ProviderFor(ShabbosModeEnabled)
final shabbosModeEnabledProvider = ShabbosModeEnabledProvider._();

/// Manages the Shabbos mode enabled state.
final class ShabbosModeEnabledProvider
    extends $NotifierProvider<ShabbosModeEnabled, bool> {
  /// Manages the Shabbos mode enabled state.
  ShabbosModeEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shabbosModeEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shabbosModeEnabledHash();

  @$internal
  @override
  ShabbosModeEnabled create() => ShabbosModeEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$shabbosModeEnabledHash() =>
    r'71a38c7dd929d080d84954e445c7651465f95bad';

/// Manages the Shabbos mode enabled state.

abstract class _$ShabbosModeEnabled extends $Notifier<bool> {
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

/// Manages whether Shabbos mode uses location-based or fixed times.

@ProviderFor(ShabbosModeUseLocation)
final shabbosModeUseLocationProvider = ShabbosModeUseLocationProvider._();

/// Manages whether Shabbos mode uses location-based or fixed times.
final class ShabbosModeUseLocationProvider
    extends $NotifierProvider<ShabbosModeUseLocation, bool> {
  /// Manages whether Shabbos mode uses location-based or fixed times.
  ShabbosModeUseLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shabbosModeUseLocationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shabbosModeUseLocationHash();

  @$internal
  @override
  ShabbosModeUseLocation create() => ShabbosModeUseLocation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$shabbosModeUseLocationHash() =>
    r'52be04fdfc0bbd2388f56d0a83037a13e96001d3';

/// Manages whether Shabbos mode uses location-based or fixed times.

abstract class _$ShabbosModeUseLocation extends $Notifier<bool> {
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

/// Manages the stored latitude for location-based Shabbos mode.

@ProviderFor(ShabbosModeLatitude)
final shabbosModeLatitudeProvider = ShabbosModeLatitudeProvider._();

/// Manages the stored latitude for location-based Shabbos mode.
final class ShabbosModeLatitudeProvider
    extends $NotifierProvider<ShabbosModeLatitude, double> {
  /// Manages the stored latitude for location-based Shabbos mode.
  ShabbosModeLatitudeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shabbosModeLatitudeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shabbosModeLatitudeHash();

  @$internal
  @override
  ShabbosModeLatitude create() => ShabbosModeLatitude();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$shabbosModeLatitudeHash() =>
    r'8e7933dee67a75e0f9e214c05187be6e98406e0a';

/// Manages the stored latitude for location-based Shabbos mode.

abstract class _$ShabbosModeLatitude extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages the stored longitude for location-based Shabbos mode.

@ProviderFor(ShabbosModeLongitude)
final shabbosModeLongitudeProvider = ShabbosModeLongitudeProvider._();

/// Manages the stored longitude for location-based Shabbos mode.
final class ShabbosModeLongitudeProvider
    extends $NotifierProvider<ShabbosModeLongitude, double> {
  /// Manages the stored longitude for location-based Shabbos mode.
  ShabbosModeLongitudeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shabbosModeLongitudeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shabbosModeLongitudeHash();

  @$internal
  @override
  ShabbosModeLongitude create() => ShabbosModeLongitude();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$shabbosModeLongitudeHash() =>
    r'8f912d2e1897bd1264e0e840b9b2ff2ed557a2e8';

/// Manages the stored longitude for location-based Shabbos mode.

abstract class _$ShabbosModeLongitude extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Manages fixed Shabbos start time (candle lighting).

@ProviderFor(ShabbosModeFixedStartTime)
final shabbosModeFixedStartTimeProvider = ShabbosModeFixedStartTimeProvider._();

/// Manages fixed Shabbos start time (candle lighting).
final class ShabbosModeFixedStartTimeProvider
    extends $NotifierProvider<ShabbosModeFixedStartTime, TimeOfDay> {
  /// Manages fixed Shabbos start time (candle lighting).
  ShabbosModeFixedStartTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shabbosModeFixedStartTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shabbosModeFixedStartTimeHash();

  @$internal
  @override
  ShabbosModeFixedStartTime create() => ShabbosModeFixedStartTime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeOfDay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeOfDay>(value),
    );
  }
}

String _$shabbosModeFixedStartTimeHash() =>
    r'e86f6444c3cff71fd09fdfa220c6350f6c08450d';

/// Manages fixed Shabbos start time (candle lighting).

abstract class _$ShabbosModeFixedStartTime extends $Notifier<TimeOfDay> {
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

/// Manages fixed Shabbos end time (havdalah).

@ProviderFor(ShabbosModeFixedEndTime)
final shabbosModeFixedEndTimeProvider = ShabbosModeFixedEndTimeProvider._();

/// Manages fixed Shabbos end time (havdalah).
final class ShabbosModeFixedEndTimeProvider
    extends $NotifierProvider<ShabbosModeFixedEndTime, TimeOfDay> {
  /// Manages fixed Shabbos end time (havdalah).
  ShabbosModeFixedEndTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shabbosModeFixedEndTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shabbosModeFixedEndTimeHash();

  @$internal
  @override
  ShabbosModeFixedEndTime create() => ShabbosModeFixedEndTime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimeOfDay value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimeOfDay>(value),
    );
  }
}

String _$shabbosModeFixedEndTimeHash() =>
    r'0a0245bf826362bb3a1f7362e7cccec68782701c';

/// Manages fixed Shabbos end time (havdalah).

abstract class _$ShabbosModeFixedEndTime extends $Notifier<TimeOfDay> {
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

/// Provides the [ShabbosTimeService] singleton.

@ProviderFor(shabbosTimeService)
final shabbosTimeServiceProvider = ShabbosTimeServiceProvider._();

/// Provides the [ShabbosTimeService] singleton.

final class ShabbosTimeServiceProvider
    extends
        $FunctionalProvider<
          ShabbosTimeService,
          ShabbosTimeService,
          ShabbosTimeService
        >
    with $Provider<ShabbosTimeService> {
  /// Provides the [ShabbosTimeService] singleton.
  ShabbosTimeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shabbosTimeServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shabbosTimeServiceHash();

  @$internal
  @override
  $ProviderElement<ShabbosTimeService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShabbosTimeService create(Ref ref) {
    return shabbosTimeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShabbosTimeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShabbosTimeService>(value),
    );
  }
}

String _$shabbosTimeServiceHash() =>
    r'42e796d1858b80fa4000448963bd29e29fcf8fa9';

/// Returns true if notifications should currently be suppressed due to
/// Shabbos/Yom Tov quiet mode.

@ProviderFor(isShabbosQuietActive)
final isShabbosQuietActiveProvider = IsShabbosQuietActiveProvider._();

/// Returns true if notifications should currently be suppressed due to
/// Shabbos/Yom Tov quiet mode.

final class IsShabbosQuietActiveProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Returns true if notifications should currently be suppressed due to
  /// Shabbos/Yom Tov quiet mode.
  IsShabbosQuietActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isShabbosQuietActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isShabbosQuietActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isShabbosQuietActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isShabbosQuietActiveHash() =>
    r'8b16e8579657d0532adfba000b14e849412b2bbb';

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
    r'c7c31ebd396145bcec7513ef79d2c12cce5c22a3';

/// Watches reminder settings and daily tasks, then schedules or cancels
/// the notification accordingly.
///
/// Also respects Shabbos quiet mode — cancels notifications during Shabbos.

@ProviderFor(reminderSyncEffect)
final reminderSyncEffectProvider = ReminderSyncEffectProvider._();

/// Watches reminder settings and daily tasks, then schedules or cancels
/// the notification accordingly.
///
/// Also respects Shabbos quiet mode — cancels notifications during Shabbos.

final class ReminderSyncEffectProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Watches reminder settings and daily tasks, then schedules or cancels
  /// the notification accordingly.
  ///
  /// Also respects Shabbos quiet mode — cancels notifications during Shabbos.
  ReminderSyncEffectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderSyncEffectProvider',
        isAutoDispose: true,
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
    r'99148d17ab9b44e07164fde54abee196ce22c550';

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
    r'4c4c3c28d951e406d13398f7c9031b5648e4db96';

/// Watches streak alert settings and evaluates whether to schedule or cancel
/// the streak protection alert.
///
/// Also respects Shabbos quiet mode — cancels alerts during Shabbos.

@ProviderFor(streakAlertSyncEffect)
final streakAlertSyncEffectProvider = StreakAlertSyncEffectProvider._();

/// Watches streak alert settings and evaluates whether to schedule or cancel
/// the streak protection alert.
///
/// Also respects Shabbos quiet mode — cancels alerts during Shabbos.

final class StreakAlertSyncEffectProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Watches streak alert settings and evaluates whether to schedule or cancel
  /// the streak protection alert.
  ///
  /// Also respects Shabbos quiet mode — cancels alerts during Shabbos.
  StreakAlertSyncEffectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streakAlertSyncEffectProvider',
        isAutoDispose: true,
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
    r'568bcc892b8b42c99ea64691d38a15e4dc60567f';
