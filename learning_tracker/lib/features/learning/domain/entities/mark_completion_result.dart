import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';

/// Result of [CompletionRepository.markComplete] including any reward
/// milestones newly crossed on this mark (child profiles, eligible tracks).
class MarkCompletionResult {
  const MarkCompletionResult({
    required this.completion,
    this.newMilestoneUnlocks = const [],
  });

  final Completion completion;

  /// Newly recorded reward unlocks from this completion (empty for adults,
  /// duplicates, or when the track does not count toward reward points).
  final List<RewardUnlockRecord> newMilestoneUnlocks;
}
