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

/// The curriculum the home/dashboard has in view (AD-40 surfaces): the
/// active-tracks carousel reports its visible page here. Null until the
/// learner pages the carousel; [dashboardStreakCurriculum] then falls back
/// to the first active track. Reset on every profile switch.

@ProviderFor(DashboardCurriculumInView)
final dashboardCurriculumInViewProvider = DashboardCurriculumInViewProvider._();

/// The curriculum the home/dashboard has in view (AD-40 surfaces): the
/// active-tracks carousel reports its visible page here. Null until the
/// learner pages the carousel; [dashboardStreakCurriculum] then falls back
/// to the first active track. Reset on every profile switch.
final class DashboardCurriculumInViewProvider
    extends $NotifierProvider<DashboardCurriculumInView, CurriculumId?> {
  /// The curriculum the home/dashboard has in view (AD-40 surfaces): the
  /// active-tracks carousel reports its visible page here. Null until the
  /// learner pages the carousel; [dashboardStreakCurriculum] then falls back
  /// to the first active track. Reset on every profile switch.
  DashboardCurriculumInViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardCurriculumInViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardCurriculumInViewHash();

  @$internal
  @override
  DashboardCurriculumInView create() => DashboardCurriculumInView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CurriculumId? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CurriculumId?>(value),
    );
  }
}

String _$dashboardCurriculumInViewHash() =>
    r'51f4c8fd50a52a9e3be1a8ebd98bf093f26de7ec';

/// The curriculum the home/dashboard has in view (AD-40 surfaces): the
/// active-tracks carousel reports its visible page here. Null until the
/// learner pages the carousel; [dashboardStreakCurriculum] then falls back
/// to the first active track. Reset on every profile switch.

abstract class _$DashboardCurriculumInView extends $Notifier<CurriculumId?> {
  CurriculumId? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CurriculumId?, CurriculumId?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CurriculumId?, CurriculumId?>,
              CurriculumId?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The curriculum whose streak the home/dashboard shows (DNI-479, AD-40):
/// [DashboardCurriculumInView] resolved against the active tracks.

@ProviderFor(dashboardStreakCurriculum)
final dashboardStreakCurriculumProvider = DashboardStreakCurriculumProvider._();

/// The curriculum whose streak the home/dashboard shows (DNI-479, AD-40):
/// [DashboardCurriculumInView] resolved against the active tracks.

final class DashboardStreakCurriculumProvider
    extends
        $FunctionalProvider<
          AsyncValue<CurriculumId?>,
          CurriculumId?,
          FutureOr<CurriculumId?>
        >
    with $FutureModifier<CurriculumId?>, $FutureProvider<CurriculumId?> {
  /// The curriculum whose streak the home/dashboard shows (DNI-479, AD-40):
  /// [DashboardCurriculumInView] resolved against the active tracks.
  DashboardStreakCurriculumProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardStreakCurriculumProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardStreakCurriculumHash();

  @$internal
  @override
  $FutureProviderElement<CurriculumId?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CurriculumId?> create(Ref ref) {
    return dashboardStreakCurriculum(ref);
  }
}

String _$dashboardStreakCurriculumHash() =>
    r'c1354b8aeab9ffa092c237057b707f2eb9af27bc';

/// The streak of the curriculum in view (DNI-479, AD-40): that
/// curriculum's `LearnerState` streak. `LearnerState` has no profile-wide
/// streak; switching curricula switches the streak.
///
/// Zero with no active learner, no active track, or a curriculum the
/// engine does not evaluate. A learner-state error is an error (never a
/// fabricated zero streak, owner ruling D-E); it stays loading while the
/// state loads.

@ProviderFor(dashboardStreak)
final dashboardStreakProvider = DashboardStreakProvider._();

/// The streak of the curriculum in view (DNI-479, AD-40): that
/// curriculum's `LearnerState` streak. `LearnerState` has no profile-wide
/// streak; switching curricula switches the streak.
///
/// Zero with no active learner, no active track, or a curriculum the
/// engine does not evaluate. A learner-state error is an error (never a
/// fabricated zero streak, owner ruling D-E); it stays loading while the
/// state loads.

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
  /// The streak of the curriculum in view (DNI-479, AD-40): that
  /// curriculum's `LearnerState` streak. `LearnerState` has no profile-wide
  /// streak; switching curricula switches the streak.
  ///
  /// Zero with no active learner, no active track, or a curriculum the
  /// engine does not evaluate. A learner-state error is an error (never a
  /// fabricated zero streak, owner ruling D-E); it stays loading while the
  /// state loads.
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

String _$dashboardStreakHash() => r'92742efaf18e857241a576b0290ca7a7a5166c4a';

/// The days of the last 30 with counted learning in the curriculum in view
/// (DNI-479), for the gamification streak calendar.

@ProviderFor(dashboardStreakCalendar)
final dashboardStreakCalendarProvider = DashboardStreakCalendarProvider._();

/// The days of the last 30 with counted learning in the curriculum in view
/// (DNI-479), for the gamification streak calendar.

final class DashboardStreakCalendarProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<DateTime>>,
          Set<DateTime>,
          FutureOr<Set<DateTime>>
        >
    with $FutureModifier<Set<DateTime>>, $FutureProvider<Set<DateTime>> {
  /// The days of the last 30 with counted learning in the curriculum in view
  /// (DNI-479), for the gamification streak calendar.
  DashboardStreakCalendarProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardStreakCalendarProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardStreakCalendarHash();

  @$internal
  @override
  $FutureProviderElement<Set<DateTime>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<DateTime>> create(Ref ref) {
    return dashboardStreakCalendar(ref);
  }
}

String _$dashboardStreakCalendarHash() =>
    r'71a2b5f3c28ca8278869f3e875b3872f7cbf94e7';

/// Stored debitable points balance, scoped to active child profile (WS7.balance).
///
/// Reads from [FirestorePointsBalanceReaderAdapter] — the spend-economy
/// source of truth (DEC-32). Returns 0 for adult profiles (Rule 3: adults
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
/// Reads from [FirestorePointsBalanceReaderAdapter] — the spend-economy
/// source of truth (DEC-32). Returns 0 for adult profiles (Rule 3: adults
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
  /// Reads from [FirestorePointsBalanceReaderAdapter] — the spend-economy
  /// source of truth (DEC-32). Returns 0 for adult profiles (Rule 3: adults
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
    r'5cbf4b311b616ffa2c79341e561c43794824d032';

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
    r'e975de7cbf536ab6f39d7777574e64da506d82a8';

/// Streak recovery info for the curriculum in view. The grace-period
/// feature was dropped (W3.20), so `wasRecovered` is always false; the
/// current streak is [dashboardStreak]'s.

@ProviderFor(dashboardStreakRecovery)
final dashboardStreakRecoveryProvider = DashboardStreakRecoveryProvider._();

/// Streak recovery info for the curriculum in view. The grace-period
/// feature was dropped (W3.20), so `wasRecovered` is always false; the
/// current streak is [dashboardStreak]'s.

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
  /// Streak recovery info for the curriculum in view. The grace-period
  /// feature was dropped (W3.20), so `wasRecovered` is always false; the
  /// current streak is [dashboardStreak]'s.
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
    r'a68c9420f0004e19f4f7a42e90bba2ed696c7b16';
