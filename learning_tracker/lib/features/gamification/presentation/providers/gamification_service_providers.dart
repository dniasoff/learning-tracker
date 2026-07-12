import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// AUD-gamification-11 (SM-7): DI seams for [RewardMilestoneService],
/// [StreakStateProvider] and [StreakService] — mirroring the existing,
/// correct `pointsServiceProvider` pattern in `points_providers.dart`.
///
/// Before this file existed, every call site independently constructed
/// `RewardMilestoneService(db, profileId: profileId)` /
/// `StreakService(db, profileId: profileId)` / `StreakStateProvider(db: db,
/// clock: ...)` ad hoc from `UserDatabase` + `activeProfileIdProvider`
/// (9 sites inside `features/gamification/` alone, plus
/// `features/dashboard/`). A constructor change, a store swap, or a test
/// wanting to fake one of these services all had to touch every call site
/// individually, and a test could only fake the service by injecting a fake
/// `UserDatabase` all the way through — never by a single `ProviderScope`
/// override. Construction now lives in exactly these three providers; every
/// other call site reads them via `ref.watch`/`ref.read`.

/// Provider for [RewardMilestoneService], scoped to the active profile.
final rewardMilestoneServiceProvider = Provider<RewardMilestoneService>((ref) {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return RewardMilestoneService(database, profileId: profileId);
});

/// Provider for [StreakStateProvider].
///
/// Not profile-scoped at construction — [StreakStateProvider.read] and
/// `.watch` both take `profileId` per call — so a single instance (bound to
/// the active database + the real system clock) is shared by every reader.
final streakStateProvider = Provider<StreakStateProvider>((ref) {
  final database = ref.watch(userDatabaseProvider);
  return StreakStateProvider(db: database, clock: const SystemLocalDayClock());
});

/// Provider for [StreakService], scoped to the active profile.
final streakServiceProvider = Provider<StreakService>((ref) {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return StreakService(
    database,
    profileId: profileId,
    streakStateProvider: ref.watch(streakStateProvider),
  );
});
