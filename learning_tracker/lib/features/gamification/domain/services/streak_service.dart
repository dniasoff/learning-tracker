import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';

/// Read facade over derived streak state.
///
/// W3.20: the `streaks` snapshot table was dropped. Streak state is now
/// derived exclusively from `streak_events` via [StreakStateService] /
/// [StreakReducer]. This service wraps that read path as a compatibility
/// shim for notification/dashboard call sites.
class StreakService {
  /// AUD-gamification-11 (SM-7): [streakStateProvider] is injectable so
  /// callers — and their tests — can substitute a fake [StreakStateService]
  /// without also faking the whole [UserDatabase]. Defaults to the prior
  /// ad-hoc construction (same `db`, system clock) so every existing
  /// positional-only call site (`StreakService(db, profileId: ...)`) is
  /// unaffected.
  /// [ref] replaces the former `UserDatabase db` positional argument:
  /// [StreakStateService] now resolves its Firestore repository through Riverpod
  /// rather than holding a Drift handle. `db` had no other use in this class.
  ///
  /// No `profileId` parameter: [StreakStateService.read]/`.watch`/
  /// `.streakCalendar` all resolve the active profile internally via `ref`
  /// (Firestore path is already profile-scoped) — a `profileId` field here
  /// was dead storage, never read by this class's own methods.
  StreakService(Ref ref, {StreakStateService? streakStateProvider})
    : _provider =
          streakStateProvider ??
          StreakStateService(ref: ref, clock: const SystemLocalDayClock());

  final StreakStateService _provider;

  /// Get streak recovery info.
  ///
  /// W3.20: `graceUsedDate` was specific to the dropped `streaks` table.
  /// The grace-period feature is not implemented post-W3.20; this always
  /// returns `wasRecovered: false`.
  Future<StreakRecoveryInfo> getRecoveryInfo() async {
    final state = await _provider.read();
    return StreakRecoveryInfo(
      wasRecovered: false,
      currentStreak: state.currentStreak,
    );
  }

  /// Returns the current [StreakState] for this profile.
  Future<StreakState> getStreak() => _provider.read();

  /// Reactive read — re-emits whenever streak_events changes.
  Stream<StreakState> watchStreak() => _provider.watch();

  /// Get a map of dates with learning activity within a date range,
  /// scoped to this profile.
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    // Delegates to the repository rather than walking raw events here.
    //
    // This used to enumerate `streak_events` itself via
    // `StreakStateService.readEvents`. That method no longer exists on the
    // Firestore path: `FirestoreStreakStateRepository` deliberately exposes no
    // raw-event accessor, and AD-23 forbids a domain service importing the
    // data-access ring to get one.
    //
    // `FirestoreStreakStateRepository.getStreakCalendar` is a line-for-line
    // reimplementation of the loop that was here — same local-day extraction,
    // same 'completion' event-type filter, same inclusive range — so this is a
    // relocation, not a reimplementation.
    return _provider.streakCalendar(startUtc: startUtc, endUtc: endUtc);
  }
}
