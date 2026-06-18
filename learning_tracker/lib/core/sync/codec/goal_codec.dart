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
    this.trackId,
    this.targetPercent = 100.0,
    this.description = '',
    this.dateType = 'gregorian',
    this.goalType = 'deadline',
    this.paceValue,
    this.pacePeriod,
    this.paceGranularity,
    this.targetDate,
  });

  final String firestoreId;
  final int profileId;
  final String curriculumId;
  final DateTime updatedAt;
  final DateTime createdAt;
  final int? trackId;
  final double targetPercent;
  final String description;
  final String dateType;
  final String goalType;
  final int? paceValue;
  final String? pacePeriod;
  final String? paceGranularity;
  final DateTime? targetDate;
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
      trackId: FirestoreCodec.parseInt(raw['track_id']),
      targetPercent:
          ((raw['target_percent'] ?? raw['targetPercent']) as num?)
              ?.toDouble() ??
          100.0,
      description: raw['description'] as String? ?? '',
      dateType: (raw['date_type'] ?? raw['dateType']) as String? ?? 'gregorian',
      goalType: (raw['goal_type'] ?? raw['goalType']) as String? ?? 'deadline',
      paceValue: FirestoreCodec.parseInt(raw['pace_value']),
      // Live writers emit `pace_unit` (the rule-legal key). `pace_period` and
      // `pacePeriod` are legacy aliases kept only as read fallbacks for any
      // pre-fix documents.
      pacePeriod:
          (raw['pace_unit'] ?? raw['pace_period'] ?? raw['pacePeriod'])
              as String?,
      paceGranularity:
          (raw['pace_granularity'] ?? raw['paceGranularity']) as String?,
      targetDate: FirestoreCodec.parseDateTime(raw['target_date']),
    );
  }

  @override
  Map<String, dynamic> encode(GoalRow model) => {
    // Only rule-legal keys (see `goals` hasOnly() in firestore.rules).
    // The doc id carries the firestore_id; it is injected post-encode at the
    // call site (cf. _serverInjectedKeys in codec_rules_contract_test).
    // Pace unit is keyed `pace_unit` (NOT `pace_period`).
    'profile_id': model.profileId,
    'curriculum_id': model.curriculumId,
    if (model.trackId != null) 'track_id': model.trackId,
    'target_percent': model.targetPercent,
    'description': model.description,
    'date_type': model.dateType,
    'goal_type': model.goalType,
    'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
    'created_at': FirestoreCodec.encodeDateTime(model.createdAt),
    if (model.paceValue != null) 'pace_value': model.paceValue,
    if (model.pacePeriod != null) 'pace_unit': model.pacePeriod,
    if (model.paceGranularity != null)
      'pace_granularity': model.paceGranularity,
    if (model.targetDate != null)
      'target_date': FirestoreCodec.encodeDateTime(model.targetDate),
  };
}
