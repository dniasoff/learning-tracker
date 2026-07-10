import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/merge/bookmark_merger.dart';
import 'package:learning_tracker/core/sync/merge/completion_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/gamification_settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/goal_merger.dart';
import 'package:learning_tracker/core/sync/merge/learner_profile_merger.dart';
import 'package:learning_tracker/core/sync/merge/learning_ledger_merger.dart';
import 'package:learning_tracker/core/sync/merge/learning_order_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/merge/notification_settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/points_ledger_merger.dart';
import 'package:learning_tracker/core/sync/merge/profile_program_merger.dart';
import 'package:learning_tracker/core/sync/merge/reward_redemption_merger.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/streak_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/study_day_config_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';
import 'package:learning_tracker/core/sync/merge/tutor_grant_merger.dart';
import 'package:learning_tracker/core/sync/merge/ui_preferences_merger.dart';
import 'package:learning_tracker/features/sync/data/reward_settings_merge_delegate.dart';

/// Provider for [MergeRouter] — wires all [EntityMerger] implementations
/// with a concrete [DriftMergeStore] (DNI-334 AC4 + AC5).
///
/// [StreakEventMerger] uses [UserDatabase] directly (via [StreakEventLog])
/// rather than a [MergeStore]; all other mergers receive a [DriftMergeStore].
///
/// W2.27 additions: [GoalMerger], [LearningLedgerMerger],
/// [NotificationSettingsMerger], [GamificationSettingsMerger],
/// [UiPreferencesMerger]. These mergers bypass [DriftMergeStore] and access
/// [UserDatabase] or [SharedPreferences] directly.
///
/// Phase 3 of the sync architecture plan: [GamificationSettingsMerger]
/// receives its `reward_settings` sub-map callback via the
/// [rewardSettingsMergeDelegateProvider] (lives in `features/sync/data/`).
/// This keeps the merger in `core/sync/` while letting it call into
/// [RewardMilestoneService] (which lives in `features/gamification/`)
/// without a layering violation. Reward-milestone deltas pulled from the
/// cloud are now applied (the override never landed during W2.31; the
/// gap is closed here).
final mergeRouterProvider = Provider<MergeRouter>((ref) {
  final database = ref.watch(userDatabaseProvider);
  // W7.5: inject analytics so DriftMergeStore and ProfileProgramMerger can
  // fire merge_row_skipped events at every silent-skip site.
  final analytics = ref.watch(analyticsServiceProvider);
  final store = DriftMergeStore(database, analytics: analytics);

  // Phase 3: pull the reward-settings merge callback from the features-
  // layer provider. Keeping it as an injected callback (rather than a
  // direct import of RewardMilestoneService here) preserves the
  // core→features boundary at the call-site.
  final rewardSettingsMergeDelegate = ref.watch(
    rewardSettingsMergeDelegateProvider,
  );

  return MergeRouter(
    mergers: <String, EntityMerger>{
      EntityKind.completion: CompletionEventMerger(store: store),
      EntityKind.streak: StreakEventMerger(database),
      EntityKind.learnerProfile: LearnerProfileMerger(
        store: store,
        logger: ref.watch(appLoggerProvider),
      ),
      EntityKind.trackConfig: TrackConfigMerger(store: store),
      EntityKind.bookmark: BookmarkMerger(store: store),
      EntityKind.settings: SettingsMerger(store: store),
      EntityKind.stageDefinition: StageDefinitionMerger(store: store),
      // W7.5: ProfileProgramMerger also gets analytics for its skip site.
      EntityKind.profileProgram: ProfileProgramMerger(
        store: store,
        analytics: analytics,
      ),
      EntityKind.learningOrder: LearningOrderMerger(store: store), // W2.26
      // W2.27 — closes M1
      EntityKind.goal: GoalMerger(database, store: store),
      EntityKind.learningLedger: LearningLedgerMerger(database),
      EntityKind.notificationSettings: NotificationSettingsMerger(store: store),
      EntityKind.gamificationSettings: GamificationSettingsMerger(
        db: database,
        store: store,
        // Phase 3: reward-milestones delegate now wired from
        // features/sync/data/reward_settings_merge_delegate.dart.
        onRewardSettings: rewardSettingsMergeDelegate,
      ),
      EntityKind.uiPreferences: UiPreferencesMerger(store: store),
      EntityKind.tutorGrant: const TutorGrantMerger(), // W3.17 / W3.38
      // Phase 1 — study-day config enrolment in the sync pipeline.
      // AUD-core-sync-03: LWW ordering now goes through DriftMergeStore
      // (±5 s clock-skew window + synced_at tie-break) like every other
      // natural-key merger; the FK-existence guard against curriculum_tracks
      // stays inline since no store helper covers that composite-PK check.
      EntityKind.studyDayConfig: StudyDayConfigMerger(database, store: store),
      // WS9 Wave-B (C#2) — points spend economy. Both bypass DriftMergeStore
      // and talk to PointsBalanceDao directly (append-only ledger + LWW
      // redemption state-machine + local balance re-derivation).
      EntityKind.pointsLedger: PointsLedgerMerger(database),
      EntityKind.rewardRedemption: RewardRedemptionMerger(database),
    },
  );
});
