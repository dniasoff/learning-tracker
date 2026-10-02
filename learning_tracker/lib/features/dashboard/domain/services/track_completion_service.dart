import 'package:learning_tracker/domain/learner_state/learner_state.dart';

/// Pure track and curriculum completion percentages over the engine's
/// learner state (DNI-474).
///
/// Goal progress is the distinct learnt count (FR-14): every source and
/// date state counts, a repeat or chazara counts once, and a voided or
/// lock-ignored event never counts — all decided by the engine. This
/// service only divides.
class TrackCompletionService {
  const TrackCompletionService();

  /// The engine's distinct learnt leaves of [state] over [totalItems].
  double computeTrackPercentage({
    required CurriculumState? state,
    required int totalItems,
  }) {
    if (totalItems <= 0) return 0.0;
    return ((state?.distinctLearnt ?? 0) / totalItems).clamp(0.0, 1.0);
  }

  /// The union of [states]' learnt leaves (a leaf learnt in two curricula
  /// counts once) over [totalItems].
  double computeCurriculumPercentage({
    required Iterable<CurriculumState?> states,
    required int totalItems,
  }) {
    if (totalItems <= 0) return 0.0;
    final learnt = <String>{
      for (final state in states) ...?state?.learntLeaves,
    };
    return (learnt.length / totalItems).clamp(0.0, 1.0);
  }
}
