/// AD-39 curriculum goals: a deadline and a pace, each optional.
///
/// Storage (AD-52, DNI-470 codecs): a curriculum's deadline goal is the
/// fixed doc `goals/{curriculumId}_deadline` (`goal_type = 'deadline'`,
/// `target_date`), its pace goal `goals/{curriculumId}_pace` (`goal_type =
/// 'pace'`, `pace_value`, `pace_unit`, `pace_granularity`); both carry
/// `curriculum_id`, `last_change_id` and `ended_at`. Decoding is a
/// projection: legacy keys still present on old goal docs
/// (`target_percent`, `updated_at`, ...) are ignored and never re-emitted.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// `goals` collection name.
const String kGoalsCollection = 'goals';

/// Storage key `goal_type`.
const String kGoalType = 'goal_type';

/// The [DeadlineGoal] doc id of [curriculumId].
String deadlineGoalDocId(String curriculumId) => '${curriculumId}_deadline';

/// The [PaceGoal] doc id of [curriculumId].
String paceGoalDocId(String curriculumId) => '${curriculumId}_pace';

/// Finish the curriculum by [targetDate].
final class DeadlineGoal {
  /// Creates a deadline goal.
  const DeadlineGoal({
    required this.curriculumId,
    required this.targetDate,
    this.lastChangeId,
    this.endedAt,
  });

  /// Projects the AD-52 keys out of goal doc [docId]. Throws
  /// [StorageFormatException] unless it is a well-formed deadline goal at
  /// [deadlineGoalDocId] of its `curriculum_id`.
  factory DeadlineGoal.fromStorage(String docId, Map<String, Object?> map) {
    final r = StorageReader(_type, map);
    if (r.requiredString(kGoalType) != goalType) {
      throw const StorageFormatException(_type, kGoalType, 'not deadline');
    }
    final targetDate = r.requiredString(kTargetDate);
    if (!isCivilDate(targetDate)) {
      throw const StorageFormatException(_type, kTargetDate, 'not a date');
    }
    final goal = DeadlineGoal(
      curriculumId: r.requiredString(GovernedKeys.curriculumId),
      targetDate: targetDate,
      lastChangeId: r.optionalUlid(GovernedKeys.lastChangeId),
      endedAt: r.optionalInstant(GovernedKeys.endedAt),
    );
    if (docId != deadlineGoalDocId(goal.curriculumId)) {
      throw const StorageFormatException(_type, '<id>', 'not the fixed id');
    }
    return goal;
  }

  static const _type = 'DeadlineGoal';

  /// The `goal_type` value.
  static const goalType = 'deadline';

  /// Storage key `target_date`.
  static const kTargetDate = 'target_date';

  /// Encodes the AD-52 keys only.
  Map<String, Object?> toStorage() => {
    kGoalType: goalType,
    kTargetDate: targetDate,
    GovernedKeys.curriculumId: curriculumId,
    if (lastChangeId != null) GovernedKeys.lastChangeId: lastChangeId,
    if (endedAt != null) GovernedKeys.endedAt: endedAt!.toUtc(),
  };

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

  /// Projects the AD-52 keys out of goal doc [docId]. Throws
  /// [StorageFormatException] unless it is a well-formed pace goal at
  /// [paceGoalDocId] of its `curriculum_id`.
  factory PaceGoal.fromStorage(String docId, Map<String, Object?> map) {
    final r = StorageReader(_type, map);
    if (r.requiredString(kGoalType) != goalType) {
      throw const StorageFormatException(_type, kGoalType, 'not pace');
    }
    final value = r.required<num>(kPaceValue);
    if (!value.isFinite || value <= 0) {
      throw const StorageFormatException(_type, kPaceValue, 'not positive');
    }
    final goal = PaceGoal(
      curriculumId: r.requiredString(GovernedKeys.curriculumId),
      paceValue: value,
      paceUnit: r.requiredString(kPaceUnit),
      paceGranularity: r.requiredString(kPaceGranularity),
      lastChangeId: r.optionalUlid(GovernedKeys.lastChangeId),
      endedAt: r.optionalInstant(GovernedKeys.endedAt),
    );
    if (docId != paceGoalDocId(goal.curriculumId)) {
      throw const StorageFormatException(_type, '<id>', 'not the fixed id');
    }
    return goal;
  }

  static const _type = 'PaceGoal';

  /// The `goal_type` value.
  static const goalType = 'pace';

  /// Storage key `pace_value`.
  static const kPaceValue = 'pace_value';

  /// Storage key `pace_unit`.
  static const kPaceUnit = 'pace_unit';

  /// Storage key `pace_granularity`.
  static const kPaceGranularity = 'pace_granularity';

  /// Encodes the AD-52 keys only.
  Map<String, Object?> toStorage() => {
    kGoalType: goalType,
    kPaceValue: paceValue,
    kPaceUnit: paceUnit,
    kPaceGranularity: paceGranularity,
    GovernedKeys.curriculumId: curriculumId,
    if (lastChangeId != null) GovernedKeys.lastChangeId: lastChangeId,
    if (endedAt != null) GovernedKeys.endedAt: endedAt!.toUtc(),
  };

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
