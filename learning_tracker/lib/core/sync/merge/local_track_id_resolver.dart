/// Shared local-track-id resolution for every child-row merger.
///
/// AUD-t-cross-43: `goal_merger.dart`, `gamification_settings_merger.dart`,
/// `study_day_config_merger.dart`, and `drift_merge_store.dart`'s own
/// `_upsertSettings`/`_upsertStageDefinition` each independently re-derived
/// this exact "remote track_id → local mirror track_id" remap (Bug 3), and
/// had drifted into inconsistent fallback semantics: most sites additionally
/// accepted a raw `TrackDao.getById(remoteTrackId)` existence check as a
/// fallback, while [GamificationSettingsMerger] did not. On a device holding
/// multiple local profiles, `curriculum_tracks` ids are a single shared
/// keyspace across all of them, so that extra fallback could coincidentally
/// match an UNRELATED profile's or curriculum's track and silently bind a
/// row to it — the getById fallback is deliberately NOT reproduced here.
library;

import 'package:learning_tracker/core/database/user/user_database.dart';

/// Resolves the LOCAL `curriculum_tracks.id` a child-row merger (goal,
/// gamification_settings points_config, study_day_config, settings,
/// stage_definition) should bind its row to.
///
/// Every one of these entities carries a `track_id` FK into
/// `curriculum_tracks`, but the id embedded in the Firestore row is whichever
/// LOCAL autoincrement id the PUSHING device had for that (profile,
/// curriculum) pair — never a value shared across devices. Under a tutored
/// mirror the same logical track is re-inserted locally with a DIFFERENT
/// autoincrement id (Bug 3), so a remote row must be rebound to the id this
/// device's [UserDatabase.trackDao] resolves for (profileId, curriculumId),
/// not the id it arrived with.
///
/// Returns `null` when no local track exists yet for `(profileId,
/// curriculumId)` — callers MUST skip the row rather than insert against the
/// row's remote track id directly (AUD-core-sync-07: an unresolved FK throws
/// `SqliteException(787)`, and for a single-transaction batch write like
/// `StageDao.replaceStagesForCurriculum` that aborts every row in the page,
/// not just this one). The next, idempotent pull re-merges the row once the
/// `track_config` channel has synced the track.
Future<int?> resolveLocalTrackId(
  UserDatabase db, {
  required int profileId,
  required String curriculumId,
}) async {
  final localTrack = await db.trackDao.getTrackByProfileAndCurriculum(
    profileId,
    curriculumId,
  );
  return localTrack?.id;
}
