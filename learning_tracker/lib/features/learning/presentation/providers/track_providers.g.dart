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

String _$trackRepositoryHash() => r'9ef1aee581734a13820140be7d032f6fddee3457';

/// Provides the list of active tracks for a specific curriculum.

@ProviderFor(activeTracks)
final activeTracksProvider = ActiveTracksFamily._();

/// Provides the list of active tracks for a specific curriculum.

final class ActiveTracksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TrackType>>,
          List<TrackType>,
          FutureOr<List<TrackType>>
        >
    with $FutureModifier<List<TrackType>>, $FutureProvider<List<TrackType>> {
  /// Provides the list of active tracks for a specific curriculum.
  ActiveTracksProvider._({
    required ActiveTracksFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'activeTracksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeTracksHash();

  @override
  String toString() {
    return r'activeTracksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TrackType>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TrackType>> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return activeTracks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveTracksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeTracksHash() => r'0783617654494822ac70c440ce752b9b0a7d9ad4';

/// Provides the list of active tracks for a specific curriculum.

final class ActiveTracksFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<TrackType>>, CurriculumId> {
  ActiveTracksFamily._()
    : super(
        retry: null,
        name: r'activeTracksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides the list of active tracks for a specific curriculum.

  ActiveTracksProvider call(CurriculumId curriculumId) =>
      ActiveTracksProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'activeTracksProvider';
}

/// Checks if a specific track is active for a curriculum.

@ProviderFor(isTrackActive)
final isTrackActiveProvider = IsTrackActiveFamily._();

/// Checks if a specific track is active for a curriculum.

final class IsTrackActiveProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Checks if a specific track is active for a curriculum.
  IsTrackActiveProvider._({
    required IsTrackActiveFamily super.from,
    required (CurriculumId, TrackType) super.argument,
  }) : super(
         retry: null,
         name: r'isTrackActiveProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isTrackActiveHash();

  @override
  String toString() {
    return r'isTrackActiveProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as (CurriculumId, TrackType);
    return isTrackActive(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is IsTrackActiveProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isTrackActiveHash() => r'cb94fabd7a15ce9660e451fb864010ce113adb01';

/// Checks if a specific track is active for a curriculum.

final class IsTrackActiveFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, (CurriculumId, TrackType)> {
  IsTrackActiveFamily._()
    : super(
        retry: null,
        name: r'isTrackActiveProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Checks if a specific track is active for a curriculum.

  IsTrackActiveProvider call(CurriculumId curriculumId, TrackType trackType) =>
      IsTrackActiveProvider._(argument: (curriculumId, trackType), from: this);

  @override
  String toString() => r'isTrackActiveProvider';
}
