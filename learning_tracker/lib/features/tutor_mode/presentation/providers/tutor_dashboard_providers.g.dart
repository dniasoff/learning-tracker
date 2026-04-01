// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tutor_dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tutorDashboardAggregator)
final tutorDashboardAggregatorProvider = TutorDashboardAggregatorProvider._();

final class TutorDashboardAggregatorProvider
    extends
        $FunctionalProvider<
          TutorDashboardAggregator,
          TutorDashboardAggregator,
          TutorDashboardAggregator
        >
    with $Provider<TutorDashboardAggregator> {
  TutorDashboardAggregatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tutorDashboardAggregatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tutorDashboardAggregatorHash();

  @$internal
  @override
  $ProviderElement<TutorDashboardAggregator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TutorDashboardAggregator create(Ref ref) {
    return tutorDashboardAggregator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TutorDashboardAggregator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TutorDashboardAggregator>(value),
    );
  }
}

String _$tutorDashboardAggregatorHash() =>
    r'819c38d0f32520f77a9bdb16bd4d3b1103c2ef5f';

@ProviderFor(tutorDashboardData)
final tutorDashboardDataProvider = TutorDashboardDataProvider._();

final class TutorDashboardDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<TutorDashboardData>,
          TutorDashboardData,
          FutureOr<TutorDashboardData>
        >
    with
        $FutureModifier<TutorDashboardData>,
        $FutureProvider<TutorDashboardData> {
  TutorDashboardDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tutorDashboardDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tutorDashboardDataHash();

  @$internal
  @override
  $FutureProviderElement<TutorDashboardData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TutorDashboardData> create(Ref ref) {
    return tutorDashboardData(ref);
  }
}

String _$tutorDashboardDataHash() =>
    r'36a8ec256bb1fce1b5ea0b182a1b5bb24d8cb463';
