import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// AUD-gamification-11 (SM-7): DI seams for [RewardMilestoneService],
/// [StreakStateService] and [StreakService] — mirroring the existing,
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
/// override. Construction now lives in exactly these three providers; every
/// other call site reads them via `ref.watch`/`ref.read`.

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
