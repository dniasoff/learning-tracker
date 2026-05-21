/// Features-layer wiring for [GamificationSettingsMerger]'s reward-settings
/// callback (Phase 3 of the sync architecture plan).
///
/// Background: [GamificationSettingsMerger] lives in `core/sync/merge/`. The
/// reward-milestone state lives in [RewardMilestoneService] which is in
/// `features/gamification/`. Importing the service from core would cross the
/// `core → features` boundary, so the merger takes a callback typedef
/// (`RewardSettingsMergeDelegate`) and the actual wiring is provided here.
///
/// The merge router provider reads [rewardSettingsMergeDelegateProvider] and
/// forwards the delegate to the gamification merger at build time.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/merge/gamification_settings_merger.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';

/// Build a [RewardSettingsMergeDelegate] that hands the remote
/// `reward_settings` sub-map to [RewardMilestoneService.mergeCloudPayload]
/// for the active profile.
///
/// Returns `null` for an empty `reward_settings` block (treats it as a
/// no-op so the merger still updates its LWW timestamp). The service's
/// own LWW check guards against older payloads from being applied — the
/// merger has already won the LWW race at the parent
/// `gamification_settings` document level, but applying the sub-map again
/// is harmless because [RewardMilestoneService.mergeCloudPayload] is
/// idempotent.
final rewardSettingsMergeDelegateProvider =
    Provider<RewardSettingsMergeDelegate>((ref) {
      final db = ref.watch(userDatabaseProvider);
      return (Map<String, dynamic>? remote, int profileId) async {
        if (remote == null) return;
        final service = RewardMilestoneService(db, profileId: profileId);
        await service.mergeCloudPayload(remote);
      };
    });
