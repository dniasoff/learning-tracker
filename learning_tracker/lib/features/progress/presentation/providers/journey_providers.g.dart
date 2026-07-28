// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journey_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Sort mode toggle for journey screen (grouped vs chronological).

@ProviderFor(JourneySortModeNotifier)
final journeySortModeProvider = JourneySortModeNotifierProvider._();

/// Sort mode toggle for journey screen (grouped vs chronological).
final class JourneySortModeNotifierProvider
    extends $NotifierProvider<JourneySortModeNotifier, JourneySortModeValue> {
  /// Sort mode toggle for journey screen (grouped vs chronological).
  JourneySortModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journeySortModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journeySortModeNotifierHash();

  @$internal
  @override
  JourneySortModeNotifier create() => JourneySortModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JourneySortModeValue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JourneySortModeValue>(value),
    );
  }
}

String _$journeySortModeNotifierHash() =>
    r'8adc83e7baa4c71124ab4dc3b4b140bec4647e8b';

/// Sort mode toggle for journey screen (grouped vs chronological).

abstract class _$JourneySortModeNotifier
    extends $Notifier<JourneySortModeValue> {
  JourneySortModeValue build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<JourneySortModeValue, JourneySortModeValue>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<JourneySortModeValue, JourneySortModeValue>,
              JourneySortModeValue,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Computes the full JourneyViewModel for a given profile.

@ProviderFor(journeyViewModel)
final journeyViewModelProvider = JourneyViewModelFamily._();

/// Computes the full JourneyViewModel for a given profile.

final class JourneyViewModelProvider
    extends
        $FunctionalProvider<
          AsyncValue<JourneyViewModel>,
          JourneyViewModel,
          FutureOr<JourneyViewModel>
        >
    with $FutureModifier<JourneyViewModel>, $FutureProvider<JourneyViewModel> {
  /// Computes the full JourneyViewModel for a given profile.
  JourneyViewModelProvider._({
    required JourneyViewModelFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'journeyViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$journeyViewModelHash();

  @override
  String toString() {
    return r'journeyViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<JourneyViewModel> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<JourneyViewModel> create(Ref ref) {
    final argument = this.argument as int;
    return journeyViewModel(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JourneyViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$journeyViewModelHash() => r'9eaa660b66a70cf78c2e1c8f102a3bdb92a5dcdc';

/// Computes the full JourneyViewModel for a given profile.

final class JourneyViewModelFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<JourneyViewModel>, int> {
  JourneyViewModelFamily._()
    : super(
        retry: null,
        name: r'journeyViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Computes the full JourneyViewModel for a given profile.

  JourneyViewModelProvider call(int profileId) =>
      JourneyViewModelProvider._(argument: profileId, from: this);

  @override
  String toString() => r'journeyViewModelProvider';
}

/// The siyum tiers offered for [curriculum] in Settings, finest → coarsest.
///
/// Always includes [MilestoneLevel.unit] (per-masechta/sefer/siman/hilchos)
/// and [MilestoneLevel.curriculum] (the whole-curriculum siyum). The
/// [MilestoneLevel.aggregate] (seder-style) tier is offered only when the
/// curriculum's content exposes a *meaningful* aggregate: it must both pass
/// [_hasAggregateLevel] (the same predicate that gates aggregate emission, so
/// the UI can never offer a tier the engine won't fire) AND have more than one
/// level-1 group. The second clause excludes a degenerate single-group
/// "aggregate" that coincides with the whole curriculum (Mishna Berurah's one
/// book of 697 simanim), which would otherwise duplicate the curriculum tier.
///
/// The list is a strict superset relationship to emission: a tier absent here
/// is only ever a tier the granularity gate could suppress, never one it would
/// fabricate.

@ProviderFor(availableSiyumTiers)
final availableSiyumTiersProvider = AvailableSiyumTiersFamily._();

/// The siyum tiers offered for [curriculum] in Settings, finest → coarsest.
///
/// Always includes [MilestoneLevel.unit] (per-masechta/sefer/siman/hilchos)
/// and [MilestoneLevel.curriculum] (the whole-curriculum siyum). The
/// [MilestoneLevel.aggregate] (seder-style) tier is offered only when the
/// curriculum's content exposes a *meaningful* aggregate: it must both pass
/// [_hasAggregateLevel] (the same predicate that gates aggregate emission, so
/// the UI can never offer a tier the engine won't fire) AND have more than one
/// level-1 group. The second clause excludes a degenerate single-group
/// "aggregate" that coincides with the whole curriculum (Mishna Berurah's one
/// book of 697 simanim), which would otherwise duplicate the curriculum tier.
///
/// The list is a strict superset relationship to emission: a tier absent here
/// is only ever a tier the granularity gate could suppress, never one it would
/// fabricate.

final class AvailableSiyumTiersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MilestoneLevel>>,
          List<MilestoneLevel>,
          FutureOr<List<MilestoneLevel>>
        >
    with
        $FutureModifier<List<MilestoneLevel>>,
        $FutureProvider<List<MilestoneLevel>> {
  /// The siyum tiers offered for [curriculum] in Settings, finest → coarsest.
  ///
  /// Always includes [MilestoneLevel.unit] (per-masechta/sefer/siman/hilchos)
  /// and [MilestoneLevel.curriculum] (the whole-curriculum siyum). The
  /// [MilestoneLevel.aggregate] (seder-style) tier is offered only when the
  /// curriculum's content exposes a *meaningful* aggregate: it must both pass
  /// [_hasAggregateLevel] (the same predicate that gates aggregate emission, so
  /// the UI can never offer a tier the engine won't fire) AND have more than one
  /// level-1 group. The second clause excludes a degenerate single-group
  /// "aggregate" that coincides with the whole curriculum (Mishna Berurah's one
  /// book of 697 simanim), which would otherwise duplicate the curriculum tier.
  ///
  /// The list is a strict superset relationship to emission: a tier absent here
  /// is only ever a tier the granularity gate could suppress, never one it would
  /// fabricate.
  AvailableSiyumTiersProvider._({
    required AvailableSiyumTiersFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'availableSiyumTiersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$availableSiyumTiersHash();

  @override
  String toString() {
    return r'availableSiyumTiersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MilestoneLevel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MilestoneLevel>> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return availableSiyumTiers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AvailableSiyumTiersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$availableSiyumTiersHash() =>
    r'dc44f57d4d31b748c624ed585bbc6c8bd9b6bd75';

/// The siyum tiers offered for [curriculum] in Settings, finest → coarsest.
///
/// Always includes [MilestoneLevel.unit] (per-masechta/sefer/siman/hilchos)
/// and [MilestoneLevel.curriculum] (the whole-curriculum siyum). The
/// [MilestoneLevel.aggregate] (seder-style) tier is offered only when the
/// curriculum's content exposes a *meaningful* aggregate: it must both pass
/// [_hasAggregateLevel] (the same predicate that gates aggregate emission, so
/// the UI can never offer a tier the engine won't fire) AND have more than one
/// level-1 group. The second clause excludes a degenerate single-group
/// "aggregate" that coincides with the whole curriculum (Mishna Berurah's one
/// book of 697 simanim), which would otherwise duplicate the curriculum tier.
///
/// The list is a strict superset relationship to emission: a tier absent here
/// is only ever a tier the granularity gate could suppress, never one it would
/// fabricate.

final class AvailableSiyumTiersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<MilestoneLevel>>,
          CurriculumId
        > {
  AvailableSiyumTiersFamily._()
    : super(
        retry: null,
        name: r'availableSiyumTiersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The siyum tiers offered for [curriculum] in Settings, finest → coarsest.
  ///
  /// Always includes [MilestoneLevel.unit] (per-masechta/sefer/siman/hilchos)
  /// and [MilestoneLevel.curriculum] (the whole-curriculum siyum). The
  /// [MilestoneLevel.aggregate] (seder-style) tier is offered only when the
  /// curriculum's content exposes a *meaningful* aggregate: it must both pass
  /// [_hasAggregateLevel] (the same predicate that gates aggregate emission, so
  /// the UI can never offer a tier the engine won't fire) AND have more than one
  /// level-1 group. The second clause excludes a degenerate single-group
  /// "aggregate" that coincides with the whole curriculum (Mishna Berurah's one
  /// book of 697 simanim), which would otherwise duplicate the curriculum tier.
  ///
  /// The list is a strict superset relationship to emission: a tier absent here
  /// is only ever a tier the granularity gate could suppress, never one it would
  /// fabricate.

  AvailableSiyumTiersProvider call(CurriculumId curriculum) =>
      AvailableSiyumTiersProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'availableSiyumTiersProvider';
}
