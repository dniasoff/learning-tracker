import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'goal_entity.freezed.dart';

// ─── PaceGranularity ────────────────────────────────────────────────────────

/// Typed granularity for pace-based goals.
///
/// Maps directly to the `paceGranularity` column in the Goals table.
/// Values not listed here (e.g. 'amud', 'pasuk') map to `null` via
/// [fromStorageKey] and are preserved as-is through [toFirestore].
enum PaceGranularity {
  perek('perek'),
  daf('daf'),
  seif('seif');

  const PaceGranularity(this.storageKey);

  /// Storage key written to the DB / Firestore `paceGranularity` column.
  final String storageKey;

  /// Returns the [PaceGranularity] matching [key], or `null` for unknown keys.
  static PaceGranularity? fromStorageKey(String? key) {
    if (key == null) return null;
    for (final v in values) {
      if (v.storageKey == key) return v;
    }
    return null;
  }
}

// ─── PaceTarget ─────────────────────────────────────────────────────────────

/// Sealed discriminant for the two goal modes supported by the scheduler.
sealed class PaceTarget {
  const PaceTarget();
}

/// Goal driven by a hard deadline date.
final class DeadlineTarget extends PaceTarget {
  const DeadlineTarget(this.dueDate);
  final DateTime dueDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeadlineTarget && other.dueDate == dueDate);

  @override
  int get hashCode => Object.hash(runtimeType, dueDate);

  @override
  String toString() => 'DeadlineTarget(dueDate: $dueDate)';
}

/// Goal driven by a target pace (items per period).
final class PacePeriodTarget extends PaceTarget {
  const PacePeriodTarget({required this.rate, required this.period});

  /// Number of items per [period].
  final int rate;

  /// Period key: `'per_day'` or `'per_week'`.
  final String period;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PacePeriodTarget &&
          other.rate == rate &&
          other.period == period);

  @override
  int get hashCode => Object.hash(runtimeType, rate, period);

  @override
  String toString() => 'PacePeriodTarget(rate: $rate, period: $period)';
}

// ─── GoalEntity ─────────────────────────────────────────────────────────────

/// Domain entity representing a learning goal with an optional deadline.
///
/// Goals are per-curriculum and drive the scheduler's pacing calculations.
/// Multiple goals per curriculum are allowed (e.g., "finish Seder Zeraim by
/// Pesach, all Mishnayos by bar mitzvah").
///
/// The typed [paceGranularity] field supersedes the legacy string
/// `paceGranularity` column. For curricula whose units are not yet covered by
/// [PaceGranularity] (e.g. 'amud', 'pasuk') the field is `null` and the
/// raw string is preserved via [rawLearningUnit] for DB round-trips.
@freezed
abstract class GoalEntity with _$GoalEntity {
  const GoalEntity._();

  const factory GoalEntity({
    int? id,
    required CurriculumId curriculumId,
    @Default(100.0) double targetPercent,
    DateTime? targetDate,
    @Default('') String description,

    /// Whether the goal deadline uses Hebrew or Gregorian calendar.
    /// Values: 'hebrew' or 'gregorian' (default).
    @Default('gregorian') String dateType,

    /// Goal mode: 'deadline' (default), 'pace', or 'none'.
    @Default('deadline') String goalType,

    /// Pace value (e.g., 1, 5). Only used when [goalType] == 'pace'.
    int? paceValue,

    /// Pace unit: 'per_day' or 'per_week'. Only used when [goalType] == 'pace'.
    String? pacePeriod,

    /// Typed learning granularity. Covers perek / daf / seif.
    ///
    /// Null when the curriculum uses a granularity not yet in the enum
    /// (e.g. 'amud', 'pasuk') — use [rawLearningUnit] in that case.
    PaceGranularity? paceGranularity,

    /// Raw DB string for the learning unit. Always in sync with
    /// [paceGranularity] — prefer [paceGranularity] over this field.
    String? rawLearningUnit,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _GoalEntity;

  /// Typed [PaceTarget] derived from the entity's mode fields.
  ///
  /// Returns a [DeadlineTarget] when [goalType] is 'deadline' and [targetDate]
  /// is set, a [PacePeriodTarget] when [goalType] is 'pace', or `null`
  /// otherwise (goalType == 'none' or incomplete data).
  PaceTarget? get paceTarget {
    if (goalType == 'deadline' && targetDate != null) {
      return DeadlineTarget(targetDate!);
    }
    if (goalType == 'pace' && paceValue != null && pacePeriod != null) {
      return PacePeriodTarget(rate: paceValue!, period: pacePeriod!);
    }
    return null;
  }

  /// The resolved granularity storage key used for DB / Firestore writes.
  ///
  /// Prefers [paceGranularity.storageKey] when set, falls back to
  /// [rawLearningUnit] for granularities not yet covered by the enum.
  String? get paceGranularityKey =>
      paceGranularity?.storageKey ?? rawLearningUnit;

  /// Firestore document ID (deterministic per P4).
  /// Uses curriculum + targetPercent + createdAt for uniqueness
  /// since multiple goals per curriculum are allowed.
  String get firestoreId {
    final parts = <String>[
      curriculumId.storageKey,
      targetPercent.toStringAsFixed(1),
      createdAt.millisecondsSinceEpoch.toString(),
    ];
    return parts.join('_');
  }

  /// Convert to Firestore document map.
  ///
  /// Uses snake_case keys to match what [GoalMerger] reads on the parent side.
  Map<String, dynamic> toFirestore() {
    return {
      'curriculum_id': curriculumId.storageKey,
      'target_percent': targetPercent,
      'target_date': targetDate?.toIso8601String(),
      'description': description,
      'date_type': dateType,
      'goal_type': goalType,
      'pace_value': paceValue,
      'pace_unit': pacePeriod,
      'pace_granularity': paceGranularityKey,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from Firestore document.
  ///
  /// Accepts both snake_case keys (canonical) and camelCase (back-compat for
  /// any docs written before the snake_case migration).
  static GoalEntity fromFirestore(Map<String, dynamic> data) {
    final rawCurriculumId =
        (data['curriculum_id'] ?? data['curriculumId']) as String;
    final rawUnit =
        (data['pace_granularity'] ?? data['paceGranularity']) as String?;
    return GoalEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == rawCurriculumId,
        orElse: () =>
            throw ArgumentError('Unknown curriculumId: $rawCurriculumId'),
      ),
      targetPercent:
          ((data['target_percent'] ?? data['targetPercent']) as num?)
              ?.toDouble() ??
          100.0,
      targetDate: (data['target_date'] ?? data['targetDate']) != null
          ? DateTime.parse(
              (data['target_date'] ?? data['targetDate']) as String,
            ).toUtc()
          : null,
      description: data['description'] as String? ?? '',
      dateType:
          (data['date_type'] ?? data['dateType']) as String? ?? 'gregorian',
      goalType:
          (data['goal_type'] ?? data['goalType']) as String? ?? 'deadline',
      paceValue: (data['pace_value'] ?? data['paceValue']) as int?,
      pacePeriod: (data['pace_unit'] ?? data['pacePeriod']) as String?,
      paceGranularity: PaceGranularity.fromStorageKey(rawUnit),
      rawLearningUnit: PaceGranularity.fromStorageKey(rawUnit) == null
          ? rawUnit
          : null,
      createdAt: DateTime.parse(
        (data['created_at'] ?? data['createdAt']) as String,
      ).toUtc(),
      updatedAt: DateTime.parse(
        (data['updated_at'] ?? data['updatedAt']) as String,
      ).toUtc(),
    );
  }
}
