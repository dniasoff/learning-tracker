/// `StreakStateProvider` — the only read path for streak values.
///
/// Wraps `[Restorer → Reducer]`:
///
///   1. Ensure the local log isn't empty (restore from `completions`
///      on first launch / new device).
///   2. Replay `streak_events` through [StreakReducer] using the
///      [LocalDayClock]'s "today" UTC.
///
/// `StreakService.recordCompletion` writes are gone (Story 25.16) —
/// state is derived, never assigned.
library;

import 'package:learning_tracker/core/database/user/user_database.dart'
    hide StreakEvent;
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/streak/streak_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';
import 'package:learning_tracker/features/gamification/streak/streak_restorer.dart';

class StreakStateProvider {
  StreakStateProvider({required UserDatabase db, required LocalDayClock clock})
    : _db = db,
      _clock = clock,
      _restorer = StreakRestorer(db);

  final UserDatabase _db;
  final LocalDayClock _clock;
  final StreakRestorer _restorer;

  /// Returns the raw [StreakEvent] list for [profileId].
  ///
  /// Used by callers that need per-event detail (e.g. calendar heatmaps).
  Future<Iterable<StreakEvent>> readEvents({required int profileId}) async {
    final rows = await (_db.select(
      _db.streakEvents,
    )..where((t) => t.profileId.equals(profileId))).get();
    return rows.map(
      (r) => StreakEvent(
        profileId: r.profileId,
        eventType: r.eventType,
        eventTimestamp: r.eventTimestamp,
        clientDeviceId: r.clientDeviceId,
      ),
    );
  }

  /// Returns the current [StreakState] for [profileId].
  Future<StreakState> read({required int profileId}) async {
    await _restorer.restoreIfEmpty(profileId: profileId);
    final rows = await (_db.select(
      _db.streakEvents,
    )..where((t) => t.profileId.equals(profileId))).get();
    final events = rows.map(
      (r) => StreakEvent(
        profileId: r.profileId,
        eventType: r.eventType,
        eventTimestamp: r.eventTimestamp,
        clientDeviceId: r.clientDeviceId,
      ),
    );
    return const StreakReducer().reduce(events, today: _clock.nowUtc());
  }

  /// Reactive read — re-emits whenever `streak_events` for the profile
  /// changes (e.g. a sync pull lands a new row).
  Stream<StreakState> watch({required int profileId}) async* {
    await _restorer.restoreIfEmpty(profileId: profileId);
    final today = _clock.nowUtc();
    yield* (_db.select(
      _db.streakEvents,
    )..where((t) => t.profileId.equals(profileId))).watch().map(
      (rows) => const StreakReducer().reduce(
        rows.map(
          (r) => StreakEvent(
            profileId: r.profileId,
            eventType: r.eventType,
            eventTimestamp: r.eventTimestamp,
            clientDeviceId: r.clientDeviceId,
          ),
        ),
        today: today,
      ),
    );
  }
}
