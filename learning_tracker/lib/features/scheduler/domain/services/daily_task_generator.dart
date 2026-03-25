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

  /// Generate daily tasks for a single curriculum.
  Future<List<DailyTask>> generate(
    CurriculumId curriculumId,
    DateTime date, {
    DateTime? goalDeadline,
    double? pacePerDay,
    bool isStudyDay = true,
    int studyDaysPerWeek = 7,
    Set<String> skippedRefs = const {},
  }) async {
    final config = ScheduleConfig(
      curriculumId: curriculumId,
      currentDate: date,
      goalDeadline: goalDeadline,
      pacePerDay: pacePerDay,
      isStudyDay: isStudyDay,
      studyDaysPerWeek: studyDaysPerWeek,
    );
    final tasks = await _engine.generateDailyTasks(config);

    // Filter out skipped items
    if (skippedRefs.isEmpty) return tasks;
    return tasks
        .where((t) => !skippedRefs.contains(t.contentItemSefariaRef))
        .toList();
  }

  /// Generate daily tasks across multiple curricula.
  ///
  /// [goalDeadlines] maps curriculum IDs to their earliest goal deadline,
  /// enabling deadline-aware pacing.
  Future<List<DailyTask>> generateAll(
    List<CurriculumId> curricula,
    DateTime date, {
    Set<String> skippedRefs = const {},
    Map<CurriculumId, DateTime> goalDeadlines = const {},
    Map<CurriculumId, double> pacePerDayMap = const {},
    Map<CurriculumId, bool> isStudyDayMap = const {},
    Map<CurriculumId, int> studyDaysPerWeekMap = const {},
  }) async {
    final allTasks = <DailyTask>[];

    for (final curriculum in curricula) {
      final tasks = await generate(
        curriculum,
        date,
        goalDeadline: goalDeadlines[curriculum],
        pacePerDay: pacePerDayMap[curriculum],
        isStudyDay: isStudyDayMap[curriculum] ?? true,
        studyDaysPerWeek: studyDaysPerWeekMap[curriculum] ?? 7,
        skippedRefs: skippedRefs,
      );
      allTasks.addAll(tasks);
    }

    // Sort by priority across all curricula
    allTasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return allTasks;
  }
}
