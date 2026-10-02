// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journey_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(JourneySortModeNotifier)
final journeySortModeProvider = JourneySortModeNotifierProvider._();

final class JourneySortModeNotifierProvider
    extends $NotifierProvider<JourneySortModeNotifier, JourneySortModeValue> {
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

/// The siyumim journey of the active learner (DNI-474 AC-4).
///
/// Every milestone comes from the engine's completed units
/// (`CurriculumState.completedUnits`, from any source including backfill
/// and correction): one row per completion number k, dated
/// `first_completed_at(k)`. A void that takes a completion away removes
/// its row, and a later re-completion adds a row with its new date. The
/// chosen siyum granularity filters what is shown; the level counters
/// count each unit's first completion.

@ProviderFor(journeyViewModel)
final journeyViewModelProvider = JourneyViewModelProvider._();

/// The siyumim journey of the active learner (DNI-474 AC-4).
///
/// Every milestone comes from the engine's completed units
/// (`CurriculumState.completedUnits`, from any source including backfill
/// and correction): one row per completion number k, dated
/// `first_completed_at(k)`. A void that takes a completion away removes
/// its row, and a later re-completion adds a row with its new date. The
/// chosen siyum granularity filters what is shown; the level counters
/// count each unit's first completion.

final class JourneyViewModelProvider
    extends
        $FunctionalProvider<
          AsyncValue<JourneyViewModel>,
          JourneyViewModel,
          FutureOr<JourneyViewModel>
        >
    with $FutureModifier<JourneyViewModel>, $FutureProvider<JourneyViewModel> {
  /// The siyumim journey of the active learner (DNI-474 AC-4).
  ///
  /// Every milestone comes from the engine's completed units
  /// (`CurriculumState.completedUnits`, from any source including backfill
  /// and correction): one row per completion number k, dated
  /// `first_completed_at(k)`. A void that takes a completion away removes
  /// its row, and a later re-completion adds a row with its new date. The
  /// chosen siyum granularity filters what is shown; the level counters
  /// count each unit's first completion.
  JourneyViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'journeyViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$journeyViewModelHash();

  @$internal
  @override
  $FutureProviderElement<JourneyViewModel> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<JourneyViewModel> create(Ref ref) {
    return journeyViewModel(ref);
  }
}

String _$journeyViewModelHash() => r'e592febf83152ee8e90b23821cd0d69328f694d0';

/// Which siyum tiers [curriculum] offers in the granularity selector — a
/// property of the curriculum's content structure, not of the learner: the
/// unit tier, the aggregate tier when its level-2 values name units
/// grouped under more than one level-1 group (Mishnayos sederim), and the
/// whole curriculum.

@ProviderFor(availableSiyumTiers)
final availableSiyumTiersProvider = AvailableSiyumTiersFamily._();

/// Which siyum tiers [curriculum] offers in the granularity selector — a
/// property of the curriculum's content structure, not of the learner: the
/// unit tier, the aggregate tier when its level-2 values name units
/// grouped under more than one level-1 group (Mishnayos sederim), and the
/// whole curriculum.

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
  /// Which siyum tiers [curriculum] offers in the granularity selector — a
  /// property of the curriculum's content structure, not of the learner: the
  /// unit tier, the aggregate tier when its level-2 values name units
  /// grouped under more than one level-1 group (Mishnayos sederim), and the
  /// whole curriculum.
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
    r'255280235b678e63495be8759c8b5f86bf410d95';

/// Which siyum tiers [curriculum] offers in the granularity selector — a
/// property of the curriculum's content structure, not of the learner: the
/// unit tier, the aggregate tier when its level-2 values name units
/// grouped under more than one level-1 group (Mishnayos sederim), and the
/// whole curriculum.

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

  /// Which siyum tiers [curriculum] offers in the granularity selector — a
  /// property of the curriculum's content structure, not of the learner: the
  /// unit tier, the aggregate tier when its level-2 values name units
  /// grouped under more than one level-1 group (Mishnayos sederim), and the
  /// whole curriculum.

  AvailableSiyumTiersProvider call(CurriculumId curriculum) =>
      AvailableSiyumTiersProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'availableSiyumTiersProvider';
}
