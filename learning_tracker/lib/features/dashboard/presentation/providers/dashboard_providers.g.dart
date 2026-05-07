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

String _$dashboardUserModeHash() => r'fff9df75b1a75bdff8789d1bcd89456dcefac42e';

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

/// Stage-based completion for one track (same denominator as
/// [dashboardCompletionPercentage] for the curriculum, completions from this track only).

@ProviderFor(dashboardTrackCompletionPercentage)
final dashboardTrackCompletionPercentageProvider =
    DashboardTrackCompletionPercentageFamily._();

/// Stage-based completion for one track (same denominator as
/// [dashboardCompletionPercentage] for the curriculum, completions from this track only).

final class DashboardTrackCompletionPercentageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Stage-based completion for one track (same denominator as
  /// [dashboardCompletionPercentage] for the curriculum, completions from this track only).
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
    r'5a4725fcc043ebe6690ee63615c78dc6fbd99fbc';

/// Stage-based completion for one track (same denominator as
/// [dashboardCompletionPercentage] for the curriculum, completions from this track only).

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

  /// Stage-based completion for one track (same denominator as
  /// [dashboardCompletionPercentage] for the curriculum, completions from this track only).

  DashboardTrackCompletionPercentageProvider call(int trackId) =>
      DashboardTrackCompletionPercentageProvider._(
        argument: trackId,
        from: this,
      );

  @override
  String toString() => r'dashboardTrackCompletionPercentageProvider';
}

/// Per-curriculum completion percentage, scoped to active profile.
///
/// Formula: `completions.length / (totalLeafItems * totalStages)`.
/// Every stage completion nudges the bar, and the denominator is the
/// scoped total leaf items (not items touched) so the bar never regresses
/// when a new item is started.

@ProviderFor(dashboardCompletionPercentage)
final dashboardCompletionPercentageProvider =
    DashboardCompletionPercentageFamily._();

/// Per-curriculum completion percentage, scoped to active profile.
///
/// Formula: `completions.length / (totalLeafItems * totalStages)`.
/// Every stage completion nudges the bar, and the denominator is the
/// scoped total leaf items (not items touched) so the bar never regresses
/// when a new item is started.

final class DashboardCompletionPercentageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Per-curriculum completion percentage, scoped to active profile.
  ///
  /// Formula: `completions.length / (totalLeafItems * totalStages)`.
  /// Every stage completion nudges the bar, and the denominator is the
  /// scoped total leaf items (not items touched) so the bar never regresses
  /// when a new item is started.
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
    r'6efa6cddbea645766b524e1d84d9cbfb5e710297';

/// Per-curriculum completion percentage, scoped to active profile.
///
/// Formula: `completions.length / (totalLeafItems * totalStages)`.
/// Every stage completion nudges the bar, and the denominator is the
/// scoped total leaf items (not items touched) so the bar never regresses
/// when a new item is started.

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

  /// Per-curriculum completion percentage, scoped to active profile.
  ///
  /// Formula: `completions.length / (totalLeafItems * totalStages)`.
  /// Every stage completion nudges the bar, and the denominator is the
  /// scoped total leaf items (not items touched) so the bar never regresses
  /// when a new item is started.

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
    r'7c1b1bd065a319bc338ed8ac893e903faf55acaa';

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

@ProviderFor(dashboardStreak)
final dashboardStreakProvider = DashboardStreakProvider._();

/// Streak data provider, scoped to the active profile.

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

String _$dashboardStreakHash() => r'57d98ffb0171ffdee4b35d132f16c664e828f662';

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
    r'c43526771961c0076acd51f60182f620a839860a';

/// Next reward milestone for the child dashboard (closest threshold not yet met).

@ProviderFor(dashboardChildNextReward)
final dashboardChildNextRewardProvider = DashboardChildNextRewardProvider._();

/// Next reward milestone for the child dashboard (closest threshold not yet met).

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
    r'9a9255d440416abf6ba46de2bf3f3a2ffd7109fa';

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

@ProviderFor(dashboardPaceStatus)
final dashboardPaceStatusProvider = DashboardPaceStatusFamily._();

/// Per-curriculum pace status for the dashboard.
///
/// Fetches goal data and computes pace internally so the dashboard
/// doesn't need to know goal details.

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
    r'807eb9cacf3233fae7f8bae20a19ec6ed8a6ed7b';

/// Per-curriculum pace status for the dashboard.
///
/// Fetches goal data and computes pace internally so the dashboard
/// doesn't need to know goal details.

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

  DashboardPaceStatusProvider call(CurriculumId curriculum) =>
      DashboardPaceStatusProvider._(argument: curriculum, from: this);

  @override
  String toString() => r'dashboardPaceStatusProvider';
}
