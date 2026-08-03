import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';

/// Result of [CompletionRepository.markComplete] including any reward
/// milestones newly crossed on this mark (child profiles, eligible tracks).
class MarkCompletionResult {
  const MarkCompletionResult({
    required this.completion,
    this.newMilestoneUnlocks = const [],
    this.isNew = true,
  });

  final Completion completion;

  /// Newly recorded reward unlocks from this completion (empty for adults,
  /// duplicates, or when the track does not count toward reward points).
  final List<RewardUnlockRecord> newMilestoneUnlocks;

  /// True when [CompletionRepository.markComplete] inserted a brand-new
  /// storage row for this call; false when it returned an already-existing
  /// completion (the natural-key idempotency/duplicate path).
  ///
  /// `CompletionOrchestrator` (`lib/features/learning/domain/services/
  /// completion_orchestrator.dart`) gates every post-write side effect
  /// (points, streak, siyum detection, bookmark advance) on this flag —
  /// re-marking an already-completed stage must not double-credit anything.
  /// Defaults to `true` so pre-existing test doubles that construct this
  /// result without setting it (there is exactly one genuinely-new
  /// completion per call in their fixtures) are unaffected.
  final bool isNew;
}
