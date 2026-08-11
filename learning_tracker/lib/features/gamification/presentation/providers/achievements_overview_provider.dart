import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/gamification_service_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// One milestone row for the achievements list (per track).
class AchievementRowVm {
  const AchievementRowVm({
    required this.trackId,
    required this.trackLabel,
    required this.curriculumId,
    required this.milestone,
    required this.trackPoints,
    required this.isUnlocked,
    required this.isNextUp,
    required this.isLegendTier,
  });

  final int trackId;
  final String trackLabel;
  final CurriculumId? curriculumId;
  final RewardMilestone milestone;
  final int trackPoints;
  final bool isUnlocked;

  /// First locked milestone on this track (by threshold order).
  final bool isNextUp;

  final bool isLegendTier;
}

/// Data for the achievements screen header and list.
class AchievementsOverview {
  const AchievementsOverview({
    required this.rows,
    required this.unlockedCount,
    required this.totalMilestones,
    required this.trackFilterOptions,
  });

  final List<AchievementRowVm> rows;
  final int unlockedCount;
  final int totalMilestones;

  /// Active tracks for the filter strip (label resolved in UI via locale).
  final List<AchievementTrackFilterVm> trackFilterOptions;
}

class AchievementTrackFilterVm {
  const AchievementTrackFilterVm({
    required this.trackId,
    required this.curriculumId,
    required this.sortLabel,
  });

  final int trackId;
  final CurriculumId? curriculumId;

  /// English name for stable sort order.
  final String sortLabel;
}

/// SM-2 (AUD-gamification-03): a pure read of the achievements overview.
/// Stripping legacy stock-template milestones + pushing the resulting
/// snapshot used to happen inline here as a side effect of simply watching
/// this provider (on every rebuild, e.g. every [completionCommittedProvider]
/// tick) -- that write/sync-push now lives exclusively in
/// [GamificationMaintenanceController.stripStockTemplateMilestonesIfNeeded],
/// invoked explicitly once from `GamificationScreen`'s `initState`.
final achievementsOverviewProvider =
    FutureProvider.autoDispose<AchievementsOverview>((ref) async {
      ref.watch<int>(completionCommittedProvider);
      final service = ref.watch(rewardMilestoneServiceProvider);

      // R4o-C1 / DEC-32/GA-3: the auto-unlock achievement ladder was replaced
      // by the spend economy, and per-track rewards were removed from it
      // entirely — every reward is a single global priced spend-item now, so
      // there is no per-track loop left to run (see
      // reward_config_controller.dart's doc comment for the fuller product
      // history). A reward is "unlocked" (affordable / achievable) when the
      // relevant points total has reached or crossed its threshold.
      // Classification is derived purely from threshold <= points — no
      // historical unlock records are consulted.
      final rows = <AchievementRowVm>[];
      final filterOptions = <AchievementTrackFilterVm>[];

      final globalMilestones = await service.getMilestones();
      final enabledGlobal = globalMilestones.where((m) => m.isEnabled).toList()
        ..sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));

      if (enabledGlobal.isNotEmpty) {
        filterOptions.insert(
          0,
          const AchievementTrackFilterVm(
            trackId: RewardMilestone.kGlobalTrackSentinel,
            curriculumId: null,
            sortLabel: '',
          ),
        );

        // R-GA2 is NOT fully honored here: the "lifetime-earned, never
        // decremented" total it calls for (so a milestone stays unlocked
        // after a redemption debits the spendable balance) had no working
        // implementation even before this Firestore rewrite —
        // `getGlobalLifetimeEarnedForRewards` was already a deprecated stub
        // returning 0 unconditionally, which made every milestone show as
        // permanently locked. Using the current spendable balance instead is
        // a real behavior change (a redemption CAN now re-lock a milestone),
        // but it replaces an always-locked screen with a correct one for the
        // common case. True lifetime-earned tracking needs its own
        // monotonic ledger view — tracked separately, not rebuilt here.
        final globalPoints = await service.getGlobalPointsForRewards();
        RewardMilestone? firstLockedGlobal;
        for (final m in enabledGlobal) {
          if (globalPoints < m.thresholdPoints) {
            firstLockedGlobal = m;
            break;
          }
        }

        for (final m in enabledGlobal) {
          final unlocked = globalPoints >= m.thresholdPoints;
          final isNext = !unlocked && firstLockedGlobal?.id == m.id;
          rows.add(
            AchievementRowVm(
              trackId: RewardMilestone.kGlobalTrackSentinel,
              trackLabel: '',
              curriculumId: null,
              milestone: m,
              trackPoints: globalPoints,
              isUnlocked: unlocked,
              isNextUp: isNext,
              isLegendTier: false,
            ),
          );
        }
      }

      filterOptions.sort((a, b) => a.sortLabel.compareTo(b.sortLabel));

      final unlockedCount = rows.where((r) => r.isUnlocked).length;

      return AchievementsOverview(
        rows: rows,
        unlockedCount: unlockedCount,
        totalMilestones: rows.length,
        trackFilterOptions: filterOptions,
      );
    });

// ─── Maintenance action (AUD-gamification-03) ──────────────────────────────

/// One-shot, idempotent action that strips legacy stock-template milestones
/// (a no-op after the first run that actually finds something to strip) and
/// pushes the updated snapshot if anything changed.
///
/// SM-2: this is the ONLY place [achievementsOverviewProvider]'s former
/// inline strip-and-push side effect now happens. Must be invoked explicitly
/// (see `GamificationScreen`'s `initState`) -- never as a side effect of
/// watching a read provider.
class GamificationMaintenanceController extends Notifier<void> {
  @override
  void build() {}

  Future<void> stripStockTemplateMilestonesIfNeeded() async {
    final service = ref.read(rewardMilestoneServiceProvider);
    final changed = await service.stripStockTemplateMilestones();
    if (!changed) return;
    // SM-4: the screen that triggered this can be disposed while the
    // strip write above / the awaits below are in flight.
    if (!ref.mounted) return;
    await ref.read(syncWriteFacadeProvider)?.pushGamificationSettingsSnapshot();
    if (!ref.mounted) return;
    ref.invalidate(achievementsOverviewProvider);
  }
}

final gamificationMaintenanceControllerProvider =
    NotifierProvider<GamificationMaintenanceController, void>(
      GamificationMaintenanceController.new,
    );
