import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

part 'task_assembly.freezed.dart';

/// The final output of a scheduling run — an ordered list of daily tasks.
///
/// [TaskAssembly] wraps the task list produced by a [SchedulingStrategy].
/// Tasks are pre-sorted by [DailyTaskPriority] (highest first).
///
/// Using a named type (rather than a bare `List<DailyTask>`) lets callers
/// distinguish an assembled result from an intermediate list, and keeps the
/// pipeline's return type explicit.
@freezed
abstract class TaskAssembly with _$TaskAssembly {
  const TaskAssembly._();

  const factory TaskAssembly({
    /// Tasks sorted by priority (overdueProgram → todayProgram →
    /// overdueChazara → scheduledChazara → newLearning).
    required List<DailyTask> tasks,

    /// Human-readable label for the strategy that produced this assembly.
    required String strategyName,
  }) = _TaskAssembly;

  /// Convenience accessor for the task count.
  int get length => tasks.length;

  /// True when no tasks were assembled.
  bool get isEmpty => tasks.isEmpty;

  /// True when at least one task was assembled.
  bool get isNotEmpty => tasks.isNotEmpty;
}
