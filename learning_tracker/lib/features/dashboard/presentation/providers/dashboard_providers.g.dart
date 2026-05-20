// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the CrossCurriculumAggregator instance.

@ProviderFor(crossCurriculumAggregator)
final crossCurriculumAggregatorProvider = CrossCurriculumAggregatorProvider._();

/// Provider for the CrossCurriculumAggregator instance.

final class CrossCurriculumAggregatorProvider
    extends
        $FunctionalProvider<
          CrossCurriculumAggregator,
          CrossCurriculumAggregator,
          CrossCurriculumAggregator
        >
    with $Provider<CrossCurriculumAggregator> {
  /// Provider for the CrossCurriculumAggregator instance.
  CrossCurriculumAggregatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crossCurriculumAggregatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crossCurriculumAggregatorHash();

  @$internal
  @override
  $ProviderElement<CrossCurriculumAggregator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CrossCurriculumAggregator create(Ref ref) {
    return crossCurriculumAggregator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrossCurriculumAggregator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrossCurriculumAggregator>(value),
    );
  }
}

String _$crossCurriculumAggregatorHash() =>
    r'1819b08e0b5c27a2886dc5d9196d1db55ba9384f';

/// Provider for the active profile's user mode, resolved from the
/// [Profiles] table.
///
/// Defaults to [UserMode.adult] if no profile row is found. This is what
/// gates child-only gamification UI (points, streaks, celebrations).

@ProviderFor(dashboardUserMode)
final dashboardUserModeProvider = DashboardUserModeProvider._();

/// Provider for the active profile's user mode, resolved from the
/// [Profiles] table.
///
/// Defaults to [UserMode.adult] if no profile row is found. This is what
/// gates child-only gamification UI (points, streaks, celebrations).

final class DashboardUserModeProvider
    extends
        $FunctionalProvider<AsyncValue<UserMode>, UserMode, FutureOr<UserMode>>
    with $FutureModifier<UserMode>, $FutureProvider<UserMode> {
  /// Provider for the active profile's user mode, resolved from the
  /// [Profiles] table.
  ///
  /// Defaults to [UserMode.adult] if no profile row is found. This is what
  /// gates child-only gamification UI (points, streaks, celebrations).
  DashboardUserModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardUserModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardUserModeHash();

  @$internal
  @override
  $FutureProviderElement<UserMode> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UserMode> create(Ref ref) {
    return dashboardUserMode(ref);
  }
}

String _$dashboardUserModeHash() => r'691eebf2f98e9744deb09ad27484cfb52c71264b';

/// Provider for list of active curricula IDs, scoped to active profile.

@ProviderFor(dashboardActiveCurricula)
final dashboardActiveCurriculaProvider = DashboardActiveCurriculaProvider._();

/// Provider for list of active curricula IDs, scoped to active profile.

final class DashboardActiveCurriculaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CurriculumId>>,
          List<CurriculumId>,
          FutureOr<List<CurriculumId>>
        >
    with
        $FutureModifier<List<CurriculumId>>,
        $FutureProvider<List<CurriculumId>> {
  /// Provider for list of active curricula IDs, scoped to active profile.
  DashboardActiveCurriculaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardActiveCurriculaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardActiveCurriculaHash();

  @$internal
  @override
  $FutureProviderElement<List<CurriculumId>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CurriculumId>> create(Ref ref) {
    return dashboardActiveCurricula(ref);
  }
}

String _$dashboardActiveCurriculaHash() =>
    r'bcbc18bb9a788007e9d8e0f89b9cd92f02707587';

/// Stream provider for watching active curricula changes, scoped to active profile.

@ProviderFor(dashboardActiveCurriculaStream)
final dashboardActiveCurriculaStreamProvider =
    DashboardActiveCurriculaStreamProvider._();

/// Stream provider for watching active curricula changes, scoped to active profile.

final class DashboardActiveCurriculaStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CurriculumId>>,
          List<CurriculumId>,
          Stream<List<CurriculumId>>
        >
    with
        $FutureModifier<List<CurriculumId>>,
        $StreamProvider<List<CurriculumId>> {
  /// Stream provider for watching active curricula changes, scoped to active profile.
  DashboardActiveCurriculaStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardActiveCurriculaStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardActiveCurriculaStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<CurriculumId>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CurriculumId>> create(Ref ref) {
    return dashboardActiveCurriculaStream(ref);
  }
}

String _$dashboardActiveCurriculaStreamHash() =>
    r'9689fa138119b78a0b3bf8ad2013549a05ca3d37';

/// Track completion percentage for the Manage Tracks card.
///
/// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) — matching
/// the "I learnt it" intent of the Manage Tracks display. Lifetime-only imports
/// are excluded because they do not represent in-track learning activity.
///
/// An item is "done" when ALL of the track's required stages have a
/// completion record.  Formula: `(done items) / totalItems`.
///
/// Delegates computation to [TrackProgressService] (Layer 3 unification).
///
/// **Why this differs from [trackDualProgressMetricsProvider].currentCyclePercentage:**
/// This answers "how complete is this track overall?" (all-time, multi-stage gate).
/// The cycle metric answers "how many items has the user touched since the last
/// track activation?" (time-gated, single-ref check).
///
/// See also: [trackDualProgressMetricsProvider] (lifetime_knowledge_providers.dart).

@ProviderFor(dashboardTrackCompletionPercentage)
final dashboardTrackCompletionPercentageProvider =
    DashboardTrackCompletionPercentageFamily._();

/// Track completion percentage for the Manage Tracks card.
///
/// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) — matching
/// the "I learnt it" intent of the Manage Tracks display. Lifetime-only imports
/// are excluded because they do not represent in-track learning activity.
///
/// An item is "done" when ALL of the track's required stages have a
/// completion record.  Formula: `(done items) / totalItems`.
///
/// Delegates computation to [TrackProgressService] (Layer 3 unification).
///
/// **Why this differs from [trackDualProgressMetricsProvider].currentCyclePercentage:**
/// This answers "how complete is this track overall?" (all-time, multi-stage gate).
/// The cycle metric answers "how many items has the user touched since the last
/// track activation?" (time-gated, single-ref check).
///
/// See also: [trackDualProgressMetricsProvider] (lifetime_knowledge_providers.dart).

final class DashboardTrackCompletionPercentageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Track completion percentage for the Manage Tracks card.
  ///
  /// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) — matching
  /// the "I learnt it" intent of the Manage Tracks display. Lifetime-only imports
  /// are excluded because they do not represent in-track learning activity.
  ///
  /// An item is "done" when ALL of the track's required stages have a
  /// completion record.  Formula: `(done items) / totalItems`.
  ///
  /// Delegates computation to [TrackProgressService] (Layer 3 unification).
  ///
  /// **Why this differs from [trackDualProgressMetricsProvider].currentCyclePercentage:**
  /// This answers "how complete is this track overall?" (all-time, multi-stage gate).
  /// The cycle metric answers "how many items has the user touched since the last
  /// track activation?" (time-gated, single-ref check).
  ///
  /// See also: [trackDualProgressMetricsProvider] (lifetime_knowledge_providers.dart).
  DashboardTrackCompletionPercentageProvider._({
    required DashboardTrackCompletionPercentageFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'dashboardTrackCompletionPercentageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$dashboardTrackCompletionPercentageHash();

  @override
  String toString() {
    return r'dashboardTrackCompletionPercentageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    final argument = this.argument as int;
    return dashboardTrackCompletionPercentage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardTrackCompletionPercentageProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dashboardTrackCompletionPercentageHash() =>
    r'6c62c3cd2383c19a9e71eb4ae7f5763211f620c7';

/// Track completion percentage for the Manage Tracks card.
///
/// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) — matching
/// the "I learnt it" intent of the Manage Tracks display. Lifetime-only imports
/// are excluded because they do not represent in-track learning activity.
///
/// An item is "done" when ALL of the track's required stages have a
/// completion record.  Formula: `(done items) / totalItems`.
///
/// Delegates computation to [TrackProgressService] (Layer 3 unification).
///
/// **Why this differs from [trackDualProgressMetricsProvider].currentCyclePercentage:**
/// This answers "how complete is this track overall?" (all-time, multi-stage gate).
/// The cycle metric answers "how many items has the user touched since the last
/// track activation?" (time-gated, single-ref check).
///
/// See also: [trackDualProgressMetricsProvider] (lifetime_knowledge_providers.dart).

final class DashboardTrackCompletionPercentageFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, int> {
  DashboardTrackCompletionPercentageFamily._()
    : super(
        retry: null,
        name: r'dashboardTrackCompletionPercentageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Track completion percentage for the Manage Tracks card.
  ///
  /// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) — matching
  /// the "I learnt it" intent of the Manage Tracks display. Lifetime-only imports
  /// are excluded because they do not represent in-track learning activity.
  ///
  /// An item is "done" when ALL of the track's required stages have a
  /// completion record.  Formula: `(done items) / totalItems`.
  ///
  /// Delegates computation to [TrackProgressService] (Layer 3 unification).
  ///
  /// **Why this differs from [trackDualProgressMetricsProvider].currentCyclePercentage:**
  /// This answers "how complete is this track overall?" (all-time, multi-stage gate).
  /// The cycle metric answers "how many items has the user touched since the last
  /// track activation?" (time-gated, single-ref check).
  ///
  /// See also: [trackDualProgressMetricsProvider] (lifetime_knowledge_providers.dart).

  DashboardTrackCompletionPercentageProvider call(int trackId) =>
      DashboardTrackCompletionPercentageProvider._(
        argument: trackId,
        from: this,
      );

  @override
  String toString() => r'dashboardTrackCompletionPercentageProvider';
}

/// Per-curriculum item-based completion percentage, scoped to active profile.
///
/// An item (sefariaRef) is "done" when every required stage for its track has
/// a completion record.  Required stages = the non-superseded stages defined
/// for that track.  An item that is fully done in any of its tracks counts
/// once toward the numerator.
///
/// Formula: `(distinct sefariaRefs fully done in any track) / totalLeafItems`.
///
/// Delegates computation to [TrackCompletionService].

@ProviderFor(dashboardCompletionPercentage)
final dashboardCompletionPercentageProvider =
    DashboardCompletionPercentageFamily._();

/// Per-curriculum item-based completion percentage, scoped to active profile.
///
/// An item (sefariaRef) is "done" when every required stage for its track has
/// a completion record.  Required stages = the non-superseded stages defined
/// for that track.  An item that is fully done in any of its tracks counts
/// once toward the numerator.
///
/// Formula: `(distinct sefariaRefs fully done in any track) / totalLeafItems`.
///
/// Delegates computation to [TrackCompletionService].

final class DashboardCompletionPercentageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Per-curriculum item-based completion percentage, scoped to active profile.
  ///
  /// An item (sefariaRef) is "done" when every required stage for its track has
  /// a completion record.  Required stages = the non-superseded stages defined
  /// for that track.  An item that is fully done in any of its tracks counts
  /// once toward the numerator.
  ///
  /// Formula: `(distinct sefariaRefs fully done in any track) / totalLeafItems`.
  ///
  /// Delegates computation to [TrackCompletionService].
  DashboardCompletionPercentageProvider._({
    required DashboardCompletionPercentageFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'dashboardCompletionPercentageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dashboardCompletionPercentageHash();

  @override
  String toString() {
    return r'dashboardCompletionPercentageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return dashboardCompletionPercentage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardCompletionPercentageProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dashboardCompletionPercentageHash() =>
    r'7ceee9ec3e5bf87f4b23ed05225cc6e1931cc5af';

/// Per-curriculum item-based completion percentage, scoped to active profile.
///
/// An item (sefariaRef) is "done" when every required stage for its track has
/// a completion record.  Required stages = the non-superseded stages defined
/// for that track.  An item that is fully done in any of its tracks counts
/// once toward the numerator.
///
/// Formula: `(distinct sefariaRefs fully done in any track) / totalLeafItems`.
///
/// Delegates computation to [TrackCompletionService].

final class DashboardCompletionPercentageFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, CurriculumId> {
  DashboardCompletionPercentageFamily._()
    : super(
        retry: null,
        name: r'dashboardCompletionPercentageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-curriculum item-based completion percentage, scoped to active profile.
  ///
  /// An item (sefariaRef) is "done" when every required stage for its track has
  /// a completion record.  Required stages = the non-superseded stages defined
  /// for that track.  An item that is fully done in any of its tracks counts
  /// once toward the numerator.
  ///
  /// Formula: `(distinct sefariaRefs fully done in any track) / totalLeafItems`.
  ///
  /// Delegates computation to [TrackCompletionService].

  DashboardCompletionPercentageProvider call(CurriculumId curriculum) =>
      DashboardCompletionPercentageProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'dashboardCompletionPercentageProvider';
}

/// Per-curriculum last completion timestamp, scoped to active profile.

@ProviderFor(dashboardLastCompletion)
final dashboardLastCompletionProvider = DashboardLastCompletionFamily._();

/// Per-curriculum last completion timestamp, scoped to active profile.

final class DashboardLastCompletionProvider
    extends
        $FunctionalProvider<
          AsyncValue<DateTime?>,
          DateTime?,
          FutureOr<DateTime?>
        >
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// Per-curriculum last completion timestamp, scoped to active profile.
  DashboardLastCompletionProvider._({
    required DashboardLastCompletionFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'dashboardLastCompletionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dashboardLastCompletionHash();

  @override
  String toString() {
    return r'dashboardLastCompletionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DateTime?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DateTime?> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return dashboardLastCompletion(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardLastCompletionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dashboardLastCompletionHash() =>
    r'd82f958f1ed1485d553b61f7aa929c5832255004';

/// Per-curriculum last completion timestamp, scoped to active profile.

final class DashboardLastCompletionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DateTime?>, CurriculumId> {
  DashboardLastCompletionFamily._()
    : super(
        retry: null,
        name: r'dashboardLastCompletionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-curriculum last completion timestamp, scoped to active profile.

  DashboardLastCompletionProvider call(CurriculumId curriculum) =>
      DashboardLastCompletionProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'dashboardLastCompletionProvider';
}

/// Streak data provider, scoped to the active profile.
///
/// Reads streak state through `core/streak/StreakStateProvider` — the
/// only read path post-DNI-337. The provider replays the append-only
/// `streak_events` log through `StreakReducer` (UTC day boundaries),
/// restoring from `completions` on a new-device empty-log first launch.
///
/// Performance note: `completionCommittedProvider` is intentionally NOT
/// watched here. [CompletionRepositoryImpl._createCompletion] writes a
/// `streak_events` row on each completion, which Drift surfaces via the
/// reactive `watch()` query below — no manual trigger needed.
/// Watching `completionCommittedProvider` would tear down and rebuild the
/// entire stream subscription on every completion, causing unnecessary
/// work on every task mark.

@ProviderFor(dashboardStreak)
final dashboardStreakProvider = DashboardStreakProvider._();

/// Streak data provider, scoped to the active profile.
///
/// Reads streak state through `core/streak/StreakStateProvider` — the
/// only read path post-DNI-337. The provider replays the append-only
/// `streak_events` log through `StreakReducer` (UTC day boundaries),
/// restoring from `completions` on a new-device empty-log first launch.
///
/// Performance note: `completionCommittedProvider` is intentionally NOT
/// watched here. [CompletionRepositoryImpl._createCompletion] writes a
/// `streak_events` row on each completion, which Drift surfaces via the
/// reactive `watch()` query below — no manual trigger needed.
/// Watching `completionCommittedProvider` would tear down and rebuild the
/// entire stream subscription on every completion, causing unnecessary
/// work on every task mark.

final class DashboardStreakProvider
    extends
        $FunctionalProvider<
          AsyncValue<({int currentStreak, int maxStreak})>,
          ({int currentStreak, int maxStreak}),
          Stream<({int currentStreak, int maxStreak})>
        >
    with
        $FutureModifier<({int currentStreak, int maxStreak})>,
        $StreamProvider<({int currentStreak, int maxStreak})> {
  /// Streak data provider, scoped to the active profile.
  ///
  /// Reads streak state through `core/streak/StreakStateProvider` — the
  /// only read path post-DNI-337. The provider replays the append-only
  /// `streak_events` log through `StreakReducer` (UTC day boundaries),
  /// restoring from `completions` on a new-device empty-log first launch.
  ///
  /// Performance note: `completionCommittedProvider` is intentionally NOT
  /// watched here. [CompletionRepositoryImpl._createCompletion] writes a
  /// `streak_events` row on each completion, which Drift surfaces via the
  /// reactive `watch()` query below — no manual trigger needed.
  /// Watching `completionCommittedProvider` would tear down and rebuild the
  /// entire stream subscription on every completion, causing unnecessary
  /// work on every task mark.
  DashboardStreakProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardStreakProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardStreakHash();

  @$internal
  @override
  $StreamProviderElement<({int currentStreak, int maxStreak})> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<({int currentStreak, int maxStreak})> create(Ref ref) {
    return dashboardStreak(ref);
  }
}

String _$dashboardStreakHash() => r'0370557f7b040536a349a20b951070cb1fefa7f1';

/// Global points total, scoped to active profile.
///
/// Only completions on reward-eligible tracks (programmed or self-paced with a
/// goal); excludes onboarding bulk prior marks and browse-only tracks.

@ProviderFor(dashboardGlobalPoints)
final dashboardGlobalPointsProvider = DashboardGlobalPointsProvider._();

/// Global points total, scoped to active profile.
///
/// Only completions on reward-eligible tracks (programmed or self-paced with a
/// goal); excludes onboarding bulk prior marks and browse-only tracks.

final class DashboardGlobalPointsProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Global points total, scoped to active profile.
  ///
  /// Only completions on reward-eligible tracks (programmed or self-paced with a
  /// goal); excludes onboarding bulk prior marks and browse-only tracks.
  DashboardGlobalPointsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardGlobalPointsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardGlobalPointsHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return dashboardGlobalPoints(ref);
  }
}

String _$dashboardGlobalPointsHash() =>
    r'936c0e8d7b3adac83f55c2b6debf265fef08768f';

/// Write-path effect: strips legacy stock-template milestones for the current
/// profile and pushes updated gamification settings to Firestore if any rows
/// were removed.
///
/// This is intentionally separate from the read providers below so that a
/// mutation (delete + cloud push) never runs inside a provider that is
/// re-evaluated on every widget rebuild.  Callers that depend on the post-strip
/// state should watch this provider to ensure it completes before reading
/// milestone data.

@ProviderFor(stripStockMilestonesEffect)
final stripStockMilestonesEffectProvider =
    StripStockMilestonesEffectProvider._();

/// Write-path effect: strips legacy stock-template milestones for the current
/// profile and pushes updated gamification settings to Firestore if any rows
/// were removed.
///
/// This is intentionally separate from the read providers below so that a
/// mutation (delete + cloud push) never runs inside a provider that is
/// re-evaluated on every widget rebuild.  Callers that depend on the post-strip
/// state should watch this provider to ensure it completes before reading
/// milestone data.

final class StripStockMilestonesEffectProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Write-path effect: strips legacy stock-template milestones for the current
  /// profile and pushes updated gamification settings to Firestore if any rows
  /// were removed.
  ///
  /// This is intentionally separate from the read providers below so that a
  /// mutation (delete + cloud push) never runs inside a provider that is
  /// re-evaluated on every widget rebuild.  Callers that depend on the post-strip
  /// state should watch this provider to ensure it completes before reading
  /// milestone data.
  StripStockMilestonesEffectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stripStockMilestonesEffectProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stripStockMilestonesEffectHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return stripStockMilestonesEffect(ref);
  }
}

String _$stripStockMilestonesEffectHash() =>
    r'8b10005765c14ffcc1d40ea9289cca867fba2360';

/// Next reward milestone for the child dashboard (closest threshold not yet met).
///
/// Delegates selection to [NextRewardSelector].

@ProviderFor(dashboardChildNextReward)
final dashboardChildNextRewardProvider = DashboardChildNextRewardProvider._();

/// Next reward milestone for the child dashboard (closest threshold not yet met).
///
/// Delegates selection to [NextRewardSelector].

final class DashboardChildNextRewardProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardChildNextReward?>,
          DashboardChildNextReward?,
          FutureOr<DashboardChildNextReward?>
        >
    with
        $FutureModifier<DashboardChildNextReward?>,
        $FutureProvider<DashboardChildNextReward?> {
  /// Next reward milestone for the child dashboard (closest threshold not yet met).
  ///
  /// Delegates selection to [NextRewardSelector].
  DashboardChildNextRewardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardChildNextRewardProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardChildNextRewardHash();

  @$internal
  @override
  $FutureProviderElement<DashboardChildNextReward?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DashboardChildNextReward?> create(Ref ref) {
    return dashboardChildNextReward(ref);
  }
}

String _$dashboardChildNextRewardHash() =>
    r'5b2fbc543f8d2cb045bd04b9610d823128d9ef88';

/// Streak recovery info — whether the streak was just saved by grace period.

@ProviderFor(dashboardStreakRecovery)
final dashboardStreakRecoveryProvider = DashboardStreakRecoveryProvider._();

/// Streak recovery info — whether the streak was just saved by grace period.

final class DashboardStreakRecoveryProvider
    extends
        $FunctionalProvider<
          AsyncValue<StreakRecoveryInfo>,
          StreakRecoveryInfo,
          FutureOr<StreakRecoveryInfo>
        >
    with
        $FutureModifier<StreakRecoveryInfo>,
        $FutureProvider<StreakRecoveryInfo> {
  /// Streak recovery info — whether the streak was just saved by grace period.
  DashboardStreakRecoveryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardStreakRecoveryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardStreakRecoveryHash();

  @$internal
  @override
  $FutureProviderElement<StreakRecoveryInfo> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StreakRecoveryInfo> create(Ref ref) {
    return dashboardStreakRecovery(ref);
  }
}

String _$dashboardStreakRecoveryHash() =>
    r'11004b11503d33a6f71f1940d1023eb23413c885';

/// Per-curriculum pace status for the dashboard.
///
/// Fetches goal data and computes pace internally so the dashboard
/// doesn't need to know goal details.
///
/// Delegates computation to [ComputePaceStatusUseCase].

@ProviderFor(dashboardPaceStatus)
final dashboardPaceStatusProvider = DashboardPaceStatusFamily._();

/// Per-curriculum pace status for the dashboard.
///
/// Fetches goal data and computes pace internally so the dashboard
/// doesn't need to know goal details.
///
/// Delegates computation to [ComputePaceStatusUseCase].

final class DashboardPaceStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaceStatus?>,
          PaceStatus?,
          FutureOr<PaceStatus?>
        >
    with $FutureModifier<PaceStatus?>, $FutureProvider<PaceStatus?> {
  /// Per-curriculum pace status for the dashboard.
  ///
  /// Fetches goal data and computes pace internally so the dashboard
  /// doesn't need to know goal details.
  ///
  /// Delegates computation to [ComputePaceStatusUseCase].
  DashboardPaceStatusProvider._({
    required DashboardPaceStatusFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'dashboardPaceStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dashboardPaceStatusHash();

  @override
  String toString() {
    return r'dashboardPaceStatusProvider'
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
    final argument = this.argument as CurriculumId;
    return dashboardPaceStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DashboardPaceStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dashboardPaceStatusHash() =>
    r'58c2212bf9f975d24b8ba5b0993f3359357bc357';

/// Per-curriculum pace status for the dashboard.
///
/// Fetches goal data and computes pace internally so the dashboard
/// doesn't need to know goal details.
///
/// Delegates computation to [ComputePaceStatusUseCase].

final class DashboardPaceStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PaceStatus?>, CurriculumId> {
  DashboardPaceStatusFamily._()
    : super(
        retry: null,
        name: r'dashboardPaceStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-curriculum pace status for the dashboard.
  ///
  /// Fetches goal data and computes pace internally so the dashboard
  /// doesn't need to know goal details.
  ///
  /// Delegates computation to [ComputePaceStatusUseCase].

  DashboardPaceStatusProvider call(CurriculumId curriculum) =>
      DashboardPaceStatusProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'dashboardPaceStatusProvider';
}
