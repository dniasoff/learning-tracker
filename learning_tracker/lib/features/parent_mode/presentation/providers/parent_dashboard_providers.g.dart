// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(parentDashboardAggregator)
final parentDashboardAggregatorProvider = ParentDashboardAggregatorProvider._();

final class ParentDashboardAggregatorProvider
    extends
        $FunctionalProvider<
          ParentDashboardAggregator,
          ParentDashboardAggregator,
          ParentDashboardAggregator
        >
    with $Provider<ParentDashboardAggregator> {
  ParentDashboardAggregatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parentDashboardAggregatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parentDashboardAggregatorHash();

  @$internal
  @override
  $ProviderElement<ParentDashboardAggregator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ParentDashboardAggregator create(Ref ref) {
    return parentDashboardAggregator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ParentDashboardAggregator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ParentDashboardAggregator>(value),
    );
  }
}

String _$parentDashboardAggregatorHash() =>
    r'4997577b5029876400c8e53da4b47c2422c6ca81';

@ProviderFor(parentDashboardData)
final parentDashboardDataProvider = ParentDashboardDataProvider._();

final class ParentDashboardDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParentDashboardData>,
          ParentDashboardData,
          FutureOr<ParentDashboardData>
        >
    with
        $FutureModifier<ParentDashboardData>,
        $FutureProvider<ParentDashboardData> {
  ParentDashboardDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parentDashboardDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parentDashboardDataHash();

  @$internal
  @override
  $FutureProviderElement<ParentDashboardData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParentDashboardData> create(Ref ref) {
    return parentDashboardData(ref);
  }
}

String _$parentDashboardDataHash() =>
    r'1796eb991d529e8f996170e96fa3258f98881c46';
