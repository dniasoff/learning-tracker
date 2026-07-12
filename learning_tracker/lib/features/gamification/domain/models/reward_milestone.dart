import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'reward_milestone.freezed.dart';

@freezed
abstract class RewardMilestone with _$RewardMilestone {
  /// Stored as [trackId] for milestones that use [PointsService.getGlobalTotal].
  ///
  /// Real curriculum tracks use positive DB ids (auto-increment from 1).
  static const int kGlobalTrackSentinel = 0;

  const RewardMilestone._();

  const factory RewardMilestone({
    required String id,
    required int profileId,
    required int trackId,
    required String title,

    /// Cost in points for the child to redeem this reward (WS7.reward-price).
    ///
    /// Stored under the `threshold_points` JSON key for backward
    /// compatibility with existing cloud payloads. In the spend-economy
    /// (DEC-32), this is the price the child pays to redeem — not a
    /// cumulative auto-unlock threshold.
    required int thresholdPoints,
    required bool isEnabled,
    required DateTime createdAt,
    required DateTime updatedAt,

    /// Parent-selected reward icon; index into [RewardMilestoneIcons.choices].
    /// Synced in `reward_settings`.
    @Default(0) int iconIndex,
  }) = _RewardMilestone;

  /// Alias for [thresholdPoints]; the cost in points to redeem this reward.
  int get pointsCost => thresholdPoints;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'track_id': trackId,
      'title': title,
      'threshold_points': thresholdPoints,
      'is_enabled': isEnabled,
      'icon_index': iconIndex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static RewardMilestone fromJson(Map<String, dynamic> json) {
    return RewardMilestone(
      id: (json['id'] ?? '').toString(),
      profileId: _asInt(json['profile_id']) ?? 0,
      trackId: _asInt(json['track_id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      thresholdPoints: _asInt(json['threshold_points']) ?? 0,
      isEnabled: json['is_enabled'] as bool? ?? true,
      iconIndex: _asInt(json['icon_index']) ?? 0,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTimeFactory.nowUtc(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTimeFactory.nowUtc(),
    );
  }

  static int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
}

@freezed
abstract class RewardUnlockRecord with _$RewardUnlockRecord {
  const RewardUnlockRecord._();

  const factory RewardUnlockRecord({
    required String milestoneId,
    required int profileId,
    required int trackId,
    required String title,
    required int thresholdPoints,
    required int pointsAtUnlock,
    required DateTime unlockedAt,
  }) = _RewardUnlockRecord;

  Map<String, dynamic> toJson() {
    return {
      'milestone_id': milestoneId,
      'profile_id': profileId,
      'track_id': trackId,
      'title': title,
      'threshold_points': thresholdPoints,
      'points_at_unlock': pointsAtUnlock,
      'unlocked_at': unlockedAt.toIso8601String(),
    };
  }

  static RewardUnlockRecord fromJson(Map<String, dynamic> json) {
    return RewardUnlockRecord(
      milestoneId: (json['milestone_id'] ?? '').toString(),
      profileId: RewardMilestone._asInt(json['profile_id']) ?? 0,
      trackId: RewardMilestone._asInt(json['track_id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      thresholdPoints: RewardMilestone._asInt(json['threshold_points']) ?? 0,
      pointsAtUnlock: RewardMilestone._asInt(json['points_at_unlock']) ?? 0,
      unlockedAt:
          DateTime.tryParse((json['unlocked_at'] ?? '').toString()) ??
          DateTimeFactory.nowUtc(),
    );
  }
}
