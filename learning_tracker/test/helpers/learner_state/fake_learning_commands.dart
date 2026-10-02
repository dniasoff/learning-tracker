/// Fakes of the C0 (DNI-524) command seams: [FakeLearningCommands],
/// [FakeCaptureGate] and [RecordingLearningAnalytics], plus the DNI-469
/// seams [FakeLearningCommandReads] and [RecordingLearningFailureReporter].
///
/// Each `implements` its interface, so a contract change breaks it at
/// compile time. The fakes are not the spec (C0 contract-change protocol,
/// rule 4).
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';

/// One recorded [LearningCommands] call: the method [name] and its
/// arguments by parameter name.
final class LearningCommandCall {
  /// Creates the record.
  const LearningCommandCall(this.name, this.args);

  /// The method name, e.g. `capture`.
  final String name;

  /// The arguments by parameter name.
  final Map<String, Object?> args;

  @override
  bool operator ==(Object other) {
    if (other is! LearningCommandCall ||
        other.name != name ||
        other.args.length != args.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in args.entries) {
      if (!other.args.containsKey(key) ||
          !_deepEquals(other.args[key], value)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAllUnordered(args.keys));

  @override
  String toString() => 'LearningCommandCall($name, $args)';
}

bool _deepEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) {
    return a.length == b.length && a.containsAll(b);
  }
  return a == b;
}

/// A [LearningCommands] that records every call in [calls] and returns a
/// scripted result.
///
/// [nextResult] is one-shot: the next call returns it and clears it.
/// Otherwise every call returns `CaptureResult.success` echoing fresh ULIDs
/// (one event id per captured ref or node, per voided target, per
/// un-learnt leaf and per undone event; two for a replace; one change id
/// per governed entity change, with the first as the action id).
/// [watchPendingFailures] is [pendingFailures]' stream; push lists into it.
final class FakeLearningCommands implements LearningCommands {
  /// Every call, in order.
  final List<LearningCommandCall> calls = [];

  /// The result of the next call, if scripted (one-shot).
  CaptureResult? nextResult;

  /// The pending-failure feed.
  final StreamController<List<PendingFailure>> pendingFailures =
      StreamController<List<PendingFailure>>.broadcast();

  int _seq = 0;

  static const _crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  /// A fresh, valid, ascending ULID (`01FAKE…` + a base-32 counter).
  String freshId() {
    var n = ++_seq;
    final tail = StringBuffer();
    for (var i = 0; i < 16; i++) {
      tail.write(_crockford[n % 32]);
      n ~/= 32;
    }
    return '01FAKE0000${tail.toString().split('').reversed.join()}';
  }

  List<String> _ids(int count) => [for (var i = 0; i < count; i++) freshId()];

  CaptureResult _record(
    String name,
    Map<String, Object?> args, {
    int events = 0,
    int changes = 0,
  }) {
    calls.add(LearningCommandCall(name, args));
    final scripted = nextResult;
    if (scripted != null) {
      nextResult = null;
      return scripted;
    }
    final changeIds = _ids(changes);
    return CaptureResult.success(
      eventIds: _ids(events),
      changeIds: changeIds,
      actionId: changeIds.isEmpty ? null : changeIds.first,
    );
  }

  @override
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
  }) async => _record('capture', {
    'curriculumId': curriculumId,
    'refs': refs,
    'nodes': nodes,
    'source': source,
    'dateState': dateState,
    'learnedOn': learnedOn,
    'stage': stage,
  }, events: refs.length + nodes.length);

  @override
  Future<CaptureResult> voidEvent(String targetId) async =>
      _record('voidEvent', {'targetId': targetId}, events: 1);

  @override
  Future<CaptureResult> replace(
    String targetId,
    EventReplacement replacement,
  ) async => _record('replace', {
    'targetId': targetId,
    'replacement': replacement,
  }, events: 2);

  @override
  Future<CaptureResult> unlearn(
    String curriculumId,
    Set<LeafRef> leafSet,
  ) async => _record('unlearn', {
    'curriculumId': curriculumId,
    'leafSet': leafSet,
  }, events: leafSet.length);

  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) async =>
      _record('undoEvents', {'eventIds': eventIds}, events: eventIds.length);

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) async =>
      _record('applyGovernedChange', {
        'action': action,
      }, changes: action.changes.length);

  @override
  Future<CaptureResult> undoAction(String actionId) async =>
      _record('undoAction', {'actionId': actionId}, changes: 1);

  @override
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
  }) async => _record('createSubTrack', {
    'draft': draft,
    'subTrackId': subTrackId,
  }, changes: 1);

  @override
  Future<CaptureResult> editSubTrack(
    String subTrackId,
    SubTrackEdit edit,
  ) async => _record('editSubTrack', {
    'subTrackId': subTrackId,
    'edit': edit,
  }, changes: 1);

  @override
  Future<CaptureResult> endSubTrack(String subTrackId) async =>
      _record('endSubTrack', {'subTrackId': subTrackId}, changes: 1);

  @override
  Future<CaptureResult> deleteSubTrack(String subTrackId) async =>
      _record('deleteSubTrack', {'subTrackId': subTrackId}, changes: 1);

  @override
  Stream<List<PendingFailure>> watchPendingFailures() {
    calls.add(const LearningCommandCall('watchPendingFailures', {}));
    return pendingFailures.stream;
  }

  @override
  Future<CaptureResult> retry(String pendingFailureId) async =>
      _record('retry', {'pendingFailureId': pendingFailureId});

  /// Closes [pendingFailures].
  Future<void> dispose() => pendingFailures.close();
}

/// A [CaptureGate] with a fixed decision that records each check.
final class FakeCaptureGate implements CaptureGate {
  /// Always open.
  FakeCaptureGate.open() : decision = const GateOpen();

  /// Always locked inside [window].
  FakeCaptureGate.locked(LockWindow window) : decision = GateLocked(window);

  /// The fixed decision; reassign to change it mid-test.
  GateDecision decision;

  /// Every `(settingsHistory, nowUtc)` checked, in order.
  final List<(LearnerSettingsHistory, DateTime)> checks = [];

  @override
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc) {
    checks.add((settingsHistory, nowUtc));
    return decision;
  }
}

/// One recorded [LearningAnalytics.capture].
typedef RecordedCapture = ({
  String curriculumId,
  CaptureSourceKind sourceKind,
  DateState dateState,
  int count,
});

/// One recorded [LearningAnalytics.subTrackLifecycle].
typedef RecordedSubTrackLifecycle = ({
  String curriculumId,
  SubTrackType type,
  SubTrackLifecycleAction action,
  int groundEntries,
});

/// A [LearningAnalytics] that records every event.
final class RecordingLearningAnalytics implements LearningAnalytics {
  /// Every `capture`, in order.
  final List<RecordedCapture> captures = [];

  /// Every `subTrackLifecycle`, in order.
  final List<RecordedSubTrackLifecycle> lifecycles = [];

  @override
  void subTrackLifecycle({
    required String curriculumId,
    required SubTrackType type,
    required SubTrackLifecycleAction action,
    required int groundEntries,
  }) => lifecycles.add((
    curriculumId: curriculumId,
    type: type,
    action: action,
    groundEntries: groundEntries,
  ));

  @override
  void capture({
    required String curriculumId,
    required CaptureSourceKind sourceKind,
    required DateState dateState,
    required int count,
  }) => captures.add((
    curriculumId: curriculumId,
    sourceKind: sourceKind,
    dateState: dateState,
    count: count,
  ));
}

/// A [LearningCommandReads] over mutable in-memory values. Every read is
/// appended to [reads] (`settings`, `events`, `corpus`, `points`).
final class FakeLearningCommandReads implements LearningCommandReads {
  /// Creates the reads.
  FakeLearningCommandReads({
    required this.history,
    List<LearningEvent>? log,
    Map<String, Corpus>? corpora,
    this.pointsFor,
  }) : eventLog = log ?? [],
       corpora = corpora ?? {};

  /// The settings history; null makes [settingsHistory] throw.
  LearnerSettingsHistory? history;

  /// The event log.
  final List<LearningEvent> eventLog;

  /// The corpora by curriculum id.
  final Map<String, Corpus> corpora;

  /// The amount for `(curriculumId, stage)`; defaults to 10 for stage null
  /// or 1, else 5.
  int Function(String curriculumId, int? stage)? pointsFor;

  /// Every read, in order.
  final List<String> reads = [];

  @override
  Future<LearnerSettingsHistory> settingsHistory(LearnerScope scope) async {
    reads.add('settings');
    final h = history;
    if (h == null) throw StateError('settings unavailable');
    return h;
  }

  @override
  Future<List<LearningEvent>> events(LearnerScope scope) async {
    reads.add('events');
    return List.of(eventLog);
  }

  @override
  Future<Corpus?> corpus(String curriculumId) async {
    reads.add('corpus');
    return corpora[curriculumId];
  }

  @override
  Future<int> pointsAmount(
    LearnerScope scope,
    String curriculumId,
    int? stage,
  ) async {
    reads.add('points');
    return pointsFor?.call(curriculumId, stage) ??
        (stage == null || stage == 1 ? 10 : 5);
  }
}

/// One recorded [LearningFailureReporter.writeRejected].
typedef RecordedRejection = ({
  LearningCommandKind command,
  PendingFailureReason reason,
  int writeCount,
});

/// A [LearningFailureReporter] that records every report.
final class RecordingLearningFailureReporter
    implements LearningFailureReporter {
  /// Every report, in order.
  final List<RecordedRejection> reports = [];

  @override
  void writeRejected({
    required LearningCommandKind command,
    required PendingFailureReason reason,
    required int writeCount,
  }) => reports.add((command: command, reason: reason, writeCount: writeCount));
}
