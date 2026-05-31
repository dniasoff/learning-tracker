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

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
    // D16: anchor on the LOCAL day (`today()`), not the UTC instant, so the
    // headline streak agrees with the local-day calendar dots.
    return const StreakReducer().reduce(events, today: _clock.today());
  }

  /// Reactive read — re-emits whenever `streak_events` for the profile
  /// changes (e.g. a sync pull lands a new row) **or** the local day rolls
  /// over (D17). `today` is recomputed on every emission from [_clock] so a
  /// dashboard left open across midnight lapses the streak without a relaunch.
  ///
  /// [rolloverTicks] is injectable for tests; in production it defaults to a
  /// periodic local-midnight check.
  Stream<StreakState> watch({
    required int profileId,
    @visibleForTesting Stream<void>? rolloverTicks,
  }) {
    final controller = StreamController<StreakState>();
    StreamSubscription<List<StreakEvent>>? eventsSub;
    StreamSubscription<void>? tickSub;
    var latest = const <StreakEvent>[];

    // D16/D17: recompute against the CURRENT local day on every signal.
    StreakState compute() =>
        const StreakReducer().reduce(latest, today: _clock.today());

    controller.onListen = () async {
      // D17 fix: an exception thrown inside this async `onListen` body (e.g.
      // `restoreIfEmpty` hitting a Drift handle that is closing during a
      // profile/account swap — the D20 teardown window) is an UNHANDLED async
      // error: it does NOT reach the listener's onError and the stream never
      // emits or closes (perpetual loading). Forward the failure to the
      // controller so the consumer can observe it, matching the pre-D17
      // `async*` behaviour where the throw surfaced as a stream error.
      try {
        await _restorer.restoreIfEmpty(profileId: profileId);
        eventsSub =
            (_db.select(_db.streakEvents)
                  ..where((t) => t.profileId.equals(profileId)))
                .watch()
                .map(
                  (rows) => rows
                      .map(
                        (r) => StreakEvent(
                          profileId: r.profileId,
                          eventType: r.eventType,
                          eventTimestamp: r.eventTimestamp,
                          clientDeviceId: r.clientDeviceId,
                        ),
                      )
                      .toList(),
                )
                .listen((events) {
                  latest = events;
                  if (!controller.isClosed) controller.add(compute());
                });
        tickSub = (rolloverTicks ?? _defaultRolloverTicks()).listen((_) {
          if (!controller.isClosed) controller.add(compute());
        });
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          // Close without awaiting: a `.first`/`take(1)` consumer cancels its
          // subscription on the error, which re-enters `onCancel` (which also
          // closes the controller). Awaiting `close()` here would deadlock
          // against that cancel. The unawaited close still tears the controller
          // down for long-lived `.listen` consumers that don't auto-cancel.
          unawaited(controller.close());
        }
      }
    };
    controller.onCancel = () async {
      await eventsSub?.cancel();
      await tickSub?.cancel();
      eventsSub = null;
      tickSub = null;
      // D17: guard the close — onCancel also fires when a `.first` consumer
      // cancels after the error path above already closed the controller.
      // Closing an already-closed controller from within its own cancel
      // deadlocks the consumer's cancel future, so it stays stuck.
      if (!controller.isClosed) await controller.close();
    };
    return controller.stream;
  }

  /// Production rollover signal: a low-frequency tick so a long-open dashboard
  /// recomputes `today` after a local-midnight boundary. The recompute is
  /// cheap (a reduce over the in-memory event list); the distinct-state UI
  /// makes a no-change tick a no-op.
  Stream<void> _defaultRolloverTicks() =>
      Stream<void>.periodic(const Duration(minutes: 15));
}
