/// The single write surface for learning (AD-31, AD-38).
///
/// C0 fixes the interface. DNI-469 (1.7) adds [DefaultLearningCommands] in
/// this file and DNI-470 (1.8) fills its governed methods. The provider
/// binds the commands to one `LearnerScope` and the session actor, and
/// every command runs `CaptureGate` first. Imports only
/// `lib/domain/learner_state/**`, this directory and `dart:` (AC-1).
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/default_points.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/features/learning/domain/commands/achievement_latch.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/child_redate_limit.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_chunker.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_dispatcher.dart';
import 'package:learning_tracker/features/learning/domain/commands/unlearn_plan.dart';

/// How long a command waits for the AD-50 points amount before it falls
/// back to the default stage ladder, so an uncached or unreachable
/// `point_configs` read never blocks an offline capture (AC-9).
const Duration defaultPointsReadWait = Duration(seconds: 2);

/// The replacement fields of `LearningCommands.replace`; null keeps the
/// target's value.
///
/// One exception: a [dateState] of [DateState.beforeTracking] clears
/// `learned_on` (schema: a `before_tracking` learn has `learned_on = null`),
/// so [learnedOn] must then be null and the target's date is not kept.
/// [resolveLearnedOn] is the single rule every implementation applies.
final class EventReplacement {
  /// Creates a replacement.
  const EventReplacement({
    this.ref,
    this.source,
    this.learnedOn,
    this.dateState,
    this.stage,
  }) : assert(
         dateState != DateState.beforeTracking || learnedOn == null,
         'a before_tracking replacement has no learned_on',
       );

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

  /// The replacement's `learned_on`, given the target's [targetLearnedOn]:
  /// null for a move to Before tracking, else [learnedOn] when set, else
  /// the target's value.
  CivilDate? resolveLearnedOn(CivilDate? targetLearnedOn) =>
      dateState == DateState.beforeTracking
      ? null
      : learnedOn ?? targetLearnedOn;

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
  String toString() =>
      'EventReplacement($ref, $source, $learnedOn, ${dateState?.name})';
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

  /// AD-38 "Remove track" (DNI-476): ONE action of a `mainTrack` entry
  /// setting `ended_at` on `curriculum_tracks/{curriculumId}` plus one
  /// `subTrack` tombstone entry (`end_reason: track_deleted`) per
  /// non-ended sub-track of that curriculum, sharing one `action_id`.
  /// Learning events and the points ledger are never touched. An unknown
  /// track is `targetNotFound`; an already removed one writes nothing.
  Future<CaptureResult> removeTrack(String curriculumId);

  /// AD-38 "Re-add" (DNI-476): clears the track's `ended_at` through a
  /// logged change; its prior config, progress and history were never
  /// touched, so they return with it. Sub-tracks ended by the removal stay
  /// ended (ruling B13). An unknown track is `targetNotFound`; a live one
  /// writes nothing.
  Future<CaptureResult> reAddTrack(String curriculumId);

  /// Queued writes the server rejected, live.
  Stream<List<PendingFailure>> watchPendingFailures();

  /// Retries the pending failure [pendingFailureId].
  Future<CaptureResult> retry(String pendingFailureId);
}

/// The AD-38 governed half of [LearningCommands], filled by DNI-470 (1.8).
/// [DefaultLearningCommands] delegates to it.
abstract interface class GovernedLearningCommands {
  /// See [LearningCommands.applyGovernedChange].
  Future<CaptureResult> applyGovernedChange(GovernedAction action);

  /// See [LearningCommands.undoAction].
  Future<CaptureResult> undoAction(String actionId);

  /// See [LearningCommands.removeTrack].
  Future<CaptureResult> removeTrack(String curriculumId);

  /// See [LearningCommands.reAddTrack].
  Future<CaptureResult> reAddTrack(String curriculumId);

  /// The governed writes the server did not save, live (AD-54 Recovery);
  /// [LearningCommands.watchPendingFailures] lists them after the event
  /// failures.
  Stream<List<PendingFailure>> watchPendingFailures();

  /// Re-sends the governed pending failure [pendingFailureId] unchanged;
  /// null when it is not a governed pending failure.
  Future<CaptureResult?> retry(String pendingFailureId);
}

/// The owner-device [LearningCommands] (AD-31, AD-36, AD-50, AD-54), bound
/// to one [LearnerScope] and the session [Actor].
///
/// A thin facade: every command first reads the TARGET learner's settings
/// history and runs the [CaptureGate] at one `nowUtc` (AD-36; a settings
/// read or gate failure fails closed), then plans its events with fixed ids
/// and times (`learning_event_plans.dart`, `unlearn_plan.dart`), chunks
/// them (`learning_write_chunker.dart`) and hands them to the
/// [LearningWriteDispatcher], which owns queued success and pending
/// failures. Nothing is written before the gate passes and the whole
/// command validates.
final class DefaultLearningCommands implements LearningCommands {
  /// Creates the commands.
  DefaultLearningCommands({
    required LearnerScope scope,
    required Actor actor,
    required LearningCommandReads reads,
    required LearningWritePort writePort,
    required CaptureGate gate,
    required LearningAnalytics analytics,
    required LearningFailureReporter failureReporter,
    required UtcClock clock,
    required UlidSource newUlid,
    Duration ackWait = defaultLearningAckWait,
    Duration pointsWait = defaultPointsReadWait,
    GovernedLearningCommands? governed,
    AchievementLatch? achievements,
  }) : _scope = scope,
       _achievements = achievements,
       _pointsWait = pointsWait,
       _actor = actor,
       _reads = reads,
       _gate = gate,
       _analytics = analytics,
       _clock = clock,
       _newUlid = newUlid,
       _governed = governed,
       _dispatcher = LearningWriteDispatcher(
         scope: scope,
         port: writePort,
         reporter: failureReporter,
         ackWait: ackWait,
       );

  final LearnerScope _scope;
  final Actor _actor;
  final LearningCommandReads _reads;
  final CaptureGate _gate;
  final LearningAnalytics _analytics;
  final UtcClock _clock;
  final UlidSource _newUlid;
  final GovernedLearningCommands? _governed;
  final LearningWriteDispatcher _dispatcher;
  final Duration _pointsWait;
  final AchievementLatch? _achievements;

  static const _invalid = CaptureResult.rejected(CaptureRejection.invalid);

  /// Reads the clock once, then the target learner's settings, then runs
  /// the gate; [body] runs only when the gate is open.
  Future<CaptureResult> _gated(
    Future<CaptureResult> Function(CommandStamp stamp, LearnerSettingsHistory h)
    body,
  ) async {
    final now = _clock().toUtc();
    final LearnerSettingsHistory history;
    final GateDecision decision;
    try {
      history = await _reads.settingsHistory(_scope);
      decision = _gate.check(history, now);
    } on Object {
      return CaptureResult.locked(unknownLockAt(now)); // FR-23 fail closed
    }
    if (decision case GateLocked(:final window)) {
      return CaptureResult.locked(window);
    }
    final stamp = CommandStamp(actor: _actor, nowUtc: now, newUlid: _newUlid);
    return body(stamp, history);
  }

  /// Chunks and dispatches [units]; the result of a command that wrote.
  Future<CaptureResult> _write(
    LearningCommandKind kind,
    List<WriteUnit> units,
  ) async {
    if (units.isEmpty) return const CaptureResult.success();
    final outcome = await _dispatcher.dispatch(kind, chunkWrites(units));
    if (outcome.allRejected) {
      return const CaptureResult.rejected(CaptureRejection.notSaved);
    }
    _afterWrite(outcome);
    return CaptureResult.success(
      eventIds: outcome.eventIds,
      queued: outcome.queued,
    );
  }

  /// The AD-50 amount of an earning event of [curriculumId] at [stage].
  ///
  /// Offline the points read may be uncached, fail or stall; the capture
  /// must still queue locally (AC-9), so any failure or a read slower than
  /// the points wait resolves to the default ladder at `stage ??
  /// firstStageOrder` (first stage 1 when unknown) — the same amount an
  /// absent override resolves to.
  Future<int> _pointsAmount(String curriculumId, int? stage) async {
    try {
      return await _reads
          .pointsAmount(_scope, curriculumId, stage)
          .timeout(_pointsWait);
    } on Object {
      return defaultStagePoints(stage ?? 1);
    }
  }

  Future<LearningLogView> _log(CommandStamp stamp, LearnerSettingsHistory h) =>
      _reads
          .events(_scope)
          .then((events) => LearningLogView.of(events, h, stamp.nowUtc));

  static bool _validSource(String source) =>
      source == LearningEvent.sourceMain || isUlid(source);

  @override
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
  }) => _gated((stamp, history) async {
    if (curriculumId.isEmpty || !_validSource(source)) return _invalid;
    if (nodes.isNotEmpty && dateState != DateState.beforeTracking) {
      return _invalid;
    }
    if (stage != null && (source != LearningEvent.sourceMain || stage < 0)) {
      return _invalid;
    }
    final leaves = refs.where((r) => r.isNotEmpty).toSet().toList();
    final nodeList = nodes.toSet().toList();
    if (leaves.length != refs.toSet().length) return _invalid;
    if (leaves.isEmpty && nodeList.isEmpty) {
      return const CaptureResult.success(); // nothing to write
    }
    CivilDate? day;
    if (dateState != DateState.beforeTracking) {
      day = learnedOn ?? civilDate(stamp.nowUtc, history);
      if (!isCivilDate(day)) return _invalid;
    }
    final earns =
        source == LearningEvent.sourceMain &&
        dateState != DateState.beforeTracking;
    final amount = earns ? await _pointsAmount(curriculumId, stage) : null;
    final List<WriteUnit> units;
    try {
      units = planCapture(
        stamp: stamp,
        curriculumId: curriculumId,
        leaves: leaves,
        nodes: nodeList,
        source: source,
        dateState: dateState,
        learnedOn: day,
        stage: stage,
        amount: amount,
      );
      _validate(units);
    } on StorageFormatException {
      return _invalid;
    }
    final result = await _write(LearningCommandKind.capture, units);
    if (result is CaptureSuccess) {
      _analytics.capture(
        curriculumId: curriculumId,
        sourceKind: source == LearningEvent.sourceMain
            ? CaptureSourceKind.main
            : CaptureSourceKind.subTrack,
        dateState: dateState,
        count: result.eventIds.length,
      );
    }
    return result;
  });

  @override
  Future<CaptureResult> voidEvent(String targetId) => _gated((
    stamp,
    history,
  ) async {
    if (!isUlid(targetId)) return _invalid;
    final log = await _log(stamp, history);
    final target = log.byId[targetId];
    // AD-31: a void whose target is absent is not an error.
    if (target != null) {
      if (target.isVoid) {
        return const CaptureResult.rejected(
          CaptureRejection.voidTargetNotLearn,
        );
      }
      if (log.isLockIgnored(targetId)) {
        return const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget);
      }
      if (log.isVoided(targetId)) {
        return const CaptureResult.success(); // never voided twice
      }
    }
    final id = stamp.ids(1).single;
    return _write(LearningCommandKind.voidEvent, [
      WriteUnit([voidEventOf(stamp, id, targetId)]),
    ]);
  });

  @override
  Future<CaptureResult> replace(
    String targetId,
    EventReplacement replacement,
  ) => _gated((stamp, history) async {
    final log = await _log(stamp, history);
    final target = log.byId[targetId];
    if (target == null) {
      return const CaptureResult.rejected(CaptureRejection.targetNotFound);
    }
    if (target.isVoid) {
      return const CaptureResult.rejected(CaptureRejection.voidTargetNotLearn);
    }
    if (log.isLockIgnored(targetId)) {
      return const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget);
    }
    if (log.isVoided(targetId)) return _invalid;
    final fields = _resolve(target, replacement, stamp, history);
    if (fields == null) return _invalid;
    if (fields.sameAs(target)) return const CaptureResult.success();
    if (fields.redate &&
        _actor.role == ActorRole.child &&
        !childMayRedate(
          learnedOn: fields.learnedOn,
          settingsHistory: history,
          nowUtc: stamp.nowUtc,
        )) {
      return const CaptureResult.childLimit(); // nothing written
    }
    final ids = stamp.ids(2);
    final List<WriteUnit> units;
    try {
      final next = replacementOf(stamp, ids[1], target, fields);
      final amount = earnsPointsEntry(next)
          ? await _pointsAmount(next.curriculumId!, next.stage)
          : null;
      units = [
        learnUnit(
          next,
          amount,
          stamp.nowUtc,
          alongside: [voidEventOf(stamp, ids[0], targetId)],
        ),
      ];
      _validate(units);
    } on StorageFormatException {
      return _invalid;
    }
    return _write(LearningCommandKind.replace, units);
  });

  /// The replacement fields, or null when they are invalid.
  ResolvedReplacement? _resolve(
    LearningEvent t,
    EventReplacement r,
    CommandStamp stamp,
    LearnerSettingsHistory history,
  ) {
    final source = r.source ?? t.source!;
    if (!_validSource(source)) return null;
    final state = r.dateState ?? t.dateState!;
    final redate =
        (r.dateState != null && r.dateState != t.dateState) ||
        (r.learnedOn != null && r.learnedOn != t.learnedOn);
    final learnedOn = state == DateState.beforeTracking
        ? null
        : r.learnedOn ?? t.learnedOn ?? civilDate(stamp.nowUtc, history);
    if (learnedOn != null && !isCivilDate(learnedOn)) return null;
    final level = r.ref != null && r.ref != t.ref ? null : t.level;
    if (level != null && state != DateState.beforeTracking) return null;
    final ref = r.ref ?? t.ref!;
    if (ref.isEmpty) return null;
    if (r.stage != null && source != LearningEvent.sourceMain) return null;
    final stage = source == LearningEvent.sourceMain
        ? r.stage ?? t.stage
        : null;
    return ResolvedReplacement(
      ref: ref,
      level: level,
      source: source,
      dateState: state,
      learnedOn: learnedOn,
      stage: stage,
      redate: redate,
    );
  }

  @override
  Future<CaptureResult> unlearn(String curriculumId, Set<LeafRef> leafSet) =>
      _gated((stamp, history) async {
        if (leafSet.isEmpty) return const CaptureResult.success();
        final corpus = await _reads.corpus(curriculumId);
        if (corpus == null) return _invalid;
        final log = await _log(stamp, history);
        final plan = planUnlearn(
          curriculumId: curriculumId,
          leafSet: leafSet,
          counted: log.counted.learns,
          corpus: corpus,
        );
        return _write(
          LearningCommandKind.unlearn,
          planUnlearnWrites(stamp, plan),
        );
      });

  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) => _gated((
    stamp,
    history,
  ) async {
    final targets = eventIds.toSet().toList();
    if (targets.isEmpty) return const CaptureResult.success();
    if (!targets.every(isUlid)) return _invalid;
    final log = await _log(stamp, history);
    // Validate every target before writing anything.
    final voids = <LearningEvent>[];
    final copies = <LearningEvent>[];
    for (final id in targets) {
      final e = log.byId[id];
      if (e == null) {
        return const CaptureResult.rejected(CaptureRejection.targetNotFound);
      }
      if (log.isLockIgnored(id)) {
        return const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget);
      }
      if (e.isLearn) {
        if (!log.isVoided(id)) voids.add(e);
        continue;
      }
      if (e.revertsActionId != null) {
        return const CaptureResult.rejected(CaptureRejection.undoIsFinal);
      }
      final t = log.byId[e.targetId];
      if (t == null || !t.isLearn) {
        return const CaptureResult.rejected(CaptureRejection.targetNotFound);
      }
      if (log.isVoided(t.id) && !copies.contains(t)) copies.add(t);
    }
    final ids = stamp.ids(voids.length + copies.length);
    var i = 0;
    final units = <WriteUnit>[];
    try {
      for (final e in voids) {
        units.add(
          WriteUnit([
            voidEventOf(stamp, ids[i++], e.id, revertsActionId: targets.first),
          ]),
        );
      }
      for (final t in copies) {
        final copy = copyOf(stamp, ids[i++], t);
        final amount = earnsPointsEntry(copy)
            ? await _pointsAmount(t.curriculumId!, t.stage)
            : null;
        units.add(learnUnit(copy, amount, stamp.nowUtc));
      }
      _validate(units);
    } on StorageFormatException {
      return _invalid;
    }
    return _write(LearningCommandKind.undo, units);
  });

  /// Governed writes pass the same [CaptureGate] as events (AD-36): the
  /// facade gates before delegating, so no [GovernedLearningCommands]
  /// implementation can write inside a lock.
  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) {
    final governed = _governed;
    if (governed == null) {
      throw UnimplementedError('applyGovernedChange (filled by DNI-470)');
    }
    return _gated((_, _) => governed.applyGovernedChange(action));
  }

  @override
  Future<CaptureResult> undoAction(String actionId) {
    final governed = _governed;
    if (governed == null) {
      throw UnimplementedError('undoAction (filled by DNI-470)');
    }
    return _gated((_, _) => governed.undoAction(actionId));
  }

  @override
  Future<CaptureResult> removeTrack(String curriculumId) {
    final governed = _governed;
    if (governed == null) {
      throw UnimplementedError('removeTrack (filled by DNI-476)');
    }
    return _gated((_, _) => governed.removeTrack(curriculumId));
  }

  @override
  Future<CaptureResult> reAddTrack(String curriculumId) {
    final governed = _governed;
    if (governed == null) {
      throw UnimplementedError('reAddTrack (filled by DNI-476)');
    }
    return _gated((_, _) => governed.reAddTrack(curriculumId));
  }

  /// The event failures, then the governed ones (AD-54 Recovery).
  @override
  Stream<List<PendingFailure>> watchPendingFailures() {
    final events = _dispatcher.watchPendingFailures();
    final governed = _governed;
    if (governed == null) return events;
    return _concatLatest(events, governed.watchPendingFailures());
  }

  @override
  Future<CaptureResult> retry(String pendingFailureId) =>
      _gated((stamp, history) async {
        final outcome = await _dispatcher.retry(pendingFailureId);
        if (outcome == null) {
          final governed = await _governed?.retry(pendingFailureId);
          return governed ??
              const CaptureResult.rejected(CaptureRejection.targetNotFound);
        }
        if (outcome.allRejected) {
          return const CaptureResult.rejected(CaptureRejection.notSaved);
        }
        _afterWrite(outcome);
        return CaptureResult.success(
          eventIds: outcome.eventIds,
          queued: outcome.queued,
        );
      });

  /// The post-write step of every command that saved (or queued) events,
  /// a first write or a retry: the AD-50 achievement latch over the learn
  /// events the write recorded (DNI-480). It runs in the background and
  /// never delays or fails the command; the latch retries its own
  /// failures.
  void _afterWrite(DispatchOutcome outcome) {
    final achievements = _achievements;
    if (achievements == null) return;
    unawaited(achievements.afterWrite(_scope, outcome.learnEventIds.toSet()));
  }

  /// Closes the pending-failure stream.
  Future<void> dispose() => _dispatcher.dispose();

  /// The latest list of [a] followed by the latest of [b], once both have
  /// delivered.
  static Stream<List<PendingFailure>> _concatLatest(
    Stream<List<PendingFailure>> a,
    Stream<List<PendingFailure>> b,
  ) {
    late final StreamController<List<PendingFailure>> out;
    StreamSubscription<List<PendingFailure>>? subA;
    StreamSubscription<List<PendingFailure>>? subB;
    List<PendingFailure>? latestA;
    List<PendingFailure>? latestB;
    void publish() {
      final x = latestA;
      final y = latestB;
      if (x != null && y != null) out.add(List.unmodifiable([...x, ...y]));
    }

    out = StreamController<List<PendingFailure>>(
      onListen: () {
        subA = a.listen((v) {
          latestA = v;
          publish();
        }, onError: out.addError);
        subB = b.listen((v) {
          latestB = v;
          publish();
        }, onError: out.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  /// Encodes every event once (AD-52 validation) before any write.
  static void _validate(List<WriteUnit> units) {
    for (final unit in units) {
      for (final e in unit.events) {
        e.toStorage();
      }
    }
  }
}
