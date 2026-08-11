import 'dart:convert';
import 'dart:math';

import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local reward milestone configuration + unlock tracking.
///
/// Stored in SharedPreferences (profile-scoped), while the points balance is
/// read from [PointsBalanceReader] (the spend-economy source of truth,
/// DEC-32).
///
/// DEC-32/GA-3: per-track rewards were removed from the spend economy —
/// every milestone applies to the single global debitable balance now. This
/// service no longer takes a track/curriculum key anywhere; see
/// `reward_config_controller.dart`'s own doc comment for the product
/// history ("tracks is hardcoded to const [] ... every reward is now a
/// single global priced spend-item").
class RewardMilestoneService {
  RewardMilestoneService({required this.balanceReader, required this.profileId});

  final PointsBalanceReader balanceReader;
  final String profileId;

  static const _configKeyPrefix = 'reward_milestones_config_v1_';
  static const _unlockKeyPrefix = 'reward_milestones_unlocks_v1_';
  static const _updatedAtMsKeyPrefix = 'reward_milestones_updated_at_ms_';

  String get _configKey => '$_configKeyPrefix$profileId';
  String get _unlockKey => '$_unlockKeyPrefix$profileId';
  String get _updatedAtMsKey => '$_updatedAtMsKeyPrefix$profileId';

  /// All configured reward milestones, sorted by threshold ascending.
  Future<List<RewardMilestone>> getMilestones() async {
    final all = List<RewardMilestone>.from(await getAllMilestones());
    all.sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));
    return all;
  }

  /// Current debitable balance for reward display (WS7.balance).
  ///
  /// Reads from [PointsBalanceReader] — the spend-economy source of truth (DEC-32).
  Future<int> getGlobalPointsForRewards() async {
    return balanceReader.getBalance();
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
    required String title,
    required int thresholdPoints,
    String? milestoneId,
    bool isEnabled = true,
    int iconIndex = 0,
  }) async {
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

    // Legacy 3-tier ladder detection: DEC-32/GA-3 removed per-track grouping,
    // so this now checks the single (global) list as a whole rather than
    // grouping by track first.
    if (all.length == 3) {
      final th = all.map((e) => e.thresholdPoints).toList()..sort();
      if (th[0] == 50 && th[1] == 150 && th[2] == 300) {
        for (final m in all) {
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
