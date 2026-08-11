import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

/// Generates the daily task list across all active curricula.
///
/// Wraps [SchedulerEngine] to aggregate tasks from multiple curricula,
/// apply skip filtering, and sort by priority.
class DailyTaskGenerator {
  const DailyTaskGenerator({required SchedulerEngine engine})
    : _engine = engine;

  final SchedulerEngine _engine;

  /// Generate daily tasks for a single curriculum/track.
  Future<List<DailyTask>> generate(
    CurriculumId curriculumId,
    DateTime date, {
    required String trackLabel,
    DateTime? goalDeadline,
    double? pacePerDay,
    bool isStudyDay = true,
    int studyDaysPerWeek = 7,
    int? studyDaysInDeadlineWindow,
    Set<String> skippedRefs = const {},
    DateTime? trackStartedAt,
    Set<String> priorlyShownRefs = const {},
    String? paceGranularity,
  }) async {
    final config = ScheduleConfig(
      curriculumId: curriculumId,
      trackLabel: trackLabel,
      currentDate: date,
      goalDeadline: goalDeadline,
      pacePerDay: pacePerDay,
      isStudyDay: isStudyDay,
      studyDaysPerWeek: studyDaysPerWeek,
      studyDaysInDeadlineWindow: studyDaysInDeadlineWindow,
      trackStartedAt: trackStartedAt,
      priorlyShownRefs: priorlyShownRefs,
      paceGranularity: paceGranularity,
    );
    final tasks = await _engine.generateDailyTasks(config);

    // Filter out skipped items
    if (skippedRefs.isEmpty) return tasks;
    return tasks
        .where((t) => !skippedRefs.contains(t.contentItemSefariaRef))
        .toList();
  }

  /// Generate daily tasks across multiple curricula/tracks.
  ///
  /// [goalDeadlines] maps curriculum IDs to their earliest goal deadline,
  /// enabling deadline-aware pacing.
  /// [trackLabels] maps curriculum IDs to their track context.
  /// [trackStartedAtMap] enables the snapshot-aware self-paced new-learning
  /// path when combined with [pacePerDayMap]; both must be set for a
  /// curriculum for the new logic to kick in.
  /// [priorlyShownRefsMap] is the set of refs that have appeared in any
  /// prior-day snapshot for that curriculum's track (resolved by the
  /// repository before this call).
  Future<List<DailyTask>> generateAll(
    List<CurriculumId> curricula,
    DateTime date, {
    Set<String> skippedRefs = const {},
    Map<CurriculumId, DateTime> goalDeadlines = const {},
    Map<CurriculumId, double> pacePerDayMap = const {},
    Map<CurriculumId, bool> isStudyDayMap = const {},
    Map<CurriculumId, int> studyDaysPerWeekMap = const {},
    Map<CurriculumId, int> studyDaysInDeadlineWindowMap = const {},
    Map<CurriculumId, String> trackLabels = const {},
    Map<CurriculumId, DateTime> trackStartedAtMap = const {},
    Map<CurriculumId, Set<String>> priorlyShownRefsMap = const {},
    Map<CurriculumId, String> paceGranularityMap = const {},
  }) async {
    final allTasks = <DailyTask>[];

    for (final curriculum in curricula) {
      final tasks = await generate(
        curriculum,
        date,
        trackLabel: trackLabels[curriculum] ?? '',
        goalDeadline: goalDeadlines[curriculum],
        pacePerDay: pacePerDayMap[curriculum],
        isStudyDay: isStudyDayMap[curriculum] ?? true,
        studyDaysPerWeek: studyDaysPerWeekMap[curriculum] ?? 7,
        studyDaysInDeadlineWindow: studyDaysInDeadlineWindowMap[curriculum],
        skippedRefs: skippedRefs,
        trackStartedAt: trackStartedAtMap[curriculum],
        priorlyShownRefs: priorlyShownRefsMap[curriculum] ?? const <String>{},
        paceGranularity: paceGranularityMap[curriculum],
      );
      allTasks.addAll(tasks);
    }

    // Sort by priority across all curricula
    allTasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return allTasks;
  }
}
