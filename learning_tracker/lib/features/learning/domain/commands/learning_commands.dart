/// The single write surface for learning (AD-31, AD-38).
///
/// C0 fixes the interface. DNI-469 (1.7) adds `DefaultLearningCommands` in
/// this file and DNI-470 (1.8) fills its governed methods. The provider
/// binds the commands to one `LearnerScope` and the session actor, and
/// every command runs `CaptureGate` first. Imports only
/// `lib/domain/learner_state/**` and `dart:` (AC-1).
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

/// The replacement fields of `LearningCommands.replace`; null keeps the
/// target's value.
final class EventReplacement {
  /// Creates a replacement.
  const EventReplacement({
    this.ref,
    this.source,
    this.learnedOn,
    this.dateState,
    this.stage,
  });

  /// The new leaf.
  final LeafRef? ref;

  /// The new source (`'main'` or a sub-track ULID).
  final String? source;

  /// The new civil date.
  final CivilDate? learnedOn;

  /// The new date state.
  final DateState? dateState;

  /// The new review stage.
  final int? stage;

  @override
  bool operator ==(Object other) =>
      other is EventReplacement &&
      other.ref == ref &&
      other.source == source &&
      other.learnedOn == learnedOn &&
      other.dateState == dateState &&
      other.stage == stage;

  @override
  int get hashCode => Object.hash(ref, source, learnedOn, dateState, stage);

  @override
  String toString() => 'EventReplacement($ref, $source, $learnedOn)';
}

/// Every learning write: events (AD-31) and governed changes (AD-38).
abstract interface class LearningCommands {
  /// Records [refs] (leaves) and [nodes] as learnt for [curriculumId].
  ///
  /// [nodes] is allowed only with [DateState.beforeTracking]; [source] is
  /// `'main'` or a sub-track ULID.
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
  });

  /// Voids the `learn` event [targetId].
  Future<CaptureResult> voidEvent(String targetId);

  /// Voids [targetId] and records its [replacement].
  Future<CaptureResult> replace(String targetId, EventReplacement replacement);

  /// Un-learns [leafSet] in [curriculumId] (AD-31).
  Future<CaptureResult> unlearn(String curriculumId, Set<LeafRef> leafSet);

  /// Undoes [eventIds]: a learn is voided; a void is re-issued as a copy
  /// with `original_recorded_at`. Covers undo of an un-learn.
  Future<CaptureResult> undoEvents(List<String> eventIds);

  /// Applies an AD-38 governed [action].
  Future<CaptureResult> applyGovernedChange(GovernedAction action);

  /// Undoes the governed action [actionId].
  Future<CaptureResult> undoAction(String actionId);

  /// Queued writes the server rejected, live.
  Stream<List<PendingFailure>> watchPendingFailures();

  /// Retries the pending failure [pendingFailureId].
  Future<CaptureResult> retry(String pendingFailureId);
}
