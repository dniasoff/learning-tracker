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

@ProviderFor(SacredLocationNotifier)
final sacredLocationProvider = SacredLocationNotifierProvider._();

/// Cached device location used for Sacred Time window calculation.
/// Survives app restarts via SharedPreferences. App-global (not per-profile).
final class SacredLocationNotifierProvider
    extends $NotifierProvider<SacredLocationNotifier, SacredLocation?> {
  /// Cached device location used for Sacred Time window calculation.
  /// Survives app restarts via SharedPreferences. App-global (not per-profile).
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
    r'4afc3fc51546607323da3bf65f43375a7bb78a00';

/// Cached device location used for Sacred Time window calculation.
/// Survives app restarts via SharedPreferences. App-global (not per-profile).

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

@ProviderFor(InIsraelNotifier)
final inIsraelProvider = InIsraelNotifierProvider._();

/// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
/// and [setManualCity] from the country code, but the user can flip freely
/// afterwards (e.g. visitors who keep two-day chag while in Israel).
final class InIsraelNotifierProvider
    extends $NotifierProvider<InIsraelNotifier, bool> {
  /// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
  /// and [setManualCity] from the country code, but the user can flip freely
  /// afterwards (e.g. visitors who keep two-day chag while in Israel).
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

String _$inIsraelNotifierHash() => r'42ffc207b60d62ea25c838f0788ab02897d65101';

/// User-toggleable in-Israel flag. Auto-set by [SacredLocationNotifier.detect]
/// and [setManualCity] from the country code, but the user can flip freely
/// afterwards (e.g. visitors who keep two-day chag while in Israel).

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
