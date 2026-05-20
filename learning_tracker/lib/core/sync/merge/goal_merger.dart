/// LWW merger for per-track goal rows (W2.27 / closes M1).
///
/// Natural key: `track_id`. Remote wins iff its `updated_at` is strictly
/// newer than the local row — handled inside [GoalDao.upsertGoalByTrack]
/// which already applies the LWW rule.
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class GoalMerger implements EntityMerger {
  GoalMerger(UserDatabase db) : _db = db;

  final UserDatabase _db;

  @override
  String get kind => EntityKind.goal;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final curriculumId = row['curriculum_id'] as String?;
      final trackId = FirestoreCodec.parseInt(row['track_id']);
      final createdAt = FirestoreCodec.parseDateTime(row['created_at']);
      final updatedAt = FirestoreCodec.parseDateTime(row['updated_at']);

      if (curriculumId == null ||
          trackId == null ||
          trackId == 0 ||
          createdAt == null ||
          updatedAt == null) {
        continue;
      }

      await _db.goalDao.upsertGoalByTrack(
        profileId: profileId,
        trackId: trackId,
        curriculumId: curriculumId,
        description: row['description'] as String? ?? '',
        targetPercent: (row['target_percent'] as num?)?.toDouble() ?? 100.0,
        targetDate: FirestoreCodec.parseDateTime(row['target_date']),
        dateType: row['date_type'] as String? ?? 'gregorian',
        goalType: row['goal_type'] as String? ?? 'deadline',
        paceValue: FirestoreCodec.parseInt(row['pace_value']),
        pacePeriod: row['pace_unit'] as String?,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }
  }
}
