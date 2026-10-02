/// The governed (AD-38) write of a goal chosen from a sub-track form's
/// no-deadline link (Story 2.4 / DNI-495 AC-6).
///
/// The link reuses the existing goal setup screen, but its result is not
/// written through the legacy goal repository: governed goal docs live at
/// the AD-43 fixed ids `goals/{curriculumId}_deadline` and
/// `goals/{curriculumId}_pace`, and every write carries a change-log entry
/// (`LearningCommands.applyGovernedChange`, C0 / DNI-524). This file maps
/// the chosen goal onto that contract as changed fields only.
///
/// Pure: imports only `lib/domain/learner_state/**`.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';

/// The governed goal collection.
const kGoalsCollection = 'goals';

/// `goals/{curriculumId}_deadline` (AD-43).
String deadlineGoalDocId(String curriculumId) => '${curriculumId}_deadline';

/// `goals/{curriculumId}_pace` (AD-43).
String paceGoalDocId(String curriculumId) => '${curriculumId}_pace';

/// The `pace_granularity` of a pace goal counted in the curriculum's leaf
/// units: what the goal setup screen counts in for a curriculum without a
/// unit picker (e.g. Mishnayos). A governed pace goal always carries a
/// granularity (AD-43; `writeWithChangeLog` rejects one without it).
const kLeafPaceGranularity = 'item';

/// What the parent chose on the goal setup screen.
sealed class GoalChoice {
  const GoalChoice();
}

/// Finish the curriculum by [targetDate].
final class DeadlineGoalChoice extends GoalChoice {
  /// Creates the choice.
  const DeadlineGoalChoice(this.targetDate);

  /// The civil target date (`YYYY-MM-DD`).
  final CivilDate targetDate;
}

/// Learn [value] [unit] (per period) of [granularity].
final class PaceGoalChoice extends GoalChoice {
  /// Creates the choice.
  const PaceGoalChoice({
    required this.value,
    required this.unit,
    required this.granularity,
  });

  /// How many.
  final num value;

  /// The pace period, storage form (e.g. `per_week`).
  final String unit;

  /// The learning granularity, storage form ([kLeafPaceGranularity] for
  /// leaf units). Required: AD-43 pace goals always carry one.
  final String granularity;
}

/// No goal: any live goal of the curriculum is ended.
final class NoGoalChoice extends GoalChoice {
  /// Creates the choice.
  const NoGoalChoice();
}

/// The governed action that turns [current] (the curriculum's goals as read,
/// or null) into [choice], carrying only changed fields; null when nothing
/// changes.
///
/// - A deadline or pace choice upserts that goal's fixed-id doc; a doc that
///   was ended is revived (`ended_at` cleared). The other goal is left alone:
///   AD-43 allows one of each.
/// - [NoGoalChoice] ends every live goal doc with `ended_at` = [nowUtc].
GovernedAction? governedGoalAction({
  required String curriculumId,
  required GoalChoice choice,
  required CurriculumGoals? current,
  required DateTime nowUtc,
}) {
  final changes = <GovernedEntityChange>[];
  final deadline = current?.deadline;
  final pace = current?.pace;

  switch (choice) {
    case DeadlineGoalChoice(:final targetDate):
      final fields = <String, Object?>{
        if (deadline == null) ...{
          'goal_type': 'deadline',
          'curriculum_id': curriculumId,
        },
        if (deadline?.targetDate != targetDate) 'target_date': targetDate,
        if (deadline?.endedAt != null) 'ended_at': null,
      };
      if (fields.isNotEmpty) {
        changes.add(_change(deadlineGoalDocId(curriculumId), fields));
      }
    case PaceGoalChoice(:final value, :final unit, :final granularity):
      final fields = <String, Object?>{
        if (pace == null) ...{
          'goal_type': 'pace',
          'curriculum_id': curriculumId,
        },
        if (pace?.paceValue != value) 'pace_value': value,
        if (pace?.paceUnit != unit) 'pace_unit': unit,
        if (pace?.paceGranularity != granularity)
          'pace_granularity': granularity,
        if (pace?.endedAt != null) 'ended_at': null,
      };
      if (fields.isNotEmpty) {
        changes.add(_change(paceGoalDocId(curriculumId), fields));
      }
    case NoGoalChoice():
      if (deadline != null && deadline.endedAt == null) {
        changes.add(
          _change(deadlineGoalDocId(curriculumId), {'ended_at': nowUtc}),
        );
      }
      if (pace != null && pace.endedAt == null) {
        changes.add(_change(paceGoalDocId(curriculumId), {'ended_at': nowUtc}));
      }
  }
  return changes.isEmpty ? null : GovernedAction(changes);
}

GovernedEntityChange _change(String docId, Map<String, Object?> fields) =>
    GovernedEntityChange(
      entity: GovernedEntity.goal,
      entityId: docId,
      docs: [
        GovernedDocPatch(
          collection: kGoalsCollection,
          docId: docId,
          fields: fields,
        ),
      ],
    );
