// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sacred_location_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(locationService)
final locationServiceProvider = LocationServiceProvider._();

final class LocationServiceProvider
    extends
        $FunctionalProvider<LocationService, LocationService, LocationService>
    with $Provider<LocationService> {
  LocationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationServiceHash();

  @$internal
  @override
  $ProviderElement<LocationService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocationService create(Ref ref) {
    return locationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationService>(value),
    );
  }
}

String _$locationServiceHash() => r'781de39d66b80cd814e0941c88d5ae9dd3af48cd';

/// Cached device location used for Sacred Time window calculation.
/// Survives app restarts via SharedPreferences. App-global (not per-profile).
// keepAlive: mirrors a persisted preference read on cold start; must survive widget unmounts so it isn't reloaded on every rebuild.

@ProviderFor(SacredLocationNotifier)
final sacredLocationProvider = SacredLocationNotifierProvider._();

/// Cached device location used for Sacred Time window calculation.
/// Survives app restarts via SharedPreferences. App-global (not per-profile).
// keepAlive: mirrors a persisted preference read on cold start; must survive widget unmounts so it isn't reloaded on every rebuild.
final class SacredLocationNotifierProvider
    extends $NotifierProvider<SacredLocationNotifier, SacredLocation?> {
  /// Cached device location used for Sacred Time window calculation.
  /// Survives app restarts via SharedPreferences. App-global (not per-profile).
  // keepAlive: mirrors a persisted preference read on cold start; must survive widget unmounts so it isn't reloaded on every rebuild.
  SacredLocationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sacredLocationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sacredLocationNotifierHash();

  @$internal
  @override
  SacredLocationNotifier create() => SacredLocationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SacredLocation? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SacredLocation?>(value),
    );
  }
}

String _$sacredLocationNotifierHash() =>
    r'586b0bbcf14475d21b448175a2332876bdc57de4';

/// Cached device location used for Sacred Time window calculation.
/// Survives app restarts via SharedPreferences. App-global (not per-profile).
// keepAlive: mirrors a persisted preference read on cold start; must survive widget unmounts so it isn't reloaded on every rebuild.

abstract class _$SacredLocationNotifier extends $Notifier<SacredLocation?> {
  SacredLocation? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SacredLocation?, SacredLocation?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SacredLocation?, SacredLocation?>,
              SacredLocation?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
/// and [setManualCity] from the country code, but the user can flip freely
/// afterwards (e.g. visitors who keep two-day chag while in Israel).
// keepAlive: the notifier's own _explicitlySet guard must survive widget unmounts, or a rebuild would drop it and let a stale async _load() clobber an explicit user choice.

@ProviderFor(InIsraelNotifier)
final inIsraelProvider = InIsraelNotifierProvider._();

/// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
/// and [setManualCity] from the country code, but the user can flip freely
/// afterwards (e.g. visitors who keep two-day chag while in Israel).
// keepAlive: the notifier's own _explicitlySet guard must survive widget unmounts, or a rebuild would drop it and let a stale async _load() clobber an explicit user choice.
final class InIsraelNotifierProvider
    extends $NotifierProvider<InIsraelNotifier, bool> {
  /// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
  /// and [setManualCity] from the country code, but the user can flip freely
  /// afterwards (e.g. visitors who keep two-day chag while in Israel).
  // keepAlive: the notifier's own _explicitlySet guard must survive widget unmounts, or a rebuild would drop it and let a stale async _load() clobber an explicit user choice.
  InIsraelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inIsraelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inIsraelNotifierHash();

  @$internal
  @override
  InIsraelNotifier create() => InIsraelNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$inIsraelNotifierHash() => r'563160720943c7986bd65c281530a57f4c35ad34';

/// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
/// and [setManualCity] from the country code, but the user can flip freely
/// afterwards (e.g. visitors who keep two-day chag while in Israel).
// keepAlive: the notifier's own _explicitlySet guard must survive widget unmounts, or a rebuild would drop it and let a stale async _load() clobber an explicit user choice.

abstract class _$InIsraelNotifier extends $Notifier<bool> {
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
