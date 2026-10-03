import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// AUD-gamification-11 (SM-7): the DI seam for [RewardMilestoneService] —
/// mirroring the existing,
/// correct `pointsServiceProvider` pattern in `points_providers.dart`.
///
/// Before this file existed, every call site independently constructed
/// `RewardMilestoneService(db, profileId: profileId)` /
/// `StreakService(db, profileId: profileId)` / `StreakStateService(db: db,
/// clock: ...)` ad hoc from `UserDatabase` + `activeProfileIdProvider`
/// (9 sites inside `features/gamification/` alone, plus
/// `features/dashboard/`). A constructor change, a store swap, or a test
/// wanting to fake one of these services all had to touch every call site
/// individually, and a test could only fake the service by injecting a fake
/// `UserDatabase` all the way through — never by a single `ProviderScope`
/// override. Construction now lives in this provider; every other call site
/// reads it via `ref.watch`/`ref.read`.
///
/// DNI-479 (R6): the profile-wide `StreakStateService`/`StreakService` seams
/// are retired with `streak_events`; the streak is the per-curriculum
/// `LearnerState` streak (AD-40).

/// Provider for [RewardMilestoneService], scoped to the active profile.
final rewardMilestoneServiceProvider = Provider<RewardMilestoneService>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  final points = EnginePointsReader(ref: ref);
  return RewardMilestoneService(
    balanceReader: points,
    lifetimeEarnedReader: points,
    profileId: profileId ?? '',
  );
});
