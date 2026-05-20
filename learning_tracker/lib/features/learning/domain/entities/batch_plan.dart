import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

/// Sealed union classifying a batch of [CompletionCommand]s by the B1 credit
/// tier they represent.
///
/// [CompletionWriter.commitBatch] receives a [BatchPlan] so it knows which
/// side-effect tiers to trigger without inspecting raw command fields:
///
/// ```
/// BatchPlan           | Streak / Points | Siyumim | Lifetime
/// ────────────────────┼─────────────────┼─────────┼─────────
/// LiveBatchPlan       |       ✓         |    ✓    |    ✓
/// BulkInTrackPlan     |       ✗         |    ✓    |    ✓
/// LifetimeOnlyPlan    |       ✗         |    ✗    |    ✓
/// ```
///
/// ### Classification rules
/// * [LiveBatchPlan] — live in-session commands (`priorMarkOnly = false`).
/// * [BulkInTrackPlan] — bulk prior-learning commands (`priorMarkOnly = true`)
///   issued during the Add-Track or Edit-Track wizard.
/// * [LifetimeOnlyPlan] — pure historical imports from settings/lifetime.
///
/// Use [BatchPlan.classify] to derive the plan from a list of commands and
/// an explicit [CompletionSource]. Passing [CompletionSource] is mandatory
/// so callers can't accidentally mix source semantics with the `priorMarkOnly`
/// flag state (which is a storage concern, not a credit-policy concern).
sealed class BatchPlan {
  const BatchPlan({required this.commands});

  /// The commands to commit.
  final List<CompletionCommand> commands;

  /// The credit source for every command in this plan.
  CompletionSource get source;

  /// Classify [commands] into the correct [BatchPlan] subtype based on
  /// the caller's explicit [source].
  ///
  /// [source] takes precedence over the `priorMarkOnly` flags on individual
  /// commands — callers are responsible for passing the correct source. The
  /// classification is intentionally simple so mismatches are caught by the
  /// domain boundary rather than silently propagated to the data layer.
  factory BatchPlan.classify({
    required List<CompletionCommand> commands,
    required CompletionSource source,
  }) {
    return switch (source) {
      CompletionSource.live => LiveBatchPlan(commands: commands),
      CompletionSource.bulkInTrack => BulkInTrackPlan(commands: commands),
      CompletionSource.lifetimeOnly => LifetimeOnlyPlan(commands: commands),
    };
  }

  /// Whether engagement side effects (streak events, gamification points)
  /// should fire for this batch. Delegates to [CompletionSource.creditsEngagement].
  bool get creditsEngagement => source.creditsEngagement;

  /// Whether achievement side effects (siyum detection, study-report indexing)
  /// should fire for this batch. Delegates to [CompletionSource.creditsAchievement].
  bool get creditsAchievement => source.creditsAchievement;

  /// Whether completion enters lifetime data (always true).
  /// Delegates to [CompletionSource.creditsLifetime].
  bool get creditsLifetime => source.creditsLifetime;
}

/// Live in-session batch — all three tiers fire.
///
/// Commands originate from a learner pressing "Mark Complete" during a
/// real study session. Points, streak events, siyum detection, and
/// lifetime-data indexing all fire.
final class LiveBatchPlan extends BatchPlan {
  const LiveBatchPlan({required super.commands});

  @override
  CompletionSource get source => CompletionSource.live;

  @override
  String toString() => 'LiveBatchPlan(${commands.length} commands)';
}

/// Bulk prior-learning batch — engagement tier suppressed.
///
/// Commands originate from the Add-Track / Edit-Track wizard's bulk-mark
/// step ("I already learned this"). No streak event, no points. Siyum
/// detection and lifetime indexing still apply. All commands carry
/// `priorMarkOnly = true`.
final class BulkInTrackPlan extends BatchPlan {
  const BulkInTrackPlan({required super.commands});

  @override
  CompletionSource get source => CompletionSource.bulkInTrack;

  @override
  String toString() => 'BulkInTrackPlan(${commands.length} commands)';
}

/// Pure historical import batch — only lifetime tier fires.
///
/// Commands originate from lifetime import flows (settings / data migration).
/// No streak event, no points, no siyum detection. The completions enter the
/// learner's history for lifetime-coverage statistics only.
final class LifetimeOnlyPlan extends BatchPlan {
  const LifetimeOnlyPlan({required super.commands});

  @override
  CompletionSource get source => CompletionSource.lifetimeOnly;

  @override
  String toString() => 'LifetimeOnlyPlan(${commands.length} commands)';
}
