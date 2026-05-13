import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/learning/completion_writer_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
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

CurriculumId? _curriculumForStorageKey(String key) {
  for (final c in CurriculumId.values) {
    if (c.storageKey == key) return c;
  }
  return null;
}

String _trackLabelEn(CurriculumId? c, String rawKey) {
  if (c != null) return curriculumEnglishName(c);
  return rawKey;
}

final achievementsOverviewProvider = FutureProvider<AchievementsOverview>((
  ref,
) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final service = RewardMilestoneService(db, profileId: profileId);

  if (await service.stripStockTemplateMilestones()) {
    await ref.read(syncEngineProvider)?.pushGamificationSettingsSnapshot();
  }

  final tracks = await db.trackDao.getActiveTracksForProfile(profileId);
  final rewardTracks = <CurriculumTrack>[];
  for (final track in tracks) {
    if (await service.trackCountsTowardRewardPoints(track.id)) {
      rewardTracks.add(track);
    }
  }

  for (final track in rewardTracks) {
    await service.evaluateUnlocksForTrack(track.id);
  }
  await service.evaluateUnlocksForGlobal();

  final unlocks = await service.getAllUnlocks();
  final unlockedIds = unlocks.map((u) => u.milestoneId).toSet();

  final rows = <AchievementRowVm>[];
  final filterOptions = <AchievementTrackFilterVm>[];

  for (final track in rewardTracks) {
    final curriculum = _curriculumForStorageKey(track.curriculumId);
    final label = _trackLabelEn(curriculum, track.curriculumId);

    final milestones = await service.getMilestonesForTrack(track.id);
    final enabled = milestones.where((m) => m.isEnabled).toList()
      ..sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));

    if (enabled.isEmpty) continue;

    filterOptions.add(
      AchievementTrackFilterVm(
        trackId: track.id,
        curriculumId: curriculum,
        sortLabel: label,
      ),
    );

    final trackPoints = await service.getTrackPointsTotalForRewards(track.id);

    RewardMilestone? firstLocked;
    for (final m in enabled) {
      if (!unlockedIds.contains(m.id)) {
        firstLocked = m;
        break;
      }
    }

    for (final m in enabled) {
      final unlocked = unlockedIds.contains(m.id);
      final isNext = !unlocked && firstLocked?.id == m.id;
      rows.add(
        AchievementRowVm(
          trackId: track.id,
          trackLabel: label,
          curriculumId: curriculum,
          milestone: m,
          trackPoints: trackPoints,
          isUnlocked: unlocked,
          isNextUp: isNext,
          isLegendTier: m.title.trim() == 'Legend Star',
        ),
      );
    }
  }

  final globalMilestones = await service.getGlobalMilestones();
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

    final globalPoints = await service.getGlobalPointsForRewards();
    RewardMilestone? firstLockedGlobal;
    for (final m in enabledGlobal) {
      if (!unlockedIds.contains(m.id)) {
        firstLockedGlobal = m;
        break;
      }
    }

    for (final m in enabledGlobal) {
      final unlocked = unlockedIds.contains(m.id);
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
