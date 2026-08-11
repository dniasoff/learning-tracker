/// Domain service backing `study_day_config_screen.dart`'s
/// write-then-invalidate ordering.
///
/// Extracted from the screen (AUD-t-scheduler-02) so regression tests can
/// drive the real behavior instead of re-deriving it inline — the same
/// testability pattern `sefaria_ref_matcher.dart` uses for the scheduler's
/// ref-matching logic. No behavior change: the screen calls these exact
/// functions.
///
/// **Track-resolution removed (Phase 3).** The Drift-era `resolveStudyDayTrackId`
/// / `withResolvedStudyDayTrackId` guard (STUDYDAY-COMPANION-10) existed only
/// because `study_day_configs.track_id` was a Drift foreign key that could not
/// tolerate a synthesized `trackId = 0`. `FirestoreStudyDayConfigRepositoryAdapter.setDayConfig`
/// (`lib/features/scheduler/data/repositories/study_day_config_repository_impl.dart`)
/// is keyed on `CurriculumId` directly — there is no track row, and therefore
/// no FK to violate — so the guard has no Firestore equivalent to migrate to.
library;

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
