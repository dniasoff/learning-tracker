import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
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
import 'package:learning_tracker/core/sync/merge/profile_program_merger.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/streak_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/study_day_config_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';
import 'package:learning_tracker/core/sync/merge/tutor_grant_merger.dart';
import 'package:learning_tracker/core/sync/merge/ui_preferences_merger.dart';

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
/// Note: [GamificationSettingsMerger] is wired with `onRewardSettings: null`
/// here because [RewardMilestoneService] lives in `features/gamification/` and
/// importing it from `core/` would violate the layering rule. The reward-
/// milestones delegate is supplied by an override in `features/sync/` once
/// W2.31 moves this wiring to the features layer.
final mergeRouterProvider = Provider<MergeRouter>((ref) {
  final database = ref.watch(userDatabaseProvider);
  // W7.5: inject analytics so DriftMergeStore and ProfileProgramMerger can
  // fire merge_row_skipped events at every silent-skip site.
  final analytics = ref.watch(analyticsServiceProvider);
  final store = DriftMergeStore(database, analytics: analytics);

  return MergeRouter(
    mergers: <String, EntityMerger>{
      EntityKind.completion: CompletionEventMerger(store: store),
      EntityKind.streak: StreakEventMerger(database),
      EntityKind.learnerProfile: LearnerProfileMerger(store: store),
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
      EntityKind.goal: GoalMerger(database),
      EntityKind.learningLedger: LearningLedgerMerger(database),
      EntityKind.notificationSettings: const NotificationSettingsMerger(),
      EntityKind.gamificationSettings: GamificationSettingsMerger(
        db: database,
        // Reward-milestones delegate wired from features/sync/ in W2.31.
        onRewardSettings: null,
      ),
      EntityKind.uiPreferences: const UiPreferencesMerger(),
      EntityKind.tutorGrant: const TutorGrantMerger(), // W3.17 / W3.38
      // Phase 1 — study-day config enrolment in the sync pipeline. Bypasses
      // DriftMergeStore because StudyDayConfigs has a composite PK with a
      // foreign-key to curriculum_tracks (no compatible store helpers yet).
      EntityKind.studyDayConfig: StudyDayConfigMerger(database),
    },
  );
});
