// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_track_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the list of active curricula as [CurriculumId] enums
/// for the parent track management screen.

@ProviderFor(parentTrackCurricula)
final parentTrackCurriculaProvider = ParentTrackCurriculaProvider._();

/// Provides the list of active curricula as [CurriculumId] enums
/// for the parent track management screen.

final class ParentTrackCurriculaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CurriculumId>>,
          List<CurriculumId>,
          FutureOr<List<CurriculumId>>
        >
    with
        $FutureModifier<List<CurriculumId>>,
        $FutureProvider<List<CurriculumId>> {
  /// Provides the list of active curricula as [CurriculumId] enums
  /// for the parent track management screen.
  ParentTrackCurriculaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parentTrackCurriculaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parentTrackCurriculaHash();

  @$internal
  @override
  $FutureProviderElement<List<CurriculumId>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CurriculumId>> create(Ref ref) {
    return parentTrackCurricula(ref);
  }
}

String _$parentTrackCurriculaHash() =>
    r'dec24d2fb4f782d0c92f2958d964bdca78790c13';
