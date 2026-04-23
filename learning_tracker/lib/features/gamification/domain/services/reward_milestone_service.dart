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
    trackMilestones.sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));
    return trackMilestones;
  }

  Future<List<RewardMilestone>> getAllMilestones() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
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
          .whereType<Map<String, dynamic>>()
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
    final now = DateTimeFactory.nowUtc();
    final all = await getAllMilestones();

    final existingIndex = milestoneId == null
        ? -1
        : all.indexWhere((m) => m.id == milestoneId && m.profileId == profileId);

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

  Future<void> ensureDefaultsForTrack(int trackId) async {
    final existing = await getMilestonesForTrack(trackId);
    if (existing.isNotEmpty) return;

    await upsertMilestone(
      trackId: trackId,
      title: 'Bronze Star',
      thresholdPoints: 50,
    );
    await upsertMilestone(
      trackId: trackId,
      title: 'Silver Star',
      thresholdPoints: 150,
    );
    await upsertMilestone(
      trackId: trackId,
      title: 'Gold Star',
      thresholdPoints: 300,
    );
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

  /// Unlock any enabled milestones crossed by the track's current points.
  Future<List<RewardUnlockRecord>> evaluateUnlocksForTrack(int trackId) async {
    final trackPoints = await getTrackPointsTotal(trackId);
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
              .whereType<Map<String, dynamic>>()
              .map(RewardMilestone.fromJson)
              .where((m) => m.profileId == profileId)
              .toList()
        : const <RewardMilestone>[];

    final unlocks = unlocksRaw is List
        ? unlocksRaw
              .whereType<Map<String, dynamic>>()
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
    final stamp = (remoteUpdatedAt ?? DateTimeFactory.nowUtc())
        .millisecondsSinceEpoch;
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
