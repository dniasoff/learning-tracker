// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the track repository.

@ProviderFor(trackRepository)
final trackRepositoryProvider = TrackRepositoryProvider._();

/// Provides the track repository.

final class TrackRepositoryProvider
    extends
        $FunctionalProvider<TrackRepository, TrackRepository, TrackRepository>
    with $Provider<TrackRepository> {
  /// Provides the track repository.
  TrackRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackRepositoryHash();

  @$internal
  @override
  $ProviderElement<TrackRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TrackRepository create(Ref ref) {
    return trackRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrackRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrackRepository>(value),
    );
  }
}

String _$trackRepositoryHash() => r'5d47a46993379472783b56a6b373ace0c2a546c6';
