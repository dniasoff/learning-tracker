/// Domain service backing `study_day_config_screen.dart`'s track-resolution
/// guard and write-then-invalidate ordering.
///
/// Extracted from the screen (AUD-t-scheduler-02) so regression tests can
/// drive the real behavior instead of re-deriving it inline — the same
/// testability pattern `sefaria_ref_matcher.dart` uses for the scheduler's
/// ref-matching logic. No behavior change: the screen calls these exact
/// functions.
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

/// Looks up the [CurriculumTrack] row id for [profileId] + [curriculumId],
/// returning `null` when no matching track exists yet (e.g. a race at first
/// activation, or the track having just been deleted).
Future<int?> resolveStudyDayTrackId(
  UserDatabase db, {
  required int profileId,
  required String curriculumId,
}) async {
  final track =
      await (db.select(db.curriculumTracks)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId),
            )
            ..limit(1))
          .getSingleOrNull();
  return track?.id;
}

/// Resolves the track id for [profileId] + [curriculumId] and, only when one
/// is found, awaits [onFound] with it.
///
/// STUDYDAY-COMPANION-10: this is the guard against the fallback-0 FK-
/// constraint crash — when no track exists yet, this no-ops rather than
/// calling [onFound] with a synthesized `trackId = 0`, which would violate
/// the FK constraint on `study_day_configs.track_id → curriculum_tracks.id`.
Future<void> withResolvedStudyDayTrackId(
  UserDatabase db, {
  required int profileId,
  required String curriculumId,
  required Future<void> Function(int trackId) onFound,
}) async {
  final trackId = await resolveStudyDayTrackId(
    db,
    profileId: profileId,
    curriculumId: curriculumId,
  );
  if (trackId == null) return;
  await onFound(trackId);
}

/// Awaits [write] to completion, then invokes [invalidate].
///
/// STUDYDAY-TOGGLE-RACE-14: [invalidate] must never run before [write] has
/// resolved — the historical bug called the scheduler invalidation
/// synchronously, outside the write's `.then()` closure, so the scheduler
/// rebuilt from stale study-day data.
///
/// A failing [write] propagates raw (EH-2: this domain-layer helper throws;
/// [invalidate] is correctly skipped). [writeThenInvalidateGuarded] is the
/// presentation-facing wrapper that converts that raw exception into a
/// logged, non-crashing outcome (EH-3).
Future<void> writeThenInvalidate({
  required Future<void> Function() write,
  required void Function() invalidate,
}) async {
  await write();
  invalidate();
}

/// Presentation-layer wrapper around [writeThenInvalidate] (AUD-scheduler-17).
///
/// Runs [write], then — only on success, and only when [isMounted] still
/// returns `true` — invokes [invalidate]. On failure, routes the error to
/// [onError] (never lets it propagate as an unhandled Future error) and
/// returns `false` so the caller can skip any follow-up that depends on the
/// write having actually persisted (e.g. `_toggleDay` skips the sync push
/// when the local write failed). Returns `true` when [write] succeeded.
///
/// This is the exact function `study_day_config_screen.dart:_toggleDay`
/// calls — matching the AUD-t-scheduler-02 testability pattern used by
/// [writeThenInvalidate] itself: tests drive this function directly instead
/// of re-deriving the guard/error-handling logic inline.
Future<bool> writeThenInvalidateGuarded({
  required Future<void> Function() write,
  required void Function() invalidate,
  required bool Function() isMounted,
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    await writeThenInvalidate(
      write: write,
      invalidate: () {
        if (isMounted()) invalidate();
      },
    );
    return true;
  } catch (e, st) {
    onError(e, st);
    return false;
  }
}
