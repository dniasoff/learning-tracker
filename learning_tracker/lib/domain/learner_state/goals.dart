/// AD-39 curriculum goals: a deadline and a pace, each optional.
///
/// Value types only; DNI-470 (1.8) adds the storage codecs.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';

/// Finish the curriculum by [targetDate].
final class DeadlineGoal {
  /// Creates a deadline goal.
  const DeadlineGoal({
    required this.curriculumId,
    required this.targetDate,
    this.lastChangeId,
    this.endedAt,
  });

  /// The curriculum.
  final String curriculumId;

  /// The civil target date.
  final CivilDate targetDate;

  /// Last governed change, if any.
  final String? lastChangeId;

  /// Tombstone instant (UTC), if ended.
  final DateTime? endedAt;

  @override
  bool operator ==(Object other) =>
      other is DeadlineGoal &&
      other.curriculumId == curriculumId &&
      other.targetDate == targetDate &&
      other.lastChangeId == lastChangeId &&
      other.endedAt == endedAt;

  @override
  int get hashCode =>
      Object.hash(curriculumId, targetDate, lastChangeId, endedAt);

  @override
  String toString() => 'DeadlineGoal($curriculumId, $targetDate)';
}

/// Learn [paceValue] [paceUnit]s per [paceGranularity].
final class PaceGoal {
  /// Creates a pace goal.
  const PaceGoal({
    required this.curriculumId,
    required this.paceValue,
    required this.paceUnit,
    required this.paceGranularity,
    this.lastChangeId,
    this.endedAt,
  });

  /// The curriculum.
  final String curriculumId;

  /// How many units.
  final num paceValue;

  /// The unit, in storage form.
  final String paceUnit;

  /// The period, in storage form.
  final String paceGranularity;

  /// Last governed change, if any.
  final String? lastChangeId;

  /// Tombstone instant (UTC), if ended.
  final DateTime? endedAt;

  @override
  bool operator ==(Object other) =>
      other is PaceGoal &&
      other.curriculumId == curriculumId &&
      other.paceValue == paceValue &&
      other.paceUnit == paceUnit &&
      other.paceGranularity == paceGranularity &&
      other.lastChangeId == lastChangeId &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(
    curriculumId,
    paceValue,
    paceUnit,
    paceGranularity,
    lastChangeId,
    endedAt,
  );

  @override
  String toString() =>
      'PaceGoal($curriculumId, $paceValue $paceUnit/$paceGranularity)';
}

/// The goals of one curriculum.
final class CurriculumGoals {
  /// Creates the goals; either may be absent.
  const CurriculumGoals({this.deadline, this.pace});

  /// The deadline goal, if set.
  final DeadlineGoal? deadline;

  /// The pace goal, if set.
  final PaceGoal? pace;

  @override
  bool operator ==(Object other) =>
      other is CurriculumGoals &&
      other.deadline == deadline &&
      other.pace == pace;

  @override
  int get hashCode => Object.hash(deadline, pace);

  @override
  String toString() => 'CurriculumGoals($deadline, $pace)';
}
