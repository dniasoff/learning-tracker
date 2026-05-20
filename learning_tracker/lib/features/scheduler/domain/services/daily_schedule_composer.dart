import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Result of composing a daily schedule across all active curricula.
class ComposedDailySchedule {
  ComposedDailySchedule({required this.tasks, required this.summary});

  /// The prioritized, capped list of tasks for the day.
  final List<DailyTask> tasks;

  /// Human-readable summary, e.g. "15 tasks across 3 curricula".
  final String summary;

  /// Tasks grouped by curriculum.
  late final Map<CurriculumId, List<DailyTask>> groupedByCurriculum = () {
    final grouped = <CurriculumId, List<DailyTask>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.curriculumId, () => []).add(task);
    }
    return Map<CurriculumId, List<DailyTask>>.unmodifiable(grouped);
  }();
}
