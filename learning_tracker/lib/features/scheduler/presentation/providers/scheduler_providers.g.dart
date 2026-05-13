// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduler_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the current UTC date/time. Override in tests to control time.

@ProviderFor(clock)
final clockProvider = ClockProvider._();

/// Provides the current UTC date/time. Override in tests to control time.

final class ClockProvider
    extends $FunctionalProvider<DateTime, DateTime, DateTime>
    with $Provider<DateTime> {
  /// Provides the current UTC date/time. Override in tests to control time.
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$clockHash() => r'9468c7ed98173bba0de2531c1898d9587398c3de';

@ProviderFor(schedulerEngine)
final schedulerEngineProvider = SchedulerEngineProvider._();

final class SchedulerEngineProvider
    extends
        $FunctionalProvider<SchedulerEngine, SchedulerEngine, SchedulerEngine>
    with $Provider<SchedulerEngine> {
  SchedulerEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schedulerEngineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schedulerEngineHash();

  @$internal
  @override
  $ProviderElement<SchedulerEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SchedulerEngine create(Ref ref) {
    return schedulerEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SchedulerEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SchedulerEngine>(value),
    );
  }
}

String _$schedulerEngineHash() => r'a1b0056ff45f3b1e70536f29aa1e529c4bcbb5da';

@ProviderFor(dailyTaskGenerator)
final dailyTaskGeneratorProvider = DailyTaskGeneratorProvider._();

final class DailyTaskGeneratorProvider
    extends
        $FunctionalProvider<
          DailyTaskGenerator,
          DailyTaskGenerator,
          DailyTaskGenerator
        >
    with $Provider<DailyTaskGenerator> {
  DailyTaskGeneratorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyTaskGeneratorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyTaskGeneratorHash();

  @$internal
  @override
  $ProviderElement<DailyTaskGenerator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DailyTaskGenerator create(Ref ref) {
    return dailyTaskGenerator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DailyTaskGenerator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DailyTaskGenerator>(value),
    );
  }
}

String _$dailyTaskGeneratorHash() =>
    r'2aa2d867a3b1192685f0e3859c1e99ef457f4774';

@ProviderFor(dailyTasks)
final dailyTasksProvider = DailyTasksFamily._();

final class DailyTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyTask>>,
          List<DailyTask>,
          FutureOr<List<DailyTask>>
        >
    with $FutureModifier<List<DailyTask>>, $FutureProvider<List<DailyTask>> {
  DailyTasksProvider._({
    required DailyTasksFamily super.from,
    required ({
      CurriculumId curriculumId,
      int trackId,
      String trackLabel,
      DateTime? goalDeadline,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'dailyTasksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dailyTasksHash();

  @override
  String toString() {
    return r'dailyTasksProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<DailyTask>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DailyTask>> create(Ref ref) {
    final argument =
        this.argument
            as ({
              CurriculumId curriculumId,
              int trackId,
              String trackLabel,
              DateTime? goalDeadline,
            });
    return dailyTasks(
      ref,
      curriculumId: argument.curriculumId,
      trackId: argument.trackId,
      trackLabel: argument.trackLabel,
      goalDeadline: argument.goalDeadline,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DailyTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dailyTasksHash() => r'93eb55acff506fb02a96868e8a9d49ed957c0971';

final class DailyTasksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<DailyTask>>,
          ({
            CurriculumId curriculumId,
            int trackId,
            String trackLabel,
            DateTime? goalDeadline,
          })
        > {
  DailyTasksFamily._()
    : super(
        retry: null,
        name: r'dailyTasksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DailyTasksProvider call({
    required CurriculumId curriculumId,
    required int trackId,
    required String trackLabel,
    DateTime? goalDeadline,
  }) => DailyTasksProvider._(
    argument: (
      curriculumId: curriculumId,
      trackId: trackId,
      trackLabel: trackLabel,
      goalDeadline: goalDeadline,
    ),
    from: this,
  );

  @override
  String toString() => r'dailyTasksProvider';
}

/// Holds the set of sefaria refs skipped (dismissed) today.
///
/// Persisted via SharedPreferences. Resets automatically when the date
/// changes. Previously-skipped refs are tracked so they can receive a
/// priority boost (see [previouslySkippedRefsProvider]).

@ProviderFor(SkippedTasks)
final skippedTasksProvider = SkippedTasksProvider._();

/// Holds the set of sefaria refs skipped (dismissed) today.
///
/// Persisted via SharedPreferences. Resets automatically when the date
/// changes. Previously-skipped refs are tracked so they can receive a
/// priority boost (see [previouslySkippedRefsProvider]).
final class SkippedTasksProvider
    extends $NotifierProvider<SkippedTasks, Set<String>> {
  /// Holds the set of sefaria refs skipped (dismissed) today.
  ///
  /// Persisted via SharedPreferences. Resets automatically when the date
  /// changes. Previously-skipped refs are tracked so they can receive a
  /// priority boost (see [previouslySkippedRefsProvider]).
  SkippedTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skippedTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skippedTasksHash();

  @$internal
  @override
  SkippedTasks create() => SkippedTasks();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$skippedTasksHash() => r'60881d1f3735d1d9774489183f5acebf28e1a6c3';

/// Holds the set of sefaria refs skipped (dismissed) today.
///
/// Persisted via SharedPreferences. Resets automatically when the date
/// changes. Previously-skipped refs are tracked so they can receive a
/// priority boost (see [previouslySkippedRefsProvider]).

abstract class _$SkippedTasks extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Refs that were skipped yesterday. Used for priority boost logic.

@ProviderFor(previouslySkippedRefs)
final previouslySkippedRefsProvider = PreviouslySkippedRefsProvider._();

/// Refs that were skipped yesterday. Used for priority boost logic.

final class PreviouslySkippedRefsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          FutureOr<Set<String>>
        >
    with $FutureModifier<Set<String>>, $FutureProvider<Set<String>> {
  /// Refs that were skipped yesterday. Used for priority boost logic.
  PreviouslySkippedRefsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previouslySkippedRefsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previouslySkippedRefsHash();

  @$internal
  @override
  $FutureProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<String>> create(Ref ref) {
    return previouslySkippedRefs(ref);
  }
}

String _$previouslySkippedRefsHash() =>
    r'6d3c8d4e63cb0ba61df49d9b829a305bfe2c6a82';

/// Pace status for a curriculum goal.
///
/// Calculates pace using personal-track completions only and a rolling
/// 7-day average for projected completion.
/// Supports both deadline-based and pace-based goals.

@ProviderFor(paceStatus)
final paceStatusProvider = PaceStatusFamily._();

/// Pace status for a curriculum goal.
///
/// Calculates pace using personal-track completions only and a rolling
/// 7-day average for projected completion.
/// Supports both deadline-based and pace-based goals.

final class PaceStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<PaceStatus?>,
          PaceStatus?,
          FutureOr<PaceStatus?>
        >
    with $FutureModifier<PaceStatus?>, $FutureProvider<PaceStatus?> {
  /// Pace status for a curriculum goal.
  ///
  /// Calculates pace using personal-track completions only and a rolling
  /// 7-day average for projected completion.
  /// Supports both deadline-based and pace-based goals.
  PaceStatusProvider._({
    required PaceStatusFamily super.from,
    required ({
      CurriculumId curriculumId,
      DateTime goalStartDate,
      DateTime? goalDeadline,
      int totalItems,
      String goalType,
      double? pacePerDay,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'paceStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$paceStatusHash();

  @override
  String toString() {
    return r'paceStatusProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<PaceStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PaceStatus?> create(Ref ref) {
    final argument =
        this.argument
            as ({
              CurriculumId curriculumId,
              DateTime goalStartDate,
              DateTime? goalDeadline,
              int totalItems,
              String goalType,
              double? pacePerDay,
            });
    return paceStatus(
      ref,
      curriculumId: argument.curriculumId,
      goalStartDate: argument.goalStartDate,
      goalDeadline: argument.goalDeadline,
      totalItems: argument.totalItems,
      goalType: argument.goalType,
      pacePerDay: argument.pacePerDay,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PaceStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$paceStatusHash() => r'b917f97e6ddeeafdb97cc84d0759ba7ccefd7ede';

/// Pace status for a curriculum goal.
///
/// Calculates pace using personal-track completions only and a rolling
/// 7-day average for projected completion.
/// Supports both deadline-based and pace-based goals.

final class PaceStatusFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<PaceStatus?>,
          ({
            CurriculumId curriculumId,
            DateTime goalStartDate,
            DateTime? goalDeadline,
            int totalItems,
            String goalType,
            double? pacePerDay,
          })
        > {
  PaceStatusFamily._()
    : super(
        retry: null,
        name: r'paceStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Pace status for a curriculum goal.
  ///
  /// Calculates pace using personal-track completions only and a rolling
  /// 7-day average for projected completion.
  /// Supports both deadline-based and pace-based goals.

  PaceStatusProvider call({
    required CurriculumId curriculumId,
    required DateTime goalStartDate,
    DateTime? goalDeadline,
    required int totalItems,
    String goalType = 'deadline',
    double? pacePerDay,
  }) => PaceStatusProvider._(
    argument: (
      curriculumId: curriculumId,
      goalStartDate: goalStartDate,
      goalDeadline: goalDeadline,
      totalItems: totalItems,
      goalType: goalType,
      pacePerDay: pacePerDay,
    ),
    from: this,
  );

  @override
  String toString() => r'paceStatusProvider';
}

/// Repository that snapshots today's plan to DB so completions don't
/// trigger regeneration.

@ProviderFor(dailyPlanRepository)
final dailyPlanRepositoryProvider = DailyPlanRepositoryProvider._();

/// Repository that snapshots today's plan to DB so completions don't
/// trigger regeneration.

final class DailyPlanRepositoryProvider
    extends
        $FunctionalProvider<
          DailyPlanRepository,
          DailyPlanRepository,
          DailyPlanRepository
        >
    with $Provider<DailyPlanRepository> {
  /// Repository that snapshots today's plan to DB so completions don't
  /// trigger regeneration.
  DailyPlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyPlanRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyPlanRepositoryHash();

  @$internal
  @override
  $ProviderElement<DailyPlanRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DailyPlanRepository create(Ref ref) {
    return dailyPlanRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DailyPlanRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DailyPlanRepository>(value),
    );
  }
}

String _$dailyPlanRepositoryHash() =>
    r'ea6412ceadb21065b6e8a962b1b0ea3276be1bed';

/// All daily tasks across active curricula.
///
/// The raw plan is snapshotted to the `daily_plans` table on the first
/// read of each local day and served back verbatim on subsequent reads.
/// Completions do **not** regenerate the plan — today's list is a
/// contract. Skipped-task filtering and previously-skipped priority
/// boosting are applied at read time.

@ProviderFor(allDailyTasks)
final allDailyTasksProvider = AllDailyTasksProvider._();

/// All daily tasks across active curricula.
///
/// The raw plan is snapshotted to the `daily_plans` table on the first
/// read of each local day and served back verbatim on subsequent reads.
/// Completions do **not** regenerate the plan — today's list is a
/// contract. Skipped-task filtering and previously-skipped priority
/// boosting are applied at read time.

final class AllDailyTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyTask>>,
          List<DailyTask>,
          FutureOr<List<DailyTask>>
        >
    with $FutureModifier<List<DailyTask>>, $FutureProvider<List<DailyTask>> {
  /// All daily tasks across active curricula.
  ///
  /// The raw plan is snapshotted to the `daily_plans` table on the first
  /// read of each local day and served back verbatim on subsequent reads.
  /// Completions do **not** regenerate the plan — today's list is a
  /// contract. Skipped-task filtering and previously-skipped priority
  /// boosting are applied at read time.
  AllDailyTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allDailyTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allDailyTasksHash();

  @$internal
  @override
  $FutureProviderElement<List<DailyTask>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DailyTask>> create(Ref ref) {
    return allDailyTasks(ref);
  }
}

String _$allDailyTasksHash() => r'10d567a7750c468340170af16d2d38be549ebdb7';
