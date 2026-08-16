/// Shared override/stub/navigation helpers for `test/e2e/journeys/*.dart`.
///
/// AUD-t-cross-21: `_sacredWindowNullOverride`, `_connectivityOnline(Override)`
/// (a.k.a. `_connectivityOnlineOverride`/`_connectivitySilenceOverride`),
/// `_incomingGrantsEmpty(Override)` (a.k.a. `_incomingGrantsEmptyOverride`),
/// `_pendingInvitesEmpty(Override)` (a.k.a. `_pendingInvitesEmptyOverride`),
/// `_stubTrack`, `_navigateTo`, `_dashboardActiveTracksOverrides`,
/// `_activeTracksOneShotOverride`, and `_pendingRedemptionsOneShotOverride`
/// used to be copy-pasted as private top-level functions across a dozen-plus
/// journey files (with naming drift on several of them). They now live once,
/// here — import the ones a journey file needs instead of redefining them.
library;

import 'dart:async' show unawaited;

import 'package:auto_route/auto_route.dart' show PageRouteInfo;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_points_balance_reader_adapter.dart';
import 'package:learning_tracker/features/gamification/data/repositories/reward_redemption_repository_impl.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart'
    show childRedemptionBalanceProvider;
import 'package:learning_tracker/features/gamification/presentation/screens/parent_pending_redemptions_screen.dart'
    show pendingRedemptionsProvider;
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart'
    show activeTracksProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';

import 'e2e_harness.dart';

// ── Sacred-window / connectivity / tutor-grant silence overrides ───────────────

/// Overrides [currentSacredWindowProvider] to return null (no sacred window
/// active), bypassing the `CurrentSacredWindow` notifier's `build()`, which
/// schedules a 30-second repeating timer. Without this, tests that navigate
/// to Settings (which mounts `SacredTimeSettingsCard`/`SacredTimeLockOverlay`)
/// leave the timer pending after `h.dispose()`, tripping the
/// `_verifyInvariants` `!timersPending` assertion.
Override sacredWindowNullOverride() =>
    currentSacredWindowProvider.overrideWithValue(null);

/// Overrides [connectivityStreamProvider] with a static "online" stream so
/// the connectivity plugin's debounce timer and recovery-probe
/// `Timer.periodic` are never created. Without this, tests that pump for
/// >0ms may hit the connectivity channel's `MissingPluginException`, and any
/// pending timers trip the `_verifyInvariants` assertion after `h.dispose()`.
Override connectivityOnlineOverride() =>
    connectivityStreamProvider.overrideWith((ref) => Stream.value(true));

/// Overrides [incomingTutorGrantsProvider] (from `manage_tutors_providers`)
/// with an empty list — avoids Cloud Function calls in headless tests.
/// `_PendingInvitesSection` (ProfilePickerScreen, SettingsScreen) watches
/// this provider.
Override incomingGrantsEmptyOverride() =>
    incomingTutorGrantsProvider.overrideWith((ref) => Future.value([]));

/// Overrides [pendingTutorInvitesProvider] (from `tutor_grant_providers`)
/// with an empty list — avoids Cloud Function calls in headless tests.
/// `_PendingInvitesSection` (ProfilePickerScreen, SettingsScreen) watches
/// this provider.
Override pendingInvitesEmptyOverride() =>
    pendingTutorInvitesProvider.overrideWith((ref) => Future.value([]));

// ── Track stub / navigation ─────────────────────────────────────────────────

/// Builds an in-memory (never persisted) active [CurriculumTrackEntity] for
/// tests that only need a valid track object to feed into an override —
/// not an actual seeded Firestore document. The legacy identity arguments are
/// retained until journey helpers are migrated to document-shaped fixtures.
CurriculumTrackEntity stubTrack({
  required int id,
  required Object profileId,
  CurriculumId curriculum = CurriculumId.mishnayos,
  DateTime? activatedAt,
}) {
  final now = activatedAt ?? DateTimeFactory.nowUtc();
  return CurriculumTrackEntity(
    curriculumId: curriculum,
    state: 'active',
    stateChangedAt: now,
    activatedAt: now,
  );
}

/// Navigates to [route] by fire-and-forget router push + frame pumps so the
/// async guard chain can complete.
Future<void> navigateTo(E2EHarness h, PageRouteInfo route) async {
  unawaited(h.router.push(route));
  await h.pump();
  await h.pump(const Duration(milliseconds: 500));
  await h.pump();
}

// ── Dashboard active-tracks override ────────────────────────────────────────

/// Zero-valued [LifetimeTotals] default for [dashboardActiveTracksOverrides].
const zeroLifetimeTotals = LifetimeTotals(
  learnedSections: 0,
  totalSections: 0,
  totalCurricula: 9,
);

/// Silence overrides for tests that land on `/dashboard` and need to control
/// exactly which tracks/tasks are "active", replacing
/// [dashboardActiveTracksStreamProvider] with [tracks] and
/// [allDailyTasksProvider] with [tasks].
///
/// Do NOT combine with [E2EHarness.dashboardSilenceOverrides] — that already
/// overrides `dashboardActiveTracksStreamProvider` with an empty list, which
/// would create a duplicate override (Riverpod assertion error). This
/// function reproduces the rest of `dashboardSilenceOverrides` manually
/// (curricula/streak/streak-recovery) alongside the caller-supplied track
/// stream.
List<Override> dashboardActiveTracksOverrides(
  E2EHarness h, {
  required List<CurriculumTrackEntity> tracks,
  required List<DailyTask> tasks,
  LifetimeTotals totals = zeroLifetimeTotals,
}) {
  return [
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(<CurriculumId>[]),
    ),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
    ),
    dashboardStreakRecoveryProvider.overrideWith(
      (ref) => Future.value(
        const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
      ),
    ),
    dashboardActiveTracksStreamProvider.overrideWith(
      (ref) => Stream.value(tracks),
    ),
    allDailyTasksProvider.overrideWith((ref) => Future.value(tasks)),
    lifetimeTotalsAcrossAllCurriculaProvider.overrideWith(
      (ref) => Future.value(totals),
    ),
    lifetimeSummariesProvider.overrideWith((ref) => Future.value([])),
    trackDualProgressMetricsProvider.overrideWith((ref) => Future.value([])),
  ];
}

// ── Firestore-backed compatibility overrides ───────────────────────────────

/// Retained for compatibility; the Drift-specific cleanup-timer bug no longer
/// applies because [activeTracksProvider] is Firestore-backed.
Override activeTracksOneShotOverride() {
  return activeTracksProvider.overrideWith((ref) {
    final adapter = FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
    return Stream.fromFuture(adapter.getActiveTracks());
  });
}

/// Retained for compatibility; the Drift-specific cleanup-timer bug no longer
/// applies because [pendingRedemptionsProvider] is Firestore-backed.
Override pendingRedemptionsOneShotOverride() {
  return pendingRedemptionsProvider.overrideWith((ref) {
    final adapter = FirestoreRewardRedemptionRepositoryAdapter(ref: ref);
    return Stream.fromFuture(adapter.watchPendingRedemptions().first);
  });
}

/// Retained for compatibility; the Drift-specific cleanup-timer bug no longer
/// applies because [childRedemptionBalanceProvider] is Firestore-backed.
Override childRedemptionBalanceOneShotOverride() {
  return childRedemptionBalanceProvider.overrideWith((ref) {
    final adapter = FirestorePointsBalanceReaderAdapter(ref: ref);
    return adapter.getBalance();
  });
}
