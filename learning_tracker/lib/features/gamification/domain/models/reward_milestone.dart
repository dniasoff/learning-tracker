class RewardMilestone {
  const RewardMilestone({
    required this.id,
    required this.profileId,
    required this.trackId,
    required this.title,
    required this.thresholdPoints,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int profileId;
  final int trackId;
  final String title;
  final int thresholdPoints;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  RewardMilestone copyWith({
    String? id,
    int? profileId,
    int? trackId,
    String? title,
    int? thresholdPoints,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RewardMilestone(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      thresholdPoints: thresholdPoints ?? this.thresholdPoints,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'track_id': trackId,
      'title': title,
      'threshold_points': thresholdPoints,
      'is_enabled': isEnabled,
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
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }

  static int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
}

class RewardUnlockRecord {
  const RewardUnlockRecord({
    required this.milestoneId,
    required this.profileId,
    required this.trackId,
    required this.title,
    required this.thresholdPoints,
    required this.pointsAtUnlock,
    required this.unlockedAt,
  });

  final String milestoneId;
  final int profileId;
  final int trackId;
  final String title;
  final int thresholdPoints;
  final int pointsAtUnlock;
  final DateTime unlockedAt;

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
              DateTime.now().toUtc(),
    );
  }
}
