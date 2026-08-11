import 'dart:convert';
import 'dart:math';

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local reward milestone configuration + unlock tracking.
///
/// Stored in SharedPreferences (profile-scoped), while points totals are
/// derived from completions via [PointsService] for offline-first consistency.
class RewardMilestoneService {
  RewardMilestoneService({
    required this.eligibility,
    required this.balanceReader,
    required this.profileId,
  });

  final CurriculumRewardEligibility eligibility;
  final PointsBalanceReader balanceReader;
  final int profileId;

  static const _configKeyPrefix = 'reward_milestones_config_v1_';
  static const _unlockKeyPrefix = 'reward_milestones_unlocks_v1_';
  static const _updatedAtMsKeyPrefix = 'reward_milestones_updated_at_ms_';

  String get _configKey => '$_configKeyPrefix$profileId';
  String get _unlockKey => '$_unlockKeyPrefix$profileId';
  String get _updatedAtMsKey => '$_updatedAtMsKeyPrefix$profileId';

  Future<List<RewardMilestone>> getMilestonesForTrack(int trackId) async {
    final all = await getAllMilestones();
    final trackMilestones = all.where((m) => m.trackId == trackId).toList();
    trackMilestones.sort(
      (a, b) => a.thresholdPoints.compareTo(b.thresholdPoints),
    );
    return trackMilestones;
  }

  /// Milestones tied to [RewardMilestone.kGlobalTrackSentinel] (total points).
  Future<List<RewardMilestone>> getGlobalMilestones() async {
    return getMilestonesForTrack(RewardMilestone.kGlobalTrackSentinel);
  }

  /// Current debitable balance for reward display (WS7.balance).
  ///
  /// Reads from [PointsBalanceReader] — the spend-economy source of truth (DEC-32).
  Future<int> getGlobalPointsForRewards() async {
    return balanceReader.getBalance();
  }

  /// Lifetime completion-derived points total across all reward-eligible curricula.
  ///
  /// R-GA2: global milestone unlock classification must use lifetime-earned, not
  /// the debitable balance. Using the debitable balance causes a milestone that
  /// was earned (threshold crossed) to flip back to LOCKED after a redemption
  /// debit reduces the balance below the threshold — i.e. spending points
  /// re-locks an achievement the child already unlocked.
  ///
  /// This method is no longer directly computable here since completions are
  /// curriculum-keyed, not track-keyed. The equivalent logic lives in
  /// [PointsService.getDerivedTotal] which accepts a completions list.
  @Deprecated('Use PointsService.getDerivedTotal with completions from the repository')
  Future<int> getGlobalLifetimeEarnedForRewards() async {
    // This method cannot be implemented without access to completions data.
    // The logic has moved to PointsService which accepts completions as input.
    // Callers should use PointsService.getDerivedTotal(completions) instead.
    return 0;
  }

  Future<List<RewardMilestone>> getAllMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .where((e) => e is Map)
          .map(
            (e) =>
                (e as Map).map((key, value) => MapEntry(key.toString(), value)),
          )
          .map(RewardMilestone.fromJson)
          .where((m) => m.profileId == profileId)
          .toList();
    } catch (e, st) {
      // AUD-gamification-06: a corrupt/unreadable config must not be
      // indistinguishable from "genuinely empty" -- this empty fallback
      // flows straight into exportCloudPayload() and can overwrite every
      // other synced device's real reward list with silence as to why.
      AppLogger.instance.error(
        event: 'reward_milestone_service getAllMilestones decode failed',
        fields: {'profileId': profileId, 'key': _configKey},
        exception: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  Future<List<RewardUnlockRecord>> getAllUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_unlockKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .where((e) => e is Map)
          .map(
            (e) =>
                (e as Map).map((key, value) => MapEntry(key.toString(), value)),
          )
          .map(RewardUnlockRecord.fromJson)
          .where((u) => u.profileId == profileId)
          .toList()
        ..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    } catch (e, st) {
      // AUD-gamification-06: see getAllMilestones's catch above.
      AppLogger.instance.error(
        event: 'reward_milestone_service getAllUnlocks decode failed',
        fields: {'profileId': profileId, 'key': _unlockKey},
        exception: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  Future<void> upsertMilestone({
    required int trackId,
    required String title,
    required int thresholdPoints,
    String? milestoneId,
    bool isEnabled = true,
    int iconIndex = 0,
  }) async {
    assert(
      trackId >= 0,
      'Use RewardMilestone.kGlobalTrackSentinel for total-points rewards.',
    );
    final now = DateTimeFactory.nowUtc();
    final all = List<RewardMilestone>.from(await getAllMilestones());

    final existingIndex = milestoneId == null
        ? -1
        : all.indexWhere(
            (m) => m.id == milestoneId && m.profileId == profileId,
          );

    if (existingIndex >= 0) {
      all[existingIndex] = all[existingIndex].copyWith(
        title: title.trim(),
        thresholdPoints: thresholdPoints,
        isEnabled: isEnabled,
        iconIndex: iconIndex,
        updatedAt: now,
      );
    } else {
      all.add(
        RewardMilestone(
          id: milestoneId ?? _newMilestoneId(),
          profileId: profileId,
          trackId: trackId,
          title: title.trim(),
          thresholdPoints: thresholdPoints,
          isEnabled: isEnabled,
          createdAt: now,
          updatedAt: now,
          iconIndex: iconIndex,
        ),
      );
    }

    await _writeMilestones(all, updatedAt: now);
  }

  /// Removes auto-generated template milestones (historical default ladder and
  /// legacy 50/150/300 tiers) so only parent-configured rewards remain.
  ///
  /// Returns `true` if any milestone or unlock row was removed.
  Future<bool> stripStockTemplateMilestones() async {
    final all = List<RewardMilestone>.from(await getAllMilestones());
    if (all.isEmpty) return false;

    final removeIds = <String>{};

    for (final m in all) {
      if (_matchesStockDefaultLadderEntry(m)) {
        removeIds.add(m.id);
      }
    }

    final byTrack = <int, List<RewardMilestone>>{};
    for (final m in all) {
      byTrack.putIfAbsent(m.trackId, () => []).add(m);
    }
    for (final list in byTrack.values) {
      if (list.length != 3) continue;
      final th = list.map((e) => e.thresholdPoints).toList()..sort();
      if (th[0] == 50 && th[1] == 150 && th[2] == 300) {
        for (final m in list) {
          removeIds.add(m.id);
        }
      }
    }

    if (removeIds.isEmpty) return false;

    final kept = all.where((m) => !removeIds.contains(m.id)).toList();
    final now = DateTimeFactory.nowUtc();
    await _writeMilestones(kept, updatedAt: now);

    final unlocks = await getAllUnlocks();
    final keptUnlocks = unlocks
        .where((u) => !removeIds.contains(u.milestoneId))
        .toList();
    await _writeUnlocks(keptUnlocks, updatedAt: now);
    return true;
  }

  static bool _matchesStockDefaultLadderEntry(RewardMilestone m) {
    final title = m.title.trim();
    for (final tier in defaultMilestoneLadder) {
      if (title == tier.title && m.thresholdPoints == tier.thresholdPoints) {
        return true;
      }
    }
    return false;
  }

  Future<void> removeMilestone(String milestoneId) async {
    final now = DateTimeFactory.nowUtc();
    final all = await getAllMilestones();
    final filtered = all.where((m) => m.id != milestoneId).toList();
    await _writeMilestones(filtered, updatedAt: now);
  }

  /// Historical auto-generated ladder (exact title + threshold) removed by
  /// [stripStockTemplateMilestones].
  static const List<({String title, int thresholdPoints})>
  defaultMilestoneLadder = [
    (title: 'Bronze Star', thresholdPoints: 500),
    (title: 'Silver Star', thresholdPoints: 1000),
    (title: 'Gold Star', thresholdPoints: 3000),
    (title: 'Platinum Star', thresholdPoints: 5000),
    (title: 'Premium Star', thresholdPoints: 10000),
    (title: 'Diamond Star', thresholdPoints: 15000),
    (title: 'Elite Star', thresholdPoints: 25000),
    (title: 'Legend Star', thresholdPoints: 50000),
  ];

  /// No-op: template ladders are not seeded; parents configure rewards explicitly.
  Future<void> ensureDefaultsForTrack(int trackId) async {
    if (trackId == RewardMilestone.kGlobalTrackSentinel) return;
  }

  /// True when this curriculum is a **programmed** (yeshiva cycle) or **self-paced**
  /// (has a learning goal) curriculum. Momentum-only "browse" curricula — and lifetime
  /// learning (ledger only, no completions) — do not count toward reward points.
  ///
  /// Replaces the old trackId-keyed [trackCountsTowardRewardPoints] (AD-25).
  /// Eligibility is now CURRICULUM-keyed via the injected [CurriculumRewardEligibility].
  Future<bool> curriculumCountsTowardRewardPoints(CurriculumId curriculumId) async {
    return eligibility.isEligible(curriculumId);
  }

  /// @deprecated Use [curriculumCountsTowardRewardPoints] instead.
  /// Kept for backward compatibility with callers that still have a trackId.
  /// Resolves the track's curriculumId and delegates to the curriculum-based check.
  @Deprecated('Use curriculumCountsTowardRewardPoints with CurriculumId')
  Future<bool> trackCountsTowardRewardPoints(int trackId) async {
    // THROWS rather than returning false.
    //
    // Returning `false` here would silently mark every track ineligible for
    // reward points — indistinguishable from a legitimate "not eligible", so no
    // gate, log or test could ever see it. A migration that is not finished
    // must fail loudly at the point of use, not answer plausibly.
    throw UnsupportedError(
      'trackCountsTowardRewardPoints is not available on the Firestore path: '
      'trackId cannot be resolved to a curriculum without the deleted trackDao. '
      'Call curriculumCountsTowardRewardPoints(CurriculumId) instead.',
    );
  }

  /// @deprecated Track-based points queries are no longer supported (AD-25).
  /// Points are now curriculum-keyed. Use [PointsService.getCurriculumTotal] instead.
  @Deprecated('Use PointsService.getCurriculumTotal with CurriculumId')
  Future<int> getTrackPointsTotal(int trackId) async {
    // THROWS rather than returning 0.
    //
    // `getTrackPointsTotalForRewards` delegates here and HAS a live caller
    // (achievements_overview_provider.dart:122), so returning 0 would render a
    // child's achievements as zero points, silently, forever. Points are
    // achievement data — owner ruling D-E: fail loudly.
    throw UnsupportedError(
      'getTrackPointsTotal is not available on the Firestore path: points are '
      'curriculum-keyed now (AD-25). Call PointsService.getCurriculumTotal '
      'with a CurriculumId instead.',
    );
  }

  /// @deprecated Track-based points queries are no longer supported (AD-25).
  /// Points are now curriculum-keyed. Use [PointsService.getCurriculumTotal] instead.
  @Deprecated('Use PointsService.getCurriculumTotal with CurriculumId')
  Future<int> getTrackPointsTotalForRewards(int trackId) async {
    // Cannot determine curriculum from trackId without trackDao.
    // This method is kept only to avoid breaking callers; it returns 0.
    return 0;
  }

  /// DEC-32: the auto-unlock achievement ladder was REPLACED by the spend
  /// economy. Rewards are now purely priced spend-items (redeem for
  /// [RewardMilestone.pointsCost]); there is no cumulative-threshold auto-unlock
  /// crossing the debitable balance. This method is retained as a no-op so the
  /// (now removed) live-wiring contract is preserved for any straggler caller;
  /// it never writes an unlock record.
  ///
  /// R4o-C1: previously this read the DEBITABLE balance and auto-unlocked
  /// milestones whose [RewardMilestone.thresholdPoints] (simultaneously the
  /// redeem price) was crossed — incoherent once the balance dropped on spend.
  /// Retained as a no-op (returns no unlock records) so the spend economy is
  /// the single source of reward semantics.
  Future<List<RewardUnlockRecord>> evaluateUnlocksForTrack(int trackId) async {
    return const [];
  }

  /// DEC-32 no-op — see [evaluateUnlocksForTrack].
  Future<List<RewardUnlockRecord>> evaluateUnlocksForGlobal() async {
    return const [];
  }

  Future<Map<String, dynamic>> exportCloudPayload() async {
    final milestones = await getAllMilestones();
    final unlocks = await getAllUnlocks();
    final localUpdatedAt = await _getLocalUpdatedAt();

    return {
      'updated_at': localUpdatedAt.toIso8601String(),
      'milestones': milestones.map((m) => m.toJson()).toList(),
      'unlocks': unlocks.map((u) => u.toJson()).toList(),
    };
  }

  Future<void> mergeCloudPayload(Map<String, dynamic>? remote) async {
    if (remote == null || remote.isEmpty) return;

    final remoteUpdatedAt = DateTime.tryParse(
      (remote['updated_at'] ?? '').toString(),
    );
    final localUpdatedAt = await _getLocalUpdatedAt();
    // AUD-gamification-05: a missing/unparseable remote 'updated_at' must NOT
    // be treated as "unconditionally newer" -- that would unconditionally
    // overwrite local milestones/unlocks with an ambiguous-timestamp remote
    // payload (EH-2 LWW ordering must not silently clobber on ambiguous
    // input). Treat null the same as "not provably newer": skip the merge.
    if (remoteUpdatedAt == null || !remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return;
    }

    final milestonesRaw = remote['milestones'];
    final unlocksRaw = remote['unlocks'];

    final milestones = milestonesRaw is List
        ? milestonesRaw
              .where((e) => e is Map)
              .map(
                (e) => (e as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              .map(RewardMilestone.fromJson)
              .where((m) => m.profileId == profileId)
              .toList()
        : const <RewardMilestone>[];

    final unlocks = unlocksRaw is List
        ? unlocksRaw
              .where((e) => e is Map)
              .map(
                (e) => (e as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              .map(RewardUnlockRecord.fromJson)
              .where((u) => u.profileId == profileId)
              .toList()
        : const <RewardUnlockRecord>[];

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configKey,
      jsonEncode(milestones.map((m) => m.toJson()).toList()),
    );
    await prefs.setString(
      _unlockKey,
      jsonEncode(unlocks.map((u) => u.toJson()).toList()),
    );
    // remoteUpdatedAt is guaranteed non-null here: the AUD-gamification-05
    // guard above already returns early when it is null.
    await prefs.setInt(_updatedAtMsKey, remoteUpdatedAt.millisecondsSinceEpoch);
    await stripStockTemplateMilestones();
  }

  Future<void> _writeMilestones(
    List<RewardMilestone> milestones, {
    required DateTime updatedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configKey,
      jsonEncode(milestones.map((m) => m.toJson()).toList()),
    );
    await prefs.setInt(_updatedAtMsKey, updatedAt.millisecondsSinceEpoch);
  }

  Future<void> _writeUnlocks(
    List<RewardUnlockRecord> unlocks, {
    required DateTime updatedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _unlockKey,
      jsonEncode(unlocks.map((u) => u.toJson()).toList()),
    );
    await prefs.setInt(_updatedAtMsKey, updatedAt.millisecondsSinceEpoch);
  }

  Future<DateTime> _getLocalUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_updatedAtMsKey);
    if (ms == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  String _newMilestoneId() {
    final rng = Random();
    final stamp = DateTimeFactory.nowUtc().millisecondsSinceEpoch;
    return 'rm_${profileId}_${stamp}_${rng.nextInt(1 << 20)}';
  }
}

/// Stable, non-localizable identifier for a milestone's visual "tier"
/// (AUD-gamification-07).
///
/// Historically, [TierStyle.forTitle] (now [TierStyle.forTier]) keyed its
/// visual styling directly off the milestone's raw English display title --
/// a fragile coupling where a future rename, typo fix, or localization of
/// one of [RewardMilestoneService.defaultMilestoneLadder]'s titles would
/// silently fall through to the generic default style, with no exception,
/// log, or test failure. [classify] performs that title match exactly once,
/// against the SAME canonical ladder
/// [RewardMilestoneService.stripStockTemplateMilestones] already matches
/// against (so the two can no longer independently drift out of sync --
/// Evans: re-derived invariant), and every other call site works with this
/// enum instead of raw text.
enum RewardTier {
  bronze,
  silver,
  gold,
  platinum,
  premium,
  diamond,
  elite,
  legend,

  /// A parent-configured custom reward, or a stock title that no longer
  /// matches the ladder -- rendered with the neutral default style. Never
  /// silently confused with a real tier: this is its own named value.
  custom;

  /// Positional order MUST match
  /// [RewardMilestoneService.defaultMilestoneLadder].
  static const List<RewardTier> _ladderOrder = [
    bronze,
    silver,
    gold,
    platinum,
    premium,
    diamond,
    elite,
    legend,
  ];

  /// Classifies a milestone [title] against the canonical stock ladder.
  ///
  /// Matches on trimmed title only -- mirroring exactly what the
  /// title-keyed switch this replaces did (threshold is intentionally NOT
  /// part of the match, so this is not a stricter/behavior-changing check
  /// than before). Returns [custom] when nothing matches, e.g. any
  /// parent-configured reward title under the spend economy (DEC-32).
  static RewardTier classify(String title) {
    final trimmed = title.trim();
    const ladder = RewardMilestoneService.defaultMilestoneLadder;
    for (var i = 0; i < ladder.length; i++) {
      if (ladder[i].title == trimmed) {
        return _ladderOrder[i];
      }
    }
    return RewardTier.custom;
  }
}
