// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduler_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the scheduler screen shows tasks grouped by curriculum.
/// Kept as a provider so [SchedulerScreen] can be a pure [ConsumerWidget]
/// with no local state (W5.21).

@ProviderFor(SchedulerGroupedView)
final schedulerGroupedViewProvider = SchedulerGroupedViewProvider._();

/// Whether the scheduler screen shows tasks grouped by curriculum.
/// Kept as a provider so [SchedulerScreen] can be a pure [ConsumerWidget]
/// with no local state (W5.21).
final class SchedulerGroupedViewProvider
    extends $NotifierProvider<SchedulerGroupedView, bool> {
  /// Whether the scheduler screen shows tasks grouped by curriculum.
  /// Kept as a provider so [SchedulerScreen] can be a pure [ConsumerWidget]
  /// with no local state (W5.21).
  SchedulerGroupedViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schedulerGroupedViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schedulerGroupedViewHash();

  @$internal
  @override
  SchedulerGroupedView create() => SchedulerGroupedView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$schedulerGroupedViewHash() =>
    r'210adcd82bc297cada0aa26f2475cc517193a6d5';

/// Whether the scheduler screen shows tasks grouped by curriculum.
/// Kept as a provider so [SchedulerScreen] can be a pure [ConsumerWidget]
/// with no local state (W5.21).

abstract class _$SchedulerGroupedView extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

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

/// Curricula on the active profile whose goal is COARSE-paced (daf/perek/seif).
/// Drives daf-grouping of the daily list and daf labels on task cards.

@ProviderFor(coarsePacedTrackIds)
final coarsePacedTrackIdsProvider = CoarsePacedTrackIdsProvider._();

/// Curricula on the active profile whose goal is COARSE-paced (daf/perek/seif).
/// Drives daf-grouping of the daily list and daf labels on task cards.

final class CoarsePacedTrackIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<CurriculumId>>,
          Set<CurriculumId>,
          FutureOr<Set<CurriculumId>>
        >
    with
        $FutureModifier<Set<CurriculumId>>,
        $FutureProvider<Set<CurriculumId>> {
  /// Curricula on the active profile whose goal is COARSE-paced (daf/perek/seif).
  /// Drives daf-grouping of the daily list and daf labels on task cards.
  CoarsePacedTrackIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coarsePacedTrackIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coarsePacedTrackIdsHash();

  @$internal
  @override
  $FutureProviderElement<Set<CurriculumId>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Set<CurriculumId>> create(Ref ref) {
    return coarsePacedTrackIds(ref);
  }
}

String _$coarsePacedTrackIdsHash() =>
    r'715791953077265e809f32b7d8128008613816bd';

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

String _$schedulerEngineHash() => r'beb25b1ead2bf6af9bfb2b127caee049bb9ed9f0';

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
              String trackLabel,
              DateTime? goalDeadline,
            });
    return dailyTasks(
      ref,
      curriculumId: argument.curriculumId,
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

String _$dailyTasksHash() => r'81462e468cc5c49491febfdc4e658b4547eda94e';

final class DailyTasksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<DailyTask>>,
          ({
            CurriculumId curriculumId,
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
    required String trackLabel,
    DateTime? goalDeadline,
  }) => DailyTasksProvider._(
    argument: (
      curriculumId: curriculumId,
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

String _$skippedTasksHash() => r'0360d01b5a098bf96baea418d37fa06896b6a006';

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
    r'92ea79f7e36c0ab80617f82c349e9a2c4649246f';

/// The planner's task list for civil [date] (`YYYY-MM-DD`), evaluated live
/// over the active learner's current `LearnerState` (AD-49, DNI-477): new
/// learning and calendar days, then reviews, as [buildPlannedTasks] lays
/// them out. Never persisted; it recomputes whenever the learner state
/// changes. The erev planned list of an upcoming locked day is this
/// provider for that date.

@ProviderFor(plannedTasksForDate)
final plannedTasksForDateProvider = PlannedTasksForDateFamily._();

/// The planner's task list for civil [date] (`YYYY-MM-DD`), evaluated live
/// over the active learner's current `LearnerState` (AD-49, DNI-477): new
/// learning and calendar days, then reviews, as [buildPlannedTasks] lays
/// them out. Never persisted; it recomputes whenever the learner state
/// changes. The erev planned list of an upcoming locked day is this
/// provider for that date.

final class PlannedTasksForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyTask>>,
          List<DailyTask>,
          FutureOr<List<DailyTask>>
        >
    with $FutureModifier<List<DailyTask>>, $FutureProvider<List<DailyTask>> {
  /// The planner's task list for civil [date] (`YYYY-MM-DD`), evaluated live
  /// over the active learner's current `LearnerState` (AD-49, DNI-477): new
  /// learning and calendar days, then reviews, as [buildPlannedTasks] lays
  /// them out. Never persisted; it recomputes whenever the learner state
  /// changes. The erev planned list of an upcoming locked day is this
  /// provider for that date.
  PlannedTasksForDateProvider._({
    required PlannedTasksForDateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'plannedTasksForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$plannedTasksForDateHash();

  @override
  String toString() {
    return r'plannedTasksForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<DailyTask>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<DailyTask>> create(Ref ref) {
    final argument = this.argument as String;
    return plannedTasksForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlannedTasksForDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$plannedTasksForDateHash() =>
    r'76d916a3f3357159b40262a1ba9818f0a8b88d75';

/// The planner's task list for civil [date] (`YYYY-MM-DD`), evaluated live
/// over the active learner's current `LearnerState` (AD-49, DNI-477): new
/// learning and calendar days, then reviews, as [buildPlannedTasks] lays
/// them out. Never persisted; it recomputes whenever the learner state
/// changes. The erev planned list of an upcoming locked day is this
/// provider for that date.

final class PlannedTasksForDateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<DailyTask>>, String> {
  PlannedTasksForDateFamily._()
    : super(
        retry: null,
        name: r'plannedTasksForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The planner's task list for civil [date] (`YYYY-MM-DD`), evaluated live
  /// over the active learner's current `LearnerState` (AD-49, DNI-477): new
  /// learning and calendar days, then reviews, as [buildPlannedTasks] lays
  /// them out. Never persisted; it recomputes whenever the learner state
  /// changes. The erev planned list of an upcoming locked day is this
  /// provider for that date.

  PlannedTasksForDateProvider call(String date) =>
      PlannedTasksForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'plannedTasksForDateProvider';
}

/// All daily tasks across active curricula: today's [plannedTasksForDate]
/// (the device's local date), with read-time skip handling — skipped-today
/// refs removed, refs skipped yesterday boosted — sorted by priority.
///
/// The planner's list already excludes what is learnt or reviewed (AD-49:
/// the engine's `schedulableRefs`, `programBacklog` and `reviewsDue` say
/// so), so there is no completion filter here.

@ProviderFor(allDailyTasks)
final allDailyTasksProvider = AllDailyTasksProvider._();

/// All daily tasks across active curricula: today's [plannedTasksForDate]
/// (the device's local date), with read-time skip handling — skipped-today
/// refs removed, refs skipped yesterday boosted — sorted by priority.
///
/// The planner's list already excludes what is learnt or reviewed (AD-49:
/// the engine's `schedulableRefs`, `programBacklog` and `reviewsDue` say
/// so), so there is no completion filter here.

final class AllDailyTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DailyTask>>,
          List<DailyTask>,
          FutureOr<List<DailyTask>>
        >
    with $FutureModifier<List<DailyTask>>, $FutureProvider<List<DailyTask>> {
  /// All daily tasks across active curricula: today's [plannedTasksForDate]
  /// (the device's local date), with read-time skip handling — skipped-today
  /// refs removed, refs skipped yesterday boosted — sorted by priority.
  ///
  /// The planner's list already excludes what is learnt or reviewed (AD-49:
  /// the engine's `schedulableRefs`, `programBacklog` and `reviewsDue` say
  /// so), so there is no completion filter here.
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

String _$allDailyTasksHash() => r'd04155164655423f386d33470f815a5743f88643';

/// Overdue task count for a single curriculum.
///
/// Reads from [allDailyTasksProvider] and filters by [curriculumId] +
/// [isOverdue].  Used by the reorder-confirm dialog to show the user how many
/// overdue items would be amnestied (architecture §10.1 / reorder-amnesty).

@ProviderFor(overdueCountForCurriculum)
final overdueCountForCurriculumProvider = OverdueCountForCurriculumFamily._();

/// Overdue task count for a single curriculum.
///
/// Reads from [allDailyTasksProvider] and filters by [curriculumId] +
/// [isOverdue].  Used by the reorder-confirm dialog to show the user how many
/// overdue items would be amnestied (architecture §10.1 / reorder-amnesty).

final class OverdueCountForCurriculumProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Overdue task count for a single curriculum.
  ///
  /// Reads from [allDailyTasksProvider] and filters by [curriculumId] +
  /// [isOverdue].  Used by the reorder-confirm dialog to show the user how many
  /// overdue items would be amnestied (architecture §10.1 / reorder-amnesty).
  OverdueCountForCurriculumProvider._({
    required OverdueCountForCurriculumFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'overdueCountForCurriculumProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$overdueCountForCurriculumHash();

  @override
  String toString() {
    return r'overdueCountForCurriculumProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return overdueCountForCurriculum(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OverdueCountForCurriculumProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$overdueCountForCurriculumHash() =>
    r'c9bfd20930388ba5cb2fa0b6f1c724238763afb3';

/// Overdue task count for a single curriculum.
///
/// Reads from [allDailyTasksProvider] and filters by [curriculumId] +
/// [isOverdue].  Used by the reorder-confirm dialog to show the user how many
/// overdue items would be amnestied (architecture §10.1 / reorder-amnesty).

final class OverdueCountForCurriculumFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<int>, CurriculumId> {
  OverdueCountForCurriculumFamily._()
    : super(
        retry: null,
        name: r'overdueCountForCurriculumProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Overdue task count for a single curriculum.
  ///
  /// Reads from [allDailyTasksProvider] and filters by [curriculumId] +
  /// [isOverdue].  Used by the reorder-confirm dialog to show the user how many
  /// overdue items would be amnestied (architecture §10.1 / reorder-amnesty).

  OverdueCountForCurriculumProvider call(CurriculumId curriculumId) =>
      OverdueCountForCurriculumProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'overdueCountForCurriculumProvider';
}

/// Returns the first [DailyTask] for [trackId] that falls in [category],
/// or null when the bucket is empty.
///
/// Sourced from [allDailyTasksProvider] so it shares the frozen daily snapshot
/// and benefits from the same skip-filtering logic.

@ProviderFor(firstTaskInTrackForCategory)
final firstTaskInTrackForCategoryProvider =
    FirstTaskInTrackForCategoryFamily._();

/// Returns the first [DailyTask] for [trackId] that falls in [category],
/// or null when the bucket is empty.
///
/// Sourced from [allDailyTasksProvider] so it shares the frozen daily snapshot
/// and benefits from the same skip-filtering logic.

final class FirstTaskInTrackForCategoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<DailyTask?>,
          DailyTask?,
          FutureOr<DailyTask?>
        >
    with $FutureModifier<DailyTask?>, $FutureProvider<DailyTask?> {
  /// Returns the first [DailyTask] for [trackId] that falls in [category],
  /// or null when the bucket is empty.
  ///
  /// Sourced from [allDailyTasksProvider] so it shares the frozen daily snapshot
  /// and benefits from the same skip-filtering logic.
  FirstTaskInTrackForCategoryProvider._({
    required FirstTaskInTrackForCategoryFamily super.from,
    required ({CurriculumId curriculumId, TrackTaskCategory category})
    super.argument,
  }) : super(
         retry: null,
         name: r'firstTaskInTrackForCategoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$firstTaskInTrackForCategoryHash();

  @override
  String toString() {
    return r'firstTaskInTrackForCategoryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<DailyTask?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<DailyTask?> create(Ref ref) {
    final argument =
        this.argument
            as ({CurriculumId curriculumId, TrackTaskCategory category});
    return firstTaskInTrackForCategory(
      ref,
      curriculumId: argument.curriculumId,
      category: argument.category,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FirstTaskInTrackForCategoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$firstTaskInTrackForCategoryHash() =>
    r'fc5d4de7faeade7d644caa1439e1a02519a4a261';

/// Returns the first [DailyTask] for [trackId] that falls in [category],
/// or null when the bucket is empty.
///
/// Sourced from [allDailyTasksProvider] so it shares the frozen daily snapshot
/// and benefits from the same skip-filtering logic.

final class FirstTaskInTrackForCategoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<DailyTask?>,
          ({CurriculumId curriculumId, TrackTaskCategory category})
        > {
  FirstTaskInTrackForCategoryFamily._()
    : super(
        retry: null,
        name: r'firstTaskInTrackForCategoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Returns the first [DailyTask] for [trackId] that falls in [category],
  /// or null when the bucket is empty.
  ///
  /// Sourced from [allDailyTasksProvider] so it shares the frozen daily snapshot
  /// and benefits from the same skip-filtering logic.

  FirstTaskInTrackForCategoryProvider call({
    required CurriculumId curriculumId,
    required TrackTaskCategory category,
  }) => FirstTaskInTrackForCategoryProvider._(
    argument: (curriculumId: curriculumId, category: category),
    from: this,
  );

  @override
  String toString() => r'firstTaskInTrackForCategoryProvider';
}
