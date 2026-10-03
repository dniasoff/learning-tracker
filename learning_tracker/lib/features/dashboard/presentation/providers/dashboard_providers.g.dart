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

/// Provider for the active profile's mode, resolved from the profile
/// repository.
///
/// Defaults to [ProfileMode.adult] if no profile is active or found. This is
/// what gates child-only gamification UI (points, streaks, celebrations).
///
/// WS9.enum: unified — formerly returned [UserMode]; now returns [ProfileMode]
/// directly. [UserMode] enum has been deleted.

@ProviderFor(dashboardUserMode)
final dashboardUserModeProvider = DashboardUserModeProvider._();

/// Provider for the active profile's mode, resolved from the profile
/// repository.
///
/// Defaults to [ProfileMode.adult] if no profile is active or found. This is
/// what gates child-only gamification UI (points, streaks, celebrations).
///
/// WS9.enum: unified — formerly returned [UserMode]; now returns [ProfileMode]
/// directly. [UserMode] enum has been deleted.

final class DashboardUserModeProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileMode>,
          ProfileMode,
          FutureOr<ProfileMode>
        >
    with $FutureModifier<ProfileMode>, $FutureProvider<ProfileMode> {
  /// Provider for the active profile's mode, resolved from the profile
  /// repository.
  ///
  /// Defaults to [ProfileMode.adult] if no profile is active or found. This is
  /// what gates child-only gamification UI (points, streaks, celebrations).
  ///
  /// WS9.enum: unified — formerly returned [UserMode]; now returns [ProfileMode]
  /// directly. [UserMode] enum has been deleted.
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
  $FutureProviderElement<ProfileMode> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileMode> create(Ref ref) {
    return dashboardUserMode(ref);
  }
}

String _$dashboardUserModeHash() => r'eae792786d70934fa955edf11e92b3d7bb918819';

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
    r'541686cccc93e8cc82563ed93b7cd4101cc2ac15';

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
    r'd9186fbbfa5c7e3bfe49620ba850a5517e217d91';

/// Track completion percentage for the Manage Tracks card (DNI-474).
///
/// Goal progress (FR-14): the engine's distinct learnt leaves of the
/// curriculum — every source and date state, repeats once — over the
/// learner's scoped leaf count. AD-25: [curriculumId] IS the track.

@ProviderFor(dashboardTrackCompletionPercentage)
final dashboardTrackCompletionPercentageProvider =
    DashboardTrackCompletionPercentageFamily._();

/// Track completion percentage for the Manage Tracks card (DNI-474).
///
/// Goal progress (FR-14): the engine's distinct learnt leaves of the
/// curriculum — every source and date state, repeats once — over the
/// learner's scoped leaf count. AD-25: [curriculumId] IS the track.

final class DashboardTrackCompletionPercentageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Track completion percentage for the Manage Tracks card (DNI-474).
  ///
  /// Goal progress (FR-14): the engine's distinct learnt leaves of the
  /// curriculum — every source and date state, repeats once — over the
  /// learner's scoped leaf count. AD-25: [curriculumId] IS the track.
  DashboardTrackCompletionPercentageProvider._({
    required DashboardTrackCompletionPercentageFamily super.from,
    required CurriculumId super.argument,
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
    final argument = this.argument as CurriculumId;
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
    r'8514076a5a18762ed13372ab216bba2bef4ec7d5';

/// Track completion percentage for the Manage Tracks card (DNI-474).
///
/// Goal progress (FR-14): the engine's distinct learnt leaves of the
/// curriculum — every source and date state, repeats once — over the
/// learner's scoped leaf count. AD-25: [curriculumId] IS the track.

final class DashboardTrackCompletionPercentageFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double>, CurriculumId> {
  DashboardTrackCompletionPercentageFamily._()
    : super(
        retry: null,
        name: r'dashboardTrackCompletionPercentageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Track completion percentage for the Manage Tracks card (DNI-474).
  ///
  /// Goal progress (FR-14): the engine's distinct learnt leaves of the
  /// curriculum — every source and date state, repeats once — over the
  /// learner's scoped leaf count. AD-25: [curriculumId] IS the track.

  DashboardTrackCompletionPercentageProvider call(CurriculumId curriculumId) =>
      DashboardTrackCompletionPercentageProvider._(
        argument: curriculumId,
        from: this,
      );

  @override
  String toString() => r'dashboardTrackCompletionPercentageProvider';
}

/// Per-curriculum completion percentage, scoped to the active learner.
///
/// AD-25: one track per curriculum, so this is the same engine number as
/// [dashboardTrackCompletionPercentage]; kept as a separate provider
/// because callers ask two conceptually different questions.

@ProviderFor(dashboardCompletionPercentage)
final dashboardCompletionPercentageProvider =
    DashboardCompletionPercentageFamily._();

/// Per-curriculum completion percentage, scoped to the active learner.
///
/// AD-25: one track per curriculum, so this is the same engine number as
/// [dashboardTrackCompletionPercentage]; kept as a separate provider
/// because callers ask two conceptually different questions.

final class DashboardCompletionPercentageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Per-curriculum completion percentage, scoped to the active learner.
  ///
  /// AD-25: one track per curriculum, so this is the same engine number as
  /// [dashboardTrackCompletionPercentage]; kept as a separate provider
  /// because callers ask two conceptually different questions.
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
    r'427e27077934806e01e509208e64c78d2022372e';

/// Per-curriculum completion percentage, scoped to the active learner.
///
/// AD-25: one track per curriculum, so this is the same engine number as
/// [dashboardTrackCompletionPercentage]; kept as a separate provider
/// because callers ask two conceptually different questions.

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

  /// Per-curriculum completion percentage, scoped to the active learner.
  ///
  /// AD-25: one track per curriculum, so this is the same engine number as
  /// [dashboardTrackCompletionPercentage]; kept as a separate provider
  /// because callers ask two conceptually different questions.

  DashboardCompletionPercentageProvider call(CurriculumId curriculum) =>
      DashboardCompletionPercentageProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'dashboardCompletionPercentageProvider';
}

/// The `effectiveAt` of the curriculum's latest counted learn event, from
/// the engine (DNI-474); null when nothing counts.

@ProviderFor(dashboardLastCompletion)
final dashboardLastCompletionProvider = DashboardLastCompletionFamily._();

/// The `effectiveAt` of the curriculum's latest counted learn event, from
/// the engine (DNI-474); null when nothing counts.

final class DashboardLastCompletionProvider
    extends
        $FunctionalProvider<
          AsyncValue<DateTime?>,
          DateTime?,
          FutureOr<DateTime?>
        >
    with $FutureModifier<DateTime?>, $FutureProvider<DateTime?> {
  /// The `effectiveAt` of the curriculum's latest counted learn event, from
  /// the engine (DNI-474); null when nothing counts.
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
    r'34593b48e10b5b9a21e4137acc34509bb747b693';

/// The `effectiveAt` of the curriculum's latest counted learn event, from
/// the engine (DNI-474); null when nothing counts.

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

  /// The `effectiveAt` of the curriculum's latest counted learn event, from
  /// the engine (DNI-474); null when nothing counts.

  DashboardLastCompletionProvider call(CurriculumId curriculum) =>
      DashboardLastCompletionProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'dashboardLastCompletionProvider';
}

/// Streak data provider, scoped to the active profile.
///
/// Reads streak state through [StreakStateService] — the only read path.
/// [StreakStateService] delegates to [FirestoreStreakStateRepository], which
/// derives state from the synced Firestore event log directly (D-E: throws
/// when the backend isn't ready rather than returning a fabricated zero
/// streak).

@ProviderFor(dashboardStreak)
final dashboardStreakProvider = DashboardStreakProvider._();

/// Streak data provider, scoped to the active profile.
///
/// Reads streak state through [StreakStateService] — the only read path.
/// [StreakStateService] delegates to [FirestoreStreakStateRepository], which
/// derives state from the synced Firestore event log directly (D-E: throws
/// when the backend isn't ready rather than returning a fabricated zero
/// streak).

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
  /// Reads streak state through [StreakStateService] — the only read path.
  /// [StreakStateService] delegates to [FirestoreStreakStateRepository], which
  /// derives state from the synced Firestore event log directly (D-E: throws
  /// when the backend isn't ready rather than returning a fabricated zero
  /// streak).
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

String _$dashboardStreakHash() => r'4a1e8fa5e4063ae523d79ab165930d5bf2ab1ea5';

/// Stored debitable points balance, scoped to active child profile (WS7.balance).
///
/// Reads the AD-50 filtered ledger balance ([watchActivePointsTotals],
/// DNI-480) — the spend-economy source of truth (DEC-32); it re-reads when
/// the engine's earning set changes. Returns 0 for adult profiles (Rule 3: adults
/// have no points).
///
/// **Not a live stream, unlike the Drift-era `watchBalance`.** No Firestore
/// equivalent exists or can cheaply exist: `firestore.rules` caps every
/// `points_ledger` list/query at `request.query.limit <= 500` (SR-4), so an
/// unbounded `.snapshots()` listener over the whole ledger is rejected by
/// the security rules outright — there is no single-listener way to watch
/// an arbitrarily-long append-only ledger's derived sum live. This re-reads
/// the balance whenever [completionCommittedProvider] fires (the dominant
/// mutation path today) or an explicit `ref.invalidate` fires (see
/// `dashboard_screen.dart`, `progress_screen.dart`,
/// `after_track_change_invalidation.dart`). A redemption debit/refund or a
/// parent points adjustment that doesn't itself invalidate this provider
/// will leave the counter stale until one of those does — a real,
/// disclosed regression from the Drift-era live stream, tracked rather than
/// silently accepted (see the phase's task list — the redemption write
/// path this would need to hook into does not exist in production code
/// yet either).

@ProviderFor(dashboardGlobalPoints)
final dashboardGlobalPointsProvider = DashboardGlobalPointsProvider._();

/// Stored debitable points balance, scoped to active child profile (WS7.balance).
///
/// Reads the AD-50 filtered ledger balance ([watchActivePointsTotals],
/// DNI-480) — the spend-economy source of truth (DEC-32); it re-reads when
/// the engine's earning set changes. Returns 0 for adult profiles (Rule 3: adults
/// have no points).
///
/// **Not a live stream, unlike the Drift-era `watchBalance`.** No Firestore
/// equivalent exists or can cheaply exist: `firestore.rules` caps every
/// `points_ledger` list/query at `request.query.limit <= 500` (SR-4), so an
/// unbounded `.snapshots()` listener over the whole ledger is rejected by
/// the security rules outright — there is no single-listener way to watch
/// an arbitrarily-long append-only ledger's derived sum live. This re-reads
/// the balance whenever [completionCommittedProvider] fires (the dominant
/// mutation path today) or an explicit `ref.invalidate` fires (see
/// `dashboard_screen.dart`, `progress_screen.dart`,
/// `after_track_change_invalidation.dart`). A redemption debit/refund or a
/// parent points adjustment that doesn't itself invalidate this provider
/// will leave the counter stale until one of those does — a real,
/// disclosed regression from the Drift-era live stream, tracked rather than
/// silently accepted (see the phase's task list — the redemption write
/// path this would need to hook into does not exist in production code
/// yet either).

final class DashboardGlobalPointsProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Stored debitable points balance, scoped to active child profile (WS7.balance).
  ///
  /// Reads the AD-50 filtered ledger balance ([watchActivePointsTotals],
  /// DNI-480) — the spend-economy source of truth (DEC-32); it re-reads when
  /// the engine's earning set changes. Returns 0 for adult profiles (Rule 3: adults
  /// have no points).
  ///
  /// **Not a live stream, unlike the Drift-era `watchBalance`.** No Firestore
  /// equivalent exists or can cheaply exist: `firestore.rules` caps every
  /// `points_ledger` list/query at `request.query.limit <= 500` (SR-4), so an
  /// unbounded `.snapshots()` listener over the whole ledger is rejected by
  /// the security rules outright — there is no single-listener way to watch
  /// an arbitrarily-long append-only ledger's derived sum live. This re-reads
  /// the balance whenever [completionCommittedProvider] fires (the dominant
  /// mutation path today) or an explicit `ref.invalidate` fires (see
  /// `dashboard_screen.dart`, `progress_screen.dart`,
  /// `after_track_change_invalidation.dart`). A redemption debit/refund or a
  /// parent points adjustment that doesn't itself invalidate this provider
  /// will leave the counter stale until one of those does — a real,
  /// disclosed regression from the Drift-era live stream, tracked rather than
  /// silently accepted (see the phase's task list — the redemption write
  /// path this would need to hook into does not exist in production code
  /// yet either).
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
    r'4ec10b9088ae7b75eed200b49db5370de2e72dcb';

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
    r'a3442fdad3e54cf61decf4336a10219df3bfce9d';

/// Next reward milestone for the child dashboard (closest threshold not yet met).
///
/// Delegates selection to [NextRewardSelector].
///
/// DEC-32/GA-3: per-track rewards were removed from the spend economy —
/// every reward is now a single global priced spend-item, so [trackEntries]
/// is always empty. [NextRewardSelector.select] already handles that
/// gracefully (falls straight through to the global ladder); see its own
/// doc comment.

@ProviderFor(dashboardChildNextReward)
final dashboardChildNextRewardProvider = DashboardChildNextRewardProvider._();

/// Next reward milestone for the child dashboard (closest threshold not yet met).
///
/// Delegates selection to [NextRewardSelector].
///
/// DEC-32/GA-3: per-track rewards were removed from the spend economy —
/// every reward is now a single global priced spend-item, so [trackEntries]
/// is always empty. [NextRewardSelector.select] already handles that
/// gracefully (falls straight through to the global ladder); see its own
/// doc comment.

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
  ///
  /// DEC-32/GA-3: per-track rewards were removed from the spend economy —
  /// every reward is now a single global priced spend-item, so [trackEntries]
  /// is always empty. [NextRewardSelector.select] already handles that
  /// gracefully (falls straight through to the global ladder); see its own
  /// doc comment.
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
    r'491c0d5c208a3958d96738f600d7b25c76f7ccb7';

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
    r'c3ae9a8a5eb1fec79e4dba73fb3ee7c92fa4c0a9';
