import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Domain entity representing a learning goal with an optional deadline.
///
/// Goals are per-curriculum and drive the scheduler's pacing calculations.
/// Multiple goals per curriculum are allowed (e.g., "finish Seder Zeraim by
/// Pesach, all Mishnayos by bar mitzvah").
class GoalEntity {
  final int? id;
  final CurriculumId curriculumId;
  final double targetPercent;
  final DateTime? targetDate;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalEntity({
    this.id,
    required this.curriculumId,
    this.targetPercent = 100.0,
    this.targetDate,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  GoalEntity copyWith({
    int? id,
    CurriculumId? curriculumId,
    double? targetPercent,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      curriculumId: curriculumId ?? this.curriculumId,
      targetPercent: targetPercent ?? this.targetPercent,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore document ID (deterministic per P4).
  /// Uses curriculum + createdAt for uniqueness since multiple goals per
  /// curriculum are allowed.
  String get firestoreId =>
      '${curriculumId.storageKey}_${createdAt.millisecondsSinceEpoch}';

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
          ? DateTime.parse(data['targetDate'] as String)
          : null,
      description: data['description'] as String? ?? '',
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
    );
  }
}
