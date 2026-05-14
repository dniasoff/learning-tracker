// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registry_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens and owns the device registry database. Lives for the entire
/// app lifetime — opened once at startup, never closed until the
/// process exits.

@ProviderFor(deviceRegistry)
final deviceRegistryProvider = DeviceRegistryProvider._();

/// Opens and owns the device registry database. Lives for the entire
/// app lifetime — opened once at startup, never closed until the
/// process exits.

final class DeviceRegistryProvider
    extends
        $FunctionalProvider<
          DeviceRegistryDatabase,
          DeviceRegistryDatabase,
          DeviceRegistryDatabase
        >
    with $Provider<DeviceRegistryDatabase> {
  /// Opens and owns the device registry database. Lives for the entire
  /// app lifetime — opened once at startup, never closed until the
  /// process exits.
  DeviceRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceRegistryHash();

  @$internal
  @override
  $ProviderElement<DeviceRegistryDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeviceRegistryDatabase create(Ref ref) {
    return deviceRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceRegistryDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceRegistryDatabase>(value),
    );
  }
}

String _$deviceRegistryHash() => r'01f1d1c0303d9883ffb5c366e65add1e7b06892e';
