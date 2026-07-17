import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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
  StreakService(
    UserDatabase db, {
    int profileId = 0,
    StreakStateService? streakStateProvider,
  }) : _profileId = profileId,
       _provider =
           streakStateProvider ??
           StreakStateService(db: db, clock: const SystemLocalDayClock());

  final int _profileId;
  final StreakStateService _provider;

  /// Get streak recovery info.
  ///
  /// W3.20: `graceUsedDate` was specific to the dropped `streaks` table.
  /// The grace-period feature is not implemented post-W3.20; this always
  /// returns `wasRecovered: false`.
  Future<StreakRecoveryInfo> getRecoveryInfo() async {
    final state = await _provider.read(profileId: _profileId);
    return StreakRecoveryInfo(
      wasRecovered: false,
      currentStreak: state.currentStreak,
    );
  }

  /// Returns the current [StreakState] for this profile.
  Future<StreakState> getStreak() => _provider.read(profileId: _profileId);

  /// Reactive read — re-emits whenever streak_events changes.
  Stream<StreakState> watchStreak() => _provider.watch(profileId: _profileId);

  /// Get a map of dates with learning activity within a date range,
  /// scoped to this profile.
  Future<Set<DateTime>> getStreakCalendar({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    // Read completion dates from completions_view (via completionDao).
    // StreakService injects UserDatabase so we can read directly.
    // This path is kept for calendar widgets that show activity dots.
    final state = await _provider.read(profileId: _profileId);
    final lastDay = state.lastCompletionDayLocal;
    if (lastDay == null) return {};

    // Build the set of active UTC days from streak_events.
    // (completionDao.getCompletionsByProfile would work too, but reading
    // streak_events avoids a join and the view overhead.)
    final activeDates = <DateTime>{};
    final startLocal = LocalDayUtils.extractLocalDate(startUtc);
    final endLocal = LocalDayUtils.extractLocalDate(endUtc);

    // Re-read events directly to enumerate per-day activity.
    final events = await _provider.readEvents(profileId: _profileId);
    for (final event in events) {
      if (event.eventType != 'completion') continue;
      final localDate = LocalDayUtils.extractLocalDate(event.eventTimestamp);
      if (!localDate.isBefore(startLocal) && !localDate.isAfter(endLocal)) {
        activeDates.add(localDate);
      }
    }
    return activeDates;
  }
}
