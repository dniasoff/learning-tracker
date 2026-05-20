/// Codec for Firestore `goals/{firestoreId}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a goal document.
class GoalRow {
  const GoalRow({
    required this.firestoreId,
    required this.profileId,
    required this.curriculumId,
    required this.updatedAt,
    required this.createdAt,
    this.paceValue,
    this.pacePeriod,
    this.targetDate,
    this.isActive = true,
  });

  final String firestoreId;
  final int profileId;
  final String curriculumId;
  final DateTime updatedAt;
  final DateTime createdAt;
  final int? paceValue;
  final String? pacePeriod;
  final DateTime? targetDate;
  final bool isActive;
}

/// Codec for the `goals` Firestore collection.
///
/// Natural key: `firestoreId`.
/// LWW: remote wins when `updated_at` is strictly newer.
class GoalCodec extends EntityCodec<GoalRow> {
  const GoalCodec();

  @override
  String get kind => EntityKind.goal;

  @override
  GoalRow? decode(Map<String, dynamic> raw) {
    final firestoreId = raw['firestore_id'] as String?;
    final profileId = FirestoreCodec.parseInt(raw['profile_id']);
    final curriculumId = raw['curriculum_id'] as String?;
    final updatedAt = FirestoreCodec.parseDateTime(raw['updated_at']);
    final createdAt = FirestoreCodec.parseDateTime(raw['created_at']);

    if (firestoreId == null ||
        profileId == null ||
        curriculumId == null ||
        updatedAt == null ||
        createdAt == null) {
      return null;
    }

    return GoalRow(
      firestoreId: firestoreId,
      profileId: profileId,
      curriculumId: curriculumId,
      updatedAt: updatedAt,
      createdAt: createdAt,
      paceValue: FirestoreCodec.parseInt(raw['pace_value']),
      pacePeriod: raw['pace_period'] as String?,
      targetDate: FirestoreCodec.parseDateTime(raw['target_date']),
      isActive: FirestoreCodec.parseBool(raw['is_active']) ?? true,
    );
  }

  @override
  Map<String, dynamic> encode(GoalRow model) => {
        'firestore_id': model.firestoreId,
        'profile_id': model.profileId,
        'curriculum_id': model.curriculumId,
        'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
        'created_at': FirestoreCodec.encodeDateTime(model.createdAt),
        'is_active': model.isActive,
        if (model.paceValue != null) 'pace_value': model.paceValue,
        if (model.pacePeriod != null) 'pace_period': model.pacePeriod,
        if (model.targetDate != null)
          'target_date': FirestoreCodec.encodeDateTime(model.targetDate),
      };
}
