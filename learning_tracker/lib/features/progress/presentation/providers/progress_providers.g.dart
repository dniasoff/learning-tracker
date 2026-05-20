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
    r'94d461758ffc9ecb6e10559f92a5f5ab8a3a8435';

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

/// Live progress snapshot derived directly from completion rows.
///
/// Unlike journey milestones, this updates on every completion and is used
/// for immediate progress feedback in the Progress screen.

@ProviderFor(progressOverviewStats)
final progressOverviewStatsProvider = ProgressOverviewStatsProvider._();

/// Live progress snapshot derived directly from completion rows.
///
/// Unlike journey milestones, this updates on every completion and is used
/// for immediate progress feedback in the Progress screen.

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
  /// Live progress snapshot derived directly from completion rows.
  ///
  /// Unlike journey milestones, this updates on every completion and is used
  /// for immediate progress feedback in the Progress screen.
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
    r'339447383be44b68fab5e4d768b0527940820f15';

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
    r'ac0dccab5a12e6428a32a57674906a8d16de8b0b';

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
///
/// F2 fix: uses [PaceCalculator.compute] from the progress domain so that
/// bulk-marked completions (sentinel date 2000-01-01) are excluded from live
/// velocity via the [trackStartDate] filter. Previously the scheduler's
/// [PaceCalculator.calculate] received ALL personal completions including
/// bulk entries, causing phantom "Ahead by 296 days on day 1" results.

@ProviderFor(curriculumPaceStatus)
final curriculumPaceStatusProvider = CurriculumPaceStatusFamily._();

/// Pace status for a curriculum (null if no goal exists).
///
/// Family provider keyed by curriculumId per P3.
///
/// F2 fix: uses [PaceCalculator.compute] from the progress domain so that
/// bulk-marked completions (sentinel date 2000-01-01) are excluded from live
/// velocity via the [trackStartDate] filter. Previously the scheduler's
/// [PaceCalculator.calculate] received ALL personal completions including
/// bulk entries, causing phantom "Ahead by 296 days on day 1" results.

final class CurriculumPaceStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaceCalculator?>,
          PaceCalculator?,
          FutureOr<PaceCalculator?>
        >
    with $FutureModifier<PaceCalculator?>, $FutureProvider<PaceCalculator?> {
  /// Pace status for a curriculum (null if no goal exists).
  ///
  /// Family provider keyed by curriculumId per P3.
  ///
  /// F2 fix: uses [PaceCalculator.compute] from the progress domain so that
  /// bulk-marked completions (sentinel date 2000-01-01) are excluded from live
  /// velocity via the [trackStartDate] filter. Previously the scheduler's
  /// [PaceCalculator.calculate] received ALL personal completions including
  /// bulk entries, causing phantom "Ahead by 296 days on day 1" results.
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
  $FutureProviderElement<PaceCalculator?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaceCalculator?> create(Ref ref) {
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
    r'b929b2b70ac8a5b586b51b5e5ba391f4a6a39190';

/// Pace status for a curriculum (null if no goal exists).
///
/// Family provider keyed by curriculumId per P3.
///
/// F2 fix: uses [PaceCalculator.compute] from the progress domain so that
/// bulk-marked completions (sentinel date 2000-01-01) are excluded from live
/// velocity via the [trackStartDate] filter. Previously the scheduler's
/// [PaceCalculator.calculate] received ALL personal completions including
/// bulk entries, causing phantom "Ahead by 296 days on day 1" results.

final class CurriculumPaceStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PaceCalculator?>, String> {
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
  ///
  /// F2 fix: uses [PaceCalculator.compute] from the progress domain so that
  /// bulk-marked completions (sentinel date 2000-01-01) are excluded from live
  /// velocity via the [trackStartDate] filter. Previously the scheduler's
  /// [PaceCalculator.calculate] received ALL personal completions including
  /// bulk entries, causing phantom "Ahead by 296 days on day 1" results.

  CurriculumPaceStatusProvider call(String curriculumId) =>
      CurriculumPaceStatusProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumPaceStatusProvider';
}
