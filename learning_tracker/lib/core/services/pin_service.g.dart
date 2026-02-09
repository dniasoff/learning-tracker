// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the PIN service.

@ProviderFor(pinService)
const pinServiceProvider = PinServiceProvider._();

/// Provider for the PIN service.

final class PinServiceProvider
    extends $FunctionalProvider<PinService, PinService, PinService>
    with $Provider<PinService> {
  /// Provider for the PIN service.
  const PinServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinServiceHash();

  @$internal
  @override
  $ProviderElement<PinService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PinService create(Ref ref) {
    return pinService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PinService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PinService>(value),
    );
  }
}

String _$pinServiceHash() => r'b18b324668beafd43c803d3ab622e488a460e30d';
