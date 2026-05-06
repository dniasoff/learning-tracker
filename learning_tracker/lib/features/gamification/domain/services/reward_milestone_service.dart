import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local reward milestone configuration + unlock tracking.
///
/// Stored in SharedPreferences (profile-scoped), while points totals are
/// derived from completions in Drift for offline-first consistency.
class RewardMilestoneService {
  RewardMilestoneService(this._database, {required this.profileId});

  final UserDatabase _database;
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

  /// Same rules as [PointsService.getGlobalTotal] — reward-eligible tracks only.
  Future<int> getGlobalPointsForRewards() async {
    final completions = await _database.completionDao.getCompletionsByProfile(
      profileId,
    );
    if (completions.isEmpty) return 0;
    final eligibility = <int, bool>{};
    var sum = 0;
    for (final c in completions) {
      final eligible =
          eligibility[c.trackId] ?? await trackCountsTowardRewardPoints(
                c.trackId,
              );
      eligibility[c.trackId] = eligible;
      if (eligible) {
        sum += c.points;
      }
    }
    return sum;
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
    } catch (_) {
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
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsertMilestone({
    required int trackId,
    required String title,
    required int thresholdPoints,
    String? milestoneId,
    bool isEnabled = true,
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
        ),
      );
    }

    await _writeMilestones(all, updatedAt: now);
  }

  Future<void> removeMilestone(String milestoneId) async {
    final now = DateTimeFactory.nowUtc();
    final all = await getAllMilestones();
    final filtered = all.where((m) => m.id != milestoneId).toList();
    await _writeMilestones(filtered, updatedAt: now);
  }

  /// Default eight-tier ladder (points thresholds) used by the achievements UI.
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

  Future<void> ensureDefaultsForTrack(int trackId) async {
    if (trackId == RewardMilestone.kGlobalTrackSentinel) return;
    var existing = await getMilestonesForTrack(trackId);
    if (_isLegacyThreeTierLadder(existing)) {
      await _migrateLegacyThreeTierToDefaultEight(trackId, existing);
      existing = await getMilestonesForTrack(trackId);
    }
    if (existing.isNotEmpty) return;

    for (final tier in defaultMilestoneLadder) {
      await upsertMilestone(
        trackId: trackId,
        title: tier.title,
        thresholdPoints: tier.thresholdPoints,
      );
    }
  }

  bool _isLegacyThreeTierLadder(List<RewardMilestone> trackMilestones) {
    if (trackMilestones.length != 3) return false;
    final sorted = [...trackMilestones]
      ..sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));
    return sorted[0].thresholdPoints == 50 &&
        sorted[1].thresholdPoints == 150 &&
        sorted[2].thresholdPoints == 300;
  }

  /// Replaces the original 50/150/300 ladder with [defaultMilestoneLadder].
  ///
  /// Drops unlock rows that pointed at removed milestone ids so the UI stays
  /// consistent with the new thresholds.
  Future<void> _migrateLegacyThreeTierToDefaultEight(
    int trackId,
    List<RewardMilestone> legacy,
  ) async {
    final now = DateTimeFactory.nowUtc();
    final removedIds = legacy.map((m) => m.id).toSet();

    final allMilestones = List<RewardMilestone>.from(await getAllMilestones());
    allMilestones.removeWhere(
      (m) => m.trackId == trackId && removedIds.contains(m.id),
    );
    await _writeMilestones(allMilestones, updatedAt: now);

    final unlocks = await getAllUnlocks();
    final kept = unlocks
        .where((u) => !removedIds.contains(u.milestoneId))
        .toList();
    await _writeUnlocks(kept, updatedAt: now);

    for (final tier in defaultMilestoneLadder) {
      await upsertMilestone(
        trackId: trackId,
        title: tier.title,
        thresholdPoints: tier.thresholdPoints,
      );
    }
  }

  Future<int> getTrackPointsTotal(int trackId) async {
    final totalExpr = _database.completions.points.sum();
    final row =
        await (_database.selectOnly(_database.completions)
              ..addColumns([totalExpr])
              ..where(
                _database.completions.profileId.equals(profileId) &
                    _database.completions.trackId.equals(trackId),
              ))
            .getSingle();
    return row.read(totalExpr) ?? 0;
  }

  /// True when this track is a **programmed** (yeshiva cycle) or **self-paced**
  /// (has a learning goal) track. Momentum-only "browse" tracks — and lifetime
  /// learning (ledger only, no completions) — do not count toward reward points.
  Future<bool> trackCountsTowardRewardPoints(int trackId) async {
    final track = await _database.trackDao.getTrackById(trackId);
    if (track == null) return false;

    final program = await _database.profileProgramDao
        .getProgramForProfileAndCurriculum(profileId, track.curriculumId);
    if (program != null) return true;

    final goal = await _database.goalDao.getGoalByTrack(trackId);
    return goal != null;
  }

  /// Points total used for reward milestones: zero when [trackCountsTowardRewardPoints] is false.
  Future<int> getTrackPointsTotalForRewards(int trackId) async {
    if (!await trackCountsTowardRewardPoints(trackId)) return 0;
    return getTrackPointsTotal(trackId);
  }

  /// Unlock any enabled milestones crossed by the track's current points.
  Future<List<RewardUnlockRecord>> evaluateUnlocksForTrack(int trackId) async {
    if (!await trackCountsTowardRewardPoints(trackId)) {
      return const [];
    }
    final trackPoints = await getTrackPointsTotalForRewards(trackId);
    final milestones = await getMilestonesForTrack(trackId);
    if (milestones.isEmpty) return const [];

    final unlocks = await getAllUnlocks();
    final unlockedIds = unlocks.map((u) => u.milestoneId).toSet();
    final now = DateTimeFactory.nowUtc();

    final newlyUnlocked = <RewardUnlockRecord>[];
    for (final milestone in milestones) {
      if (!milestone.isEnabled) continue;
      if (trackPoints < milestone.thresholdPoints) continue;
      if (unlockedIds.contains(milestone.id)) continue;

      newlyUnlocked.add(
        RewardUnlockRecord(
          milestoneId: milestone.id,
          profileId: profileId,
          trackId: trackId,
          title: milestone.title,
          thresholdPoints: milestone.thresholdPoints,
          pointsAtUnlock: trackPoints,
          unlockedAt: now,
        ),
      );
    }

    if (newlyUnlocked.isNotEmpty) {
      await _writeUnlocks([...unlocks, ...newlyUnlocked], updatedAt: now);
    }
    return newlyUnlocked;
  }

  /// Unlock enabled global milestones when [getGlobalPointsForRewards] crosses
  /// thresholds. [RewardUnlockRecord.trackId] is [RewardMilestone.kGlobalTrackSentinel].
  Future<List<RewardUnlockRecord>> evaluateUnlocksForGlobal() async {
    final globalPoints = await getGlobalPointsForRewards();
    final milestones = await getGlobalMilestones();
    if (milestones.isEmpty) return const [];

    final unlocks = await getAllUnlocks();
    final unlockedIds = unlocks.map((u) => u.milestoneId).toSet();
    final now = DateTimeFactory.nowUtc();
    const sentinel = RewardMilestone.kGlobalTrackSentinel;

    final newlyUnlocked = <RewardUnlockRecord>[];
    for (final milestone in milestones) {
      if (!milestone.isEnabled) continue;
      if (globalPoints < milestone.thresholdPoints) continue;
      if (unlockedIds.contains(milestone.id)) continue;

      newlyUnlocked.add(
        RewardUnlockRecord(
          milestoneId: milestone.id,
          profileId: profileId,
          trackId: sentinel,
          title: milestone.title,
          thresholdPoints: milestone.thresholdPoints,
          pointsAtUnlock: globalPoints,
          unlockedAt: now,
        ),
      );
    }

    if (newlyUnlocked.isNotEmpty) {
      await _writeUnlocks([...unlocks, ...newlyUnlocked], updatedAt: now);
    }
    return newlyUnlocked;
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
    if (remoteUpdatedAt != null && !remoteUpdatedAt.isAfter(localUpdatedAt)) {
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
    final stamp =
        (remoteUpdatedAt ?? DateTimeFactory.nowUtc()).millisecondsSinceEpoch;
    await prefs.setInt(_updatedAtMsKey, stamp);
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
