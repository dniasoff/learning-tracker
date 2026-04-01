// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the progress repository instance.

@ProviderFor(progressRepository)
final progressRepositoryProvider = ProgressRepositoryProvider._();

/// Provider for the progress repository instance.

final class ProgressRepositoryProvider
    extends
        $FunctionalProvider<
          ProgressRepository,
          ProgressRepository,
          ProgressRepository
        >
    with $Provider<ProgressRepository> {
  /// Provider for the progress repository instance.
  ProgressRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProgressRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProgressRepository create(Ref ref) {
    return progressRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressRepository>(value),
    );
  }
}

String _$progressRepositoryHash() =>
    r'c6f1ae20db9d3912441660fa17cf687e205758b7';

/// Provider for track breakdown by curriculum, scoped to the active profile.
///
/// Returns a map of TrackType to completion counts for the given curriculum.

@ProviderFor(trackBreakdown)
final trackBreakdownProvider = TrackBreakdownFamily._();

/// Provider for track breakdown by curriculum, scoped to the active profile.
///
/// Returns a map of TrackType to completion counts for the given curriculum.

final class TrackBreakdownProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<TrackType, int>>,
          Map<TrackType, int>,
          FutureOr<Map<TrackType, int>>
        >
    with
        $FutureModifier<Map<TrackType, int>>,
        $FutureProvider<Map<TrackType, int>> {
  /// Provider for track breakdown by curriculum, scoped to the active profile.
  ///
  /// Returns a map of TrackType to completion counts for the given curriculum.
  TrackBreakdownProvider._({
    required TrackBreakdownFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'trackBreakdownProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trackBreakdownHash();

  @override
  String toString() {
    return r'trackBreakdownProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<TrackType, int>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<TrackType, int>> create(Ref ref) {
    final argument = this.argument as String;
    return trackBreakdown(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TrackBreakdownProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trackBreakdownHash() => r'ca265ceca574217987cb113e78ce06027302283b';

/// Provider for track breakdown by curriculum, scoped to the active profile.
///
/// Returns a map of TrackType to completion counts for the given curriculum.

final class TrackBreakdownFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<TrackType, int>>, String> {
  TrackBreakdownFamily._()
    : super(
        retry: null,
        name: r'trackBreakdownProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for track breakdown by curriculum, scoped to the active profile.
  ///
  /// Returns a map of TrackType to completion counts for the given curriculum.

  TrackBreakdownProvider call(String curriculumId) =>
      TrackBreakdownProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'trackBreakdownProvider';
}

/// Provider for aggregate completion count by curriculum, scoped to the active profile.
///
/// Returns the total completion count across all tracks for the given curriculum.

@ProviderFor(aggregateCount)
final aggregateCountProvider = AggregateCountFamily._();

/// Provider for aggregate completion count by curriculum, scoped to the active profile.
///
/// Returns the total completion count across all tracks for the given curriculum.

final class AggregateCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Provider for aggregate completion count by curriculum, scoped to the active profile.
  ///
  /// Returns the total completion count across all tracks for the given curriculum.
  AggregateCountProvider._({
    required AggregateCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'aggregateCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$aggregateCountHash();

  @override
  String toString() {
    return r'aggregateCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as String;
    return aggregateCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AggregateCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$aggregateCountHash() => r'0be708b27af3275b27018c37928a269a124f9337';

/// Provider for aggregate completion count by curriculum, scoped to the active profile.
///
/// Returns the total completion count across all tracks for the given curriculum.

final class AggregateCountFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, String> {
  AggregateCountFamily._()
    : super(
        retry: null,
        name: r'aggregateCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for aggregate completion count by curriculum, scoped to the active profile.
  ///
  /// Returns the total completion count across all tracks for the given curriculum.

  AggregateCountProvider call(String curriculumId) =>
      AggregateCountProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'aggregateCountProvider';
}

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// Aggregates content hierarchy, completions, and stage definitions into
/// a [CurriculumProgressData] with hierarchy breakdowns, stage breakdowns,
/// track breakdowns, and overall stats.

@ProviderFor(curriculumProgress)
final curriculumProgressProvider = CurriculumProgressFamily._();

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// Aggregates content hierarchy, completions, and stage definitions into
/// a [CurriculumProgressData] with hierarchy breakdowns, stage breakdowns,
/// track breakdowns, and overall stats.

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
  /// Aggregates content hierarchy, completions, and stage definitions into
  /// a [CurriculumProgressData] with hierarchy breakdowns, stage breakdowns,
  /// track breakdowns, and overall stats.
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
    r'c47a5bbe1c5e336fbd9fa9a0cb2bc784f26986d9';

/// Per-curriculum progress data provider (family keyed by curriculumId per P3).
///
/// Aggregates content hierarchy, completions, and stage definitions into
/// a [CurriculumProgressData] with hierarchy breakdowns, stage breakdowns,
/// track breakdowns, and overall stats.

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
  /// Aggregates content hierarchy, completions, and stage definitions into
  /// a [CurriculumProgressData] with hierarchy breakdowns, stage breakdowns,
  /// track breakdowns, and overall stats.

  CurriculumProgressProvider call(String curriculumId) =>
      CurriculumProgressProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumProgressProvider';
}

/// Pace status for a curriculum (null if no goal exists).
///
/// Family provider keyed by curriculumId per P3.

@ProviderFor(curriculumPaceStatus)
final curriculumPaceStatusProvider = CurriculumPaceStatusFamily._();

/// Pace status for a curriculum (null if no goal exists).
///
/// Family provider keyed by curriculumId per P3.

final class CurriculumPaceStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaceStatus?>,
          PaceStatus?,
          FutureOr<PaceStatus?>
        >
    with $FutureModifier<PaceStatus?>, $FutureProvider<PaceStatus?> {
  /// Pace status for a curriculum (null if no goal exists).
  ///
  /// Family provider keyed by curriculumId per P3.
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
  $FutureProviderElement<PaceStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaceStatus?> create(Ref ref) {
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
    r'0bb55fe962271104641add8ee3dce467b2668144';

/// Pace status for a curriculum (null if no goal exists).
///
/// Family provider keyed by curriculumId per P3.

final class CurriculumPaceStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PaceStatus?>, String> {
  CurriculumPaceStatusFamily._()
    : super(
        retry: null,
        name: r'curriculumPaceStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Pace status for a curriculum (null if no goal exists).
  ///
  /// Family provider keyed by curriculumId per P3.

  CurriculumPaceStatusProvider call(String curriculumId) =>
      CurriculumPaceStatusProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumPaceStatusProvider';
}
