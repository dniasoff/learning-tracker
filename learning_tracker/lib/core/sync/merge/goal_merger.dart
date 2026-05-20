import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// LWW merger for per-track goal rows (W2.27 / closes M1).
///
/// Natural key: `track_id`. Remote wins iff its `updated_at` is strictly
/// newer than the local row — handled inside [GoalDao.upsertGoalByTrack]
/// which already applies the LWW rule.
///
/// Firestore shape (from SyncEngine._mergeGoals):
///   curriculum_id, track_id, description, target_percent, target_date,
///   date_type, goal_type, pace_value, pace_unit, created_at, updated_at.
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
      final rawTid = row['track_id'];
      final trackId = rawTid is int
          ? rawTid
          : rawTid is num
          ? rawTid.toInt()
          : int.tryParse(rawTid?.toString() ?? '');
      final createdAt = _parseTimestamp(row['created_at']);
      final updatedAt = _parseTimestamp(row['updated_at']);

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
        targetDate: _parseTimestamp(row['target_date']),
        dateType: row['date_type'] as String? ?? 'gregorian',
        goalType: row['goal_type'] as String? ?? 'deadline',
        paceValue: (row['pace_value'] as num?)?.toInt(),
        pacePeriod: row['pace_unit'] as String?,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }
  }

  DateTime? _parseTimestamp(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
