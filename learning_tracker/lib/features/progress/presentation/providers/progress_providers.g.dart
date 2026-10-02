// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live progress snapshot from the active learner's [LearnerState]
/// (DNI-474): tracked learning only (the old live-completions filter is
/// now the `dated` / `catch_up` date states), distinct per curriculum and
/// leaf. Before-tracking backfill is not "live" activity.

@ProviderFor(progressOverviewStats)
final progressOverviewStatsProvider = ProgressOverviewStatsProvider._();

/// Live progress snapshot from the active learner's [LearnerState]
/// (DNI-474): tracked learning only (the old live-completions filter is
/// now the `dated` / `catch_up` date states), distinct per curriculum and
/// leaf. Before-tracking backfill is not "live" activity.

final class ProgressOverviewStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProgressOverviewStats>,
          ProgressOverviewStats,
          FutureOr<ProgressOverviewStats>
        >
    with
        $FutureModifier<ProgressOverviewStats>,
        $FutureProvider<ProgressOverviewStats> {
  /// Live progress snapshot from the active learner's [LearnerState]
  /// (DNI-474): tracked learning only (the old live-completions filter is
  /// now the `dated` / `catch_up` date states), distinct per curriculum and
  /// leaf. Before-tracking backfill is not "live" activity.
  ProgressOverviewStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressOverviewStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressOverviewStatsHash();

  @$internal
  @override
  $FutureProviderElement<ProgressOverviewStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProgressOverviewStats> create(Ref ref) {
    return progressOverviewStats(ref);
  }
}

String _$progressOverviewStatsHash() =>
    r'e3b8a65dbb0ea30f095e53bfe540f3333c78758e';

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// The learner's scoped leaves and stage definitions, marked with the
/// engine's learnt set and counted learning (DNI-474): goal progress is the
/// distinct learnt count (FR-14), so repeats never inflate it.

@ProviderFor(curriculumProgress)
final curriculumProgressProvider = CurriculumProgressFamily._();

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// The learner's scoped leaves and stage definitions, marked with the
/// engine's learnt set and counted learning (DNI-474): goal progress is the
/// distinct learnt count (FR-14), so repeats never inflate it.

final class CurriculumProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<CurriculumProgressData>,
          CurriculumProgressData,
          FutureOr<CurriculumProgressData>
        >
    with
        $FutureModifier<CurriculumProgressData>,
        $FutureProvider<CurriculumProgressData> {
  /// Per-curriculum progress data provider (family keyed by curriculumId per P3).
  ///
  /// The learner's scoped leaves and stage definitions, marked with the
  /// engine's learnt set and counted learning (DNI-474): goal progress is the
  /// distinct learnt count (FR-14), so repeats never inflate it.
  CurriculumProgressProvider._({
    required CurriculumProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'curriculumProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curriculumProgressHash();

  @override
  String toString() {
    return r'curriculumProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CurriculumProgressData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CurriculumProgressData> create(Ref ref) {
    final argument = this.argument as String;
    return curriculumProgress(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CurriculumProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curriculumProgressHash() =>
    r'f1d62081b0d5633e8acd20ad18b7297981ead952';

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// The learner's scoped leaves and stage definitions, marked with the
/// engine's learnt set and counted learning (DNI-474): goal progress is the
/// distinct learnt count (FR-14), so repeats never inflate it.

final class CurriculumProgressFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CurriculumProgressData>, String> {
  CurriculumProgressFamily._()
    : super(
        retry: null,
        name: r'curriculumProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-curriculum progress data provider (family keyed by curriculumId per P3).
  ///
  /// The learner's scoped leaves and stage definitions, marked with the
  /// engine's learnt set and counted learning (DNI-474): goal progress is the
  /// distinct learnt count (FR-14), so repeats never inflate it.

  CurriculumProgressProvider call(String curriculumId) =>
      CurriculumProgressProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumProgressProvider';
}

/// The engine's finish projection of a curriculum (AD-35): null without an
/// active learner, when the curriculum is not evaluated, or with no
/// deadline goal ([ProjectionStatus.noDeadline]).

@ProviderFor(curriculumPaceStatus)
final curriculumPaceStatusProvider = CurriculumPaceStatusFamily._();

/// The engine's finish projection of a curriculum (AD-35): null without an
/// active learner, when the curriculum is not evaluated, or with no
/// deadline goal ([ProjectionStatus.noDeadline]).

final class CurriculumPaceStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<Projection?>,
          Projection?,
          FutureOr<Projection?>
        >
    with $FutureModifier<Projection?>, $FutureProvider<Projection?> {
  /// The engine's finish projection of a curriculum (AD-35): null without an
  /// active learner, when the curriculum is not evaluated, or with no
  /// deadline goal ([ProjectionStatus.noDeadline]).
  CurriculumPaceStatusProvider._({
    required CurriculumPaceStatusFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'curriculumPaceStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curriculumPaceStatusHash();

  @override
  String toString() {
    return r'curriculumPaceStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Projection?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Projection?> create(Ref ref) {
    final argument = this.argument as String;
    return curriculumPaceStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CurriculumPaceStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curriculumPaceStatusHash() =>
    r'90fd6322a7cf87ef1ccf0e768fbfab464962e213';

/// The engine's finish projection of a curriculum (AD-35): null without an
/// active learner, when the curriculum is not evaluated, or with no
/// deadline goal ([ProjectionStatus.noDeadline]).

final class CurriculumPaceStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Projection?>, String> {
  CurriculumPaceStatusFamily._()
    : super(
        retry: null,
        name: r'curriculumPaceStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The engine's finish projection of a curriculum (AD-35): null without an
  /// active learner, when the curriculum is not evaluated, or with no
  /// deadline goal ([ProjectionStatus.noDeadline]).

  CurriculumPaceStatusProvider call(String curriculumId) =>
      CurriculumPaceStatusProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumPaceStatusProvider';
}
