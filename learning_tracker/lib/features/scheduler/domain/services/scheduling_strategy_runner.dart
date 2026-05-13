import 'package:learning_tracker/features/scheduler/domain/models/scheduler_input.dart';
import 'package:learning_tracker/features/scheduler/domain/models/task_assembly.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduling_strategy.dart';

/// Engine entry point for the strategy-pattern scheduler pipeline.
///
/// [SchedulingStrategyRunner] is stateless and pure: it selects the correct
/// [SchedulingStrategy] from a [SchedulerInput], runs the two-phase
/// Input → [analyse] → [assemble] pipeline, and returns the [TaskAssembly].
///
/// Strategy selection rules (evaluated in order):
/// 1. [SelfPacedSnapshot]  — `pacePerDay != null && trackStartedAt != null`
/// 2. [DeadlineGoal]       — `goalDeadline != null && pacePerDay == null`
/// 3. [ProgramCalendar]    — caller passes explicit `strategy` override
/// 4. [LegacyAdaptive]     — fallback (no goal, no pace, no program)
///
/// The [ProgramCalendar] case is not auto-selected because the program refs
/// must be resolved externally (by the provider layer) before scheduling.
/// Callers that have resolved a calendar program pass the strategy directly.
///
/// Usage:
/// ```dart
/// // Self-paced or deadline paths — auto-select:
/// final assembly = SchedulingStrategyRunner.run(input);
///
/// // Program calendar path — explicit strategy:
/// final assembly = SchedulingStrategyRunner.run(
///   input,
///   strategy: ProgramCalendar(programRefs: resolvedRefs),
/// );
/// ```
class SchedulingStrategyRunner {
  const SchedulingStrategyRunner._();

  /// Select strategy, analyse the input, and assemble the task list.
  ///
  /// Returns a [TaskAssembly] whose [TaskAssembly.tasks] are sorted by
  /// [DailyTaskPriority] ascending (highest priority first).
  static TaskAssembly run(
    SchedulerInput input, {
    SchedulingStrategy? strategy,
  }) {
    final selected = strategy ?? _select(input);
    final analysis = selected.analyse(input);
    return selected.assemble(input, analysis);
  }

  /// Selects the appropriate strategy from [input] signals.
  ///
  /// [ProgramCalendar] is never auto-selected — pass it explicitly.
  static SchedulingStrategy _select(SchedulerInput input) {
    final hasPace = input.pacePerDay != null;
    final hasStartedAt = input.trackStartedAt != null;
    final hasDeadline = input.goalDeadline != null;

    if (hasPace && hasStartedAt) return const SelfPacedSnapshot();
    if (hasDeadline && !hasPace) return const DeadlineGoal();
    return const LegacyAdaptive();
  }
}
