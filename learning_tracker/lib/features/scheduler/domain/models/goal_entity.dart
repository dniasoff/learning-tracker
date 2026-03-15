import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'goal_entity.freezed.dart';

/// Domain entity representing a learning goal with an optional deadline.
///
/// Goals are per-curriculum and drive the scheduler's pacing calculations.
/// Multiple goals per curriculum are allowed (e.g., "finish Seder Zeraim by
/// Pesach, all Mishnayos by bar mitzvah").
@freezed
abstract class GoalEntity with _$GoalEntity {
  const GoalEntity._();

  const factory GoalEntity({
    int? id,
    required CurriculumId curriculumId,
    @Default(100.0) double targetPercent,
    DateTime? targetDate,
    @Default('') String description,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _GoalEntity;

  /// Firestore document ID (deterministic per P4).
  /// Uses curriculum + targetPercent + targetDate + createdAt for uniqueness
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
  Map<String, dynamic> toFirestore() {
    return {
      'curriculumId': curriculumId.storageKey,
      'targetPercent': targetPercent,
      'targetDate': targetDate?.toIso8601String(),
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from Firestore document.
  static GoalEntity fromFirestore(Map<String, dynamic> data) {
    return GoalEntity(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == data['curriculumId'] as String,
        orElse: () => throw ArgumentError(
          'Unknown curriculumId: ${data['curriculumId']}',
        ),
      ),
      targetPercent: (data['targetPercent'] as num?)?.toDouble() ?? 100.0,
      targetDate: data['targetDate'] != null
          ? DateTime.parse(data['targetDate'] as String).toUtc()
          : null,
      description: data['description'] as String? ?? '',
      createdAt: DateTime.parse(data['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(data['updatedAt'] as String).toUtc(),
    );
  }
}
