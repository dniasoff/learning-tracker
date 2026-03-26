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

/// Provider for the user mode, resolved from the database.
///
/// Defaults to [UserMode.adult] if no profile exists.
/// P6 compliant: uses only core database, no feature imports.

@ProviderFor(dashboardUserMode)
final dashboardUserModeProvider = DashboardUserModeProvider._();

/// Provider for the user mode, resolved from the database.
///
/// Defaults to [UserMode.adult] if no profile exists.
/// P6 compliant: uses only core database, no feature imports.

final class DashboardUserModeProvider
    extends
        $FunctionalProvider<AsyncValue<UserMode>, UserMode, FutureOr<UserMode>>
    with $FutureModifier<UserMode>, $FutureProvider<UserMode> {
  /// Provider for the user mode, resolved from the database.
  ///
  /// Defaults to [UserMode.adult] if no profile exists.
  /// P6 compliant: uses only core database, no feature imports.
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

String _$dashboardUserModeHash() => r'e3557fadb9ed67a00a1417ee7ee4146e550f6f95';

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
    r'5a748c490812c856063dadca8cf4fec13dc2ae78';

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
    r'd22707c8346b40236bab79b1341fd90de0d3fc8d';

/// Per-curriculum completion percentage, scoped to active profile.

@ProviderFor(dashboardCompletionPercentage)
final dashboardCompletionPercentageProvider =
    DashboardCompletionPercentageFamily._();

/// Per-curriculum completion percentage, scoped to active profile.

final class DashboardCompletionPercentageProvider
    extends $FunctionalProvider<AsyncValue<double>, double, FutureOr<double>>
    with $FutureModifier<double>, $FutureProvider<double> {
  /// Per-curriculum completion percentage, scoped to active profile.
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
    r'984f34a412f64faf16316d2a802dabc1d7db5c1e';

/// Per-curriculum completion percentage, scoped to active profile.

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
    r'2dbfcf2c43503cebbfa09a9ac244f77058be0713';

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

/// Streak data provider (P6 compliant — uses core DB DAO).

@ProviderFor(dashboardStreak)
final dashboardStreakProvider = DashboardStreakProvider._();

/// Streak data provider (P6 compliant — uses core DB DAO).

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
  /// Streak data provider (P6 compliant — uses core DB DAO).
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

String _$dashboardStreakHash() => r'9f262b606eec43dafc352be089daa6649a763588';

/// Global points total, scoped to active profile.

@ProviderFor(dashboardGlobalPoints)
final dashboardGlobalPointsProvider = DashboardGlobalPointsProvider._();

/// Global points total, scoped to active profile.

final class DashboardGlobalPointsProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Global points total, scoped to active profile.
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
    r'7b414255ea50c70ee6ed1f4a80cada3871859e54';

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
    r'9f7b13fa1ee1a90f8d860eac8b3c06087a13e8df';

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
    r'aa03e0f915505782275bee73f6db45c39d072536';

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
