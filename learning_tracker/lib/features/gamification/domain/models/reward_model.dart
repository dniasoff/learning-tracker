import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/database/app_database.dart' as drift;

part 'reward_model.freezed.dart';

/// Domain model for a mystery reward.
@freezed
abstract class RewardModel with _$RewardModel {
  const factory RewardModel({
    required int id,
    required String title,
    required String description,
    required int pointsThreshold,
    required bool isEarned,
    required bool isRevealed,
    DateTime? earnedAt,
    required DateTime createdAt,
  }) = _RewardModel;

  /// Converts a Drift [drift.Reward] row into a domain [RewardModel].
  factory RewardModel.fromDriftRow(drift.Reward row) => RewardModel(
        id: row.id,
        title: row.title,
        description: row.description,
        pointsThreshold: row.pointsThreshold,
        isEarned: row.isEarned,
        isRevealed: row.isRevealed,
        earnedAt: row.earnedAt,
        createdAt: row.createdAt,
      );
}
