/// `StreakStateService` — the only read path for streak values.
///
/// Now a thin adapter over [FirestoreStreakStateRepository] — the Drift-backed
/// `streak_events` table and `UserDatabase` are deleted. Delegates `read` →
/// `FirestoreStreakStateRepository.getStreak`, `watch` →
/// `FirestoreStreakStateRepository.watchStreak`.
///
/// ## Behavior changes from the Drift era
///
/// - **restore is gone**: `FirestoreStreakStateRepository` derives state from
///   the synced Firestore event log directly — there is no "local empty log to
///   backfill." D-E fires (`StreakStateRepositoryNotReadyException`) when the
///   backend isn't ready instead.
/// - **`profileId` is ignored**: the active profile is resolved via the [Ref]
///   through `firestoreStreakEventRepositoryProvider`; the `int` is the old
///   Drift primary key with no Firestore equivalent (see
///   `repository_providers.dart`'s "active-profile bridge" doc).
/// - **`dayOf` seam dropped**: `FirestoreStreakStateRepository` does not
///   inject a day-bucketing function. Production behavior is unchanged
///   (`dayOf` defaulted to `LocalDayUtils.extractLocalDate` in both paths).
/// - **`rolloverTicks` RESTORED on `watch`**:
///   `FirestoreStreakStateRepository.watchStreak` has no periodic recompute of
///   its own, so `watch` merges a periodic tick and recomputes on it — see
///   `watch`'s doc comment for why a streak needs a clock-driven refresh.
/// - **`readEvents` throws**: raw-event access is not exposed by
///   [FirestoreStreakStateRepository]; calendar consumers should migrate to
///   [FirestoreStreakStateRepository.getStreakCalendar].
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_streak_state_repository.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';

class StreakStateService {
  StreakStateService({
    required Ref ref,
    LocalDayClock? clock,
  })  : _ref = ref,
        _clock = clock ?? const SystemLocalDayClock();

  final Ref _ref;
  final LocalDayClock _clock;

  FirestoreStreakStateRepository get _firestoreRepo =>
      FirestoreStreakStateRepository(ref: _ref, clock: _clock);

  /// Returns the current [StreakState].
  ///
  /// Delegates to [FirestoreStreakStateRepository.getStreak], which throws
  /// [StreakStateRepositoryNotReadyException] when no account/profile is
  /// active (D-E: a streak of zero would be indistinguishable from a real
  /// empty read).
  Future<StreakState> read({required int profileId}) =>
      _firestoreRepo.getStreak();

  /// Reactive read — re-emits whenever the streak event log changes.
  ///
  /// Delegates to [FirestoreStreakStateRepository.watchStreak]. [profileId]
  /// is ignored — see class doc comment.
  /// Live streak state, recomputed on every event AND on a periodic tick.
  ///
  /// The tick restores D17. A streak is computed relative to TODAY, but
  /// `FirestoreStreakStateRepository.watchStreak` re-emits only when the EVENT
  /// stream emits. Without a tick, a child whose streak is 5 at 23:59 and who
  /// does not study still sees 5 after local midnight — until some unrelated
  /// event happens to fire the stream. The headline number would then disagree
  /// with the calendar dots, which is the disagreement D17 exists to prevent.
  ///
  /// The interval need not be precise; it only bounds how long a stale day can
  /// remain on screen. 15 minutes matches the original `_defaultRolloverTicks`.
  ///
  /// [profileId] is ignored — the repository is profile-scoped by its
  /// collection path. It is retained so existing call sites keep compiling.
  Stream<StreakState> watch({
    required int profileId,
    Stream<void>? rolloverTicks,
  }) {
    final ticks =
        rolloverTicks ?? Stream<void>.periodic(const Duration(minutes: 15));
    final controller = StreamController<StreakState>();
    StreamSubscription<StreakState>? eventsSub;
    StreamSubscription<void>? tickSub;

    Future<void> recompute() async {
      try {
        controller.add(await _firestoreRepo.getStreak());
      } catch (error, stackTrace) {
        // Surface rather than swallow: a not-ready backend must not be
        // rendered as a streak of zero (owner ruling D-E).
        controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () {
      eventsSub = _firestoreRepo.watchStreak().listen(
        controller.add,
        onError: controller.addError,
      );
      tickSub = ticks.listen((_) => recompute());
    };
    controller.onCancel = () async {
      await eventsSub?.cancel();
      await tickSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Active local days in `[startUtc, endUtc]`, for the calendar dots.
  ///
  /// Replaces the former `readEvents` accessor. That existed only so
  /// `StreakService` could walk raw events and bucket them by local day —
  /// work `FirestoreStreakStateRepository.getStreakCalendar` already does
  /// identically. Exposing raw events again would mean importing the
  /// data-access ring from here, which AD-23 forbids.
  Future<Set<DateTime>> streakCalendar({
    required DateTime startUtc,
    required DateTime endUtc,
  }) =>
      _firestoreRepo.getStreakCalendar(startUtc: startUtc, endUtc: endUtc);
}
