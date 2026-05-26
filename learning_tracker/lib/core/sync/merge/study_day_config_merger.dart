/// LWW merger for study-day config rows.
///
/// Natural key: `(curriculumId, dayOfWeek, trackId)` — the Drift PK minus
/// `profileId` (which is implicit in the per-profile Firestore subcollection
/// scope). Remote wins iff its `updated_at` is strictly newer than local;
/// ties go to local to avoid flapping.
library;

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/study_day_config_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

class StudyDayConfigMerger implements EntityMerger {
  StudyDayConfigMerger(UserDatabase db) : _db = db;

  final UserDatabase _db;
  static const _codec = StudyDayConfigCodec();

  @override
  String get kind => EntityKind.studyDayConfig;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue;

      // Use the profile_id from the document only if it matches the active
      // profile scope — defensive: the subcollection path already binds the
      // document to this profile, so a payload claiming a different profile
      // is treated as malformed.
      final docProfileId = decoded.profileId == 0
          ? profileId
          : decoded.profileId;
      if (docProfileId != profileId) continue;

      // study_day_configs.trackId is a FK into curriculum_tracks. If the
      // referenced track is not present locally yet (e.g. this listener
      // snapshot merged before the curriculum_tracks snapshot, or a
      // cross-device id mismatch), inserting would throw a FK-constraint
      // violation that fails the ENTIRE study_day_configs channel merge —
      // which in turn triggers a dashboard rebuild storm. Skip the row; the
      // next full pull re-merges it (LWW, idempotent) once the track exists.
      final trackExists = await (_db.select(
        _db.curriculumTracks,
      )..where((t) => t.id.equals(decoded.trackId))).getSingleOrNull();
      if (trackExists == null) continue;

      final localRow =
          await (_db.select(_db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(decoded.curriculumId) &
                    t.dayOfWeek.equals(decoded.dayOfWeek) &
                    t.trackId.equals(decoded.trackId),
              ))
              .getSingleOrNull();

      if (!remoteIsNewer(
        localUpdatedAt: localRow?.updatedAt,
        remoteUpdatedAt: decoded.updatedAt,
      )) {
        continue;
      }

      await _db
          .into(_db.studyDayConfigs)
          .insertOnConflictUpdate(
            StudyDayConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: decoded.curriculumId,
              trackId: decoded.trackId,
              dayOfWeek: decoded.dayOfWeek,
              dayType: drift.Value(decoded.dayType),
              updatedAt: decoded.updatedAt,
            ),
          );
    }
  }
}
