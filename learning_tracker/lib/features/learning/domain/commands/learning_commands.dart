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
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/features/learning/domain/commands/achievement_latch.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/child_redate_limit.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_chunker.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_dispatcher.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_source_check.dart';
import 'package:learning_tracker/features/learning/domain/commands/unlearn_plan.dart';

export 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart'
    show SubTrackDraft, SubTrackEdit;

/// How long a command waits for the AD-50 points amount before it falls
/// back to the default stage ladder, so an uncached or unreachable
/// `point_configs` read never blocks an offline capture (AC-9).
const Duration defaultPointsReadWait = Duration(seconds: 2);

/// How long a `skipRecorded` capture waits for the event log before it
/// writes the caller's refs as given, so an uncached or unreachable log
/// never blocks an offline capture (AC-9).
const Duration defaultRecordedReadWait = Duration(seconds: 2);

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

/// The fields of the replacement of [t] by [r] at [nowUtc], or null when
/// they are invalid (FR-4). The single rule both the owner commands and the
/// tutor commands (DNI-486) apply: a move to Before tracking clears
/// `learned_on`; an unchanged ref keeps the node `level`; `stage` is kept
/// only on the main source.
ResolvedReplacement? resolveReplacement(
  LearningEvent t,
  EventReplacement r,
  DateTime nowUtc,
  LearnerSettingsHistory history,
) {
  final source = r.source ?? t.source!;
  if (source != LearningEvent.sourceMain && !isUlid(source)) return null;
  final state = r.dateState ?? t.dateState!;
  final redate =
      (r.dateState != null && r.dateState != t.dateState) ||
      (r.learnedOn != null && r.learnedOn != t.learnedOn);
  final learnedOn = state == DateState.beforeTracking
      ? null
      : r.learnedOn ?? t.learnedOn ?? civilDate(nowUtc, history);
  if (learnedOn != null && !isCivilDate(learnedOn)) return null;
  final level = r.ref != null && r.ref != t.ref ? null : t.level;
  if (level != null && state != DateState.beforeTracking) return null;
  final ref = r.ref ?? t.ref!;
  if (ref.isEmpty) return null;
  if (r.stage != null && source != LearningEvent.sourceMain) return null;
  final stage = source == LearningEvent.sourceMain ? r.stage ?? t.stage : null;
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

/// Every learning write: events (AD-31) and governed changes (AD-38).
abstract interface class LearningCommands {
  /// Records [refs] (leaves) and [nodes] as learnt for [curriculumId].
  ///
  /// [nodes] is allowed only with [DateState.beforeTracking]; [source] is
  /// `'main'` or a sub-track ULID.
  ///
  /// One event is planned per ref, then per node, in the given order and
  /// with ascending ids, so the sorted union of a success's `eventIds` and
  /// `rejectedEventIds` lines up with [refs] followed by [nodes].
  ///
  /// With [skipRecorded] (Up to… and +1, DNI-501 AC-2) the command first
  /// re-reads the persisted event log and drops every ref already learnt
  /// in this track: for a sub-track [source], a counted `learn` event of
  /// that source covers it (AD-33 position); for `main`, any counted
  /// `learn` event of [curriculumId] covers it (AD-33 `schedulableRefs`).
  /// The dropped refs are returned in the success's `alreadyRecordedRefs`
  /// and the plan then lines up with the remaining refs. A log that cannot
  /// be read in time (offline, uncached) leaves [refs] as given: the
  /// caller's snapshot already excluded what it knew was recorded.
  /// [skipRecorded] captures of one learner run one at a time on this
  /// device, so each re-read sees the previous one's write and two quick
  /// captures of the same leaf never both pass the read. Across devices
  /// the log is append-only and offline-first (AD-31, AD-54): a leaf both
  /// record before either syncs is counted once by the engine and earns
  /// once (AD-50 `earningEventIds`).
  Future<CaptureResult> capture({
    required String curriculumId,
    List<LeafRef> refs = const [],
    List<NodeEntry> nodes = const [],
    required String source,
    required DateState dateState,
    CivilDate? learnedOn,
    int? stage,
    bool skipRecorded = false,
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

  /// Creates a sub-track (Story 2.1, AD-33/AD-38/AD-45): one queueable
  /// batch of the new `sub_tracks/{ulid}` doc and its change-log entry,
  /// every `before` null. [subTrackId] is the new doc ULID (minted when
  /// omitted). Rejected with the violated AD-45 rules before any write.
  /// [nextYearOf] names the school-year sub-track a detail's *Add next
  /// year* rolls over (Story 2.8): the create is refused
  /// (`rejected(targetNotFound)`) when that source is missing or tombstoned
  /// in the latest complete read, and is otherwise the same write, reported
  /// as that `subtrack_lifecycle` action instead of `create`.
  /// Implemented by `SubTrackCommands.createSubTrack`.
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
    String? nextYearOf,
  });

  /// Edits any field of sub-track [subTrackId] except `curriculum_id`;
  /// `ground` is replaced whole. Writes and logs only changed fields.
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit);

  /// Ends sub-track [subTrackId]: `ended_at` + `end_reason = ended`.
  Future<CaptureResult> endSubTrack(String subTrackId);

  /// Deletes sub-track [subTrackId] as a tombstone: `ended_at` +
  /// `end_reason = deleted`. No client `delete` is ever issued.
  Future<CaptureResult> deleteSubTrack(String subTrackId);

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

  /// AD-49 backup import (DNI-482): replays [input] onto this learner in
  /// order — settings, governed docs, sub-tracks, learn events with
  /// re-derived `pts_` entries, voids, then non-event records — under
  /// fresh ids (`backup_import_replay.dart`). A batch or chunk the server
  /// does not save is a "not saved — retry" [PendingFailure], listed in
  /// [BackupReplayResult.notSaved] and in [watchPendingFailures].
  Future<BackupReplayResult> importBackup(BackupReplayInput input);

  /// Queued writes the server rejected, live.
  Stream<List<PendingFailure>> watchPendingFailures();

  /// Retries the pending failure [pendingFailureId].
  Future<CaptureResult> retry(String pendingFailureId);

  /// Completes true when the queued sub-track change is accepted, false when
  /// the server refuses it and exposes it as a pending failure.
  Future<bool> whenSubTrackChangeConfirmed(String changeId);
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
    Duration recordedWait = defaultRecordedReadWait,
    GovernedLearningCommands? governed,
    SubTrackCommands? subTrackCommands,
    AchievementLatch? achievements,
    SubTrackSourceCheck? sourceCheck,
    BackupImportReplay? backupReplay,
  }) : _scope = scope,
       _achievements = achievements,
       _sourceCheck = sourceCheck,
       _backupReplay = backupReplay,
       _pointsWait = pointsWait,
       _recordedWait = recordedWait,
       _actor = actor,
       _reads = reads,
       _gate = gate,
       _analytics = analytics,
       _clock = clock,
       _newUlid = newUlid,
       _governed = governed,
       _subTrackCommands = subTrackCommands,
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
  final SubTrackSourceCheck? _sourceCheck;
  final SubTrackCommands? _subTrackCommands;
  final LearningWriteDispatcher _dispatcher;
  final Duration _pointsWait;
  final AchievementLatch? _achievements;
  final Duration _recordedWait;
  final BackupImportReplay? _backupReplay;

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
      rejectedEventIds: outcome.rejectedEventIds,
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

  /// The leaves of [curriculumId] already learnt in the track [source]
  /// per the persisted log judged at [stamp] (see `capture`'s
  /// `skipRecorded`), or null when the log or corpus cannot be read
  /// within the recorded wait.
  Future<Set<LeafRef>?> _recordedIn(
    String curriculumId,
    String source,
    CommandStamp stamp,
    LearnerSettingsHistory history,
  ) async {
    try {
      final (log, corpus) = await (
        _log(stamp, history),
        _reads.corpus(curriculumId),
      ).wait.timeout(_recordedWait);
      return {
        for (final e in log.counted.learns)
          if (e.curriculumId == curriculumId &&
              (source == LearningEvent.sourceMain || e.source == source))
            ...?(corpus == null
                ? (e.level == null && e.ref != null ? [e.ref!] : null)
                : coveredLeaves(e, corpus)),
      };
    } on Object {
      return null;
    }
  }

  static bool _validSource(String source) =>
      source == LearningEvent.sourceMain || isUlid(source);

  /// Whether [source] may name a learn event of [curriculumId]: `main`, or
  /// a live sub-track of that curriculum in this scope when a
  /// [SubTrackSourceCheck] is bound (AD-33). A check that throws or times
  /// out fails closed.
  Future<bool> _sourceAllowed(String curriculumId, String source) async {
    final check = _sourceCheck;
    if (source == LearningEvent.sourceMain || check == null) return true;
    try {
      return await check(curriculumId, source);
    } on Object {
      return false;
    }
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
    bool skipRecorded = false,
  }) {
    Future<CaptureResult> run() => _gated((stamp, history) async {
      if (curriculumId.isEmpty || !_validSource(source)) return _invalid;
      if (!await _sourceAllowed(curriculumId, source)) return _invalid;
      if (nodes.isNotEmpty && dateState != DateState.beforeTracking) {
        return _invalid;
      }
      if (stage != null && (source != LearningEvent.sourceMain || stage < 0)) {
        return _invalid;
      }
      var leaves = refs.where((r) => r.isNotEmpty).toSet().toList();
      final nodeList = nodes.toSet().toList();
      if (leaves.length != refs.toSet().length) return _invalid;
      var alreadyRecorded = const <LeafRef>[];
      if (skipRecorded && leaves.isNotEmpty) {
        // AC-2: a leaf another device (or an earlier capture) recorded while
        // the caller's picker was open is never written twice.
        final recorded = await _recordedIn(
          curriculumId,
          source,
          stamp,
          history,
        );
        if (recorded != null && recorded.isNotEmpty) {
          alreadyRecorded = [
            for (final r in leaves)
              if (recorded.contains(r)) r,
          ];
          leaves = [
            for (final r in leaves)
              if (!recorded.contains(r)) r,
          ];
        }
      }
      if (leaves.isEmpty && nodeList.isEmpty) {
        // Nothing to write.
        return CaptureResult.success(alreadyRecordedRefs: alreadyRecorded);
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
      var result = await _write(LearningCommandKind.capture, units);
      if (result is CaptureSuccess && alreadyRecorded.isNotEmpty) {
        result = CaptureResult.success(
          eventIds: result.eventIds,
          queued: result.queued,
          rejectedEventIds: result.rejectedEventIds,
          alreadyRecordedRefs: alreadyRecorded,
        );
      }
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
    return skipRecorded ? _oneRecordedCaptureAtATime(run) : run();
  }

  /// The last `skipRecorded` capture in flight per learner on this device.
  /// Static because `learningCommandsProvider` rebuilds the commands on
  /// unrelated changes while a capture may still be running.
  static final Map<LearnerScope, Completer<void>> _recordedCaptureTails = {};

  /// Runs [body] after every earlier `skipRecorded` capture of this
  /// learner has written (or failed), so its log re-read sees their events
  /// (AC-2: a leaf is never written twice by this device).
  Future<CaptureResult> _oneRecordedCaptureAtATime(
    Future<CaptureResult> Function() body,
  ) async {
    final previous = _recordedCaptureTails[_scope];
    final done = Completer<void>();
    _recordedCaptureTails[_scope] = done;
    try {
      if (previous != null) await previous.future;
      return await body();
    } finally {
      done.complete();
      if (identical(_recordedCaptureTails[_scope], done)) {
        _recordedCaptureTails.remove(_scope);
      }
    }
  }

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
    final newSource = replacement.source;
    if (newSource != null &&
        newSource != target.source &&
        !await _sourceAllowed(target.curriculumId!, newSource)) {
      return _invalid;
    }
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
  ) => resolveReplacement(t, r, stamp.nowUtc, history);

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

  /// Undo of a capture, a void or an un-learn (AD-31, AD-38; DNI-514
  /// AC-6, AC-7).
  ///
  /// Every target is validated before anything is written. The targets
  /// must all come from one command ([writtenByOneCommand]), else the call
  /// is [CaptureRejection.invalid]. A non-parent session may only undo
  /// learn events it recorded itself (the capture snackbar), else
  /// [CaptureRejection.undoNotOffered]. A learn still
  /// counted is voided, each void carrying `reverts_action_id` = the
  /// capture's first (lowest) event id, so the capture reads *Undone*
  /// everywhere and is never undone twice ([CaptureRejection.undoNotOffered]).
  /// A target already voided needs nothing. A lock-ignored member is
  /// skipped (never voided nor re-copied, so no undo launders it back into
  /// the count); a capture of only lock-ignored members offers no undo
  /// ([CaptureRejection.lockIgnoredTarget]). A void is undone by a learn
  /// copy of its target with `original_recorded_at = effectiveAt(target)`,
  /// unless such a copy is already counted. A void written by an undo is
  /// final ([CaptureRejection.undoIsFinal]).
  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) => _gated((
    stamp,
    history,
  ) async {
    final targets = eventIds.toSet().toList();
    if (targets.isEmpty) return const CaptureResult.success();
    if (!targets.every(isUlid)) return _invalid;
    final log = await _log(stamp, history);
    final undoId = targets.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    // Validate every target before writing anything.
    final members = <LearningEvent>[];
    for (final id in targets) {
      final e = log.byId[id];
      if (e == null) {
        return const CaptureResult.rejected(CaptureRejection.targetNotFound);
      }
      members.add(e);
    }
    // DNI-514 AC-1: undo from history is a parent action. Another session
    // may only take back learn events it recorded itself (the capture
    // snackbar's Undo, UX-DR-154).
    if (_actor.role != ActorRole.parent &&
        !members.every(
          (e) =>
              e.isLearn &&
              e.actor.uid == _actor.uid &&
              e.actor.role == _actor.role,
        )) {
      return const CaptureResult.rejected(CaptureRejection.undoNotOffered);
    }
    // One undo takes back exactly one capture (DNI-514 AC-6): events of
    // two commands would void both under one `reverts_action_id` and leave
    // the other capture's row offering Undo over voided events.
    if (!members.every((e) => writtenByOneCommand(e, members.first))) {
      return _invalid;
    }
    final voids = <LearningEvent>[];
    final copies = <LearningEvent>[];
    var lockIgnored = 0;
    for (final e in members) {
      final id = e.id;
      if (e.isVoid && e.revertsActionId != null) {
        return const CaptureResult.rejected(CaptureRejection.undoIsFinal);
      }
      if (log.isLockIgnored(id)) {
        lockIgnored++;
        continue;
      }
      if (e.isLearn) {
        if (!log.isVoided(id)) voids.add(e);
        continue;
      }
      final t = log.byId[e.targetId];
      if (t == null || !t.isLearn) {
        return const CaptureResult.rejected(CaptureRejection.targetNotFound);
      }
      if (log.isVoided(t.id) &&
          !log.isLockIgnored(t.id) &&
          !copies.contains(t) &&
          !_hasCountedCopy(log, t)) {
        copies.add(t);
      }
    }
    if (lockIgnored == targets.length) {
      return const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget);
    }
    if (log.byId.values.any((e) => e.isVoid && e.revertsActionId == undoId)) {
      return const CaptureResult.rejected(CaptureRejection.undoNotOffered);
    }
    final ids = stamp.ids(voids.length + copies.length);
    var i = 0;
    final units = <WriteUnit>[];
    try {
      for (final e in voids) {
        units.add(
          WriteUnit([
            voidEventOf(stamp, ids[i++], e.id, revertsActionId: undoId),
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

  /// Backup imports pass the [CaptureGate] like every other write (AD-36);
  /// a locked or unreadable gate writes nothing.
  @override
  Future<BackupReplayResult> importBackup(BackupReplayInput input) async {
    final replay = _backupReplay;
    if (replay == null) {
      throw UnimplementedError('importBackup (wired by DNI-482)');
    }
    BackupReplayResult? replayed;
    final result = await _gated((stamp, _) async {
      final out = replayed = await replay.replay(
        input,
        stamp: stamp,
        amount: _pointsAmount,
        afterEvents: _afterWrite,
      );
      return out.result;
    });
    return replayed ?? BackupReplayResult(result: result);
  }

  /// The event failures, then the governed ones, then the backup import's
  /// (AD-54 Recovery).
  @override
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
    String? nextYearOf,
  }) => _gated((_, _) async {
    final commands = _subTrackCommands;
    if (commands == null) return const CaptureResult.onlineRequired();
    return commands.createSubTrack(
      draft,
      subTrackId: subTrackId,
      nextYearOf: nextYearOf,
    );
  });

  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) =>
      _gated((_, _) async {
        final commands = _subTrackCommands;
        if (commands == null) return const CaptureResult.onlineRequired();
        return commands.editSubTrack(subTrackId, edit);
      });

  @override
  Future<CaptureResult> endSubTrack(String subTrackId) => _gated((_, _) async {
    final commands = _subTrackCommands;
    if (commands == null) return const CaptureResult.onlineRequired();
    return commands.endSubTrack(subTrackId);
  });

  @override
  Future<CaptureResult> deleteSubTrack(String subTrackId) =>
      _gated((_, _) async {
        final commands = _subTrackCommands;
        if (commands == null) return const CaptureResult.onlineRequired();
        return commands.deleteSubTrack(subTrackId);
      });

  /// The event failures, then the queued sub-track batches the server
  /// refused for good (DNI-497: a reorder or removal queued offline and
  /// later refused must reach its caller, which rolls it back).
  @override
  Stream<List<PendingFailure>> watchPendingFailures() {
    var latest = _dispatcher.watchPendingFailures();
    final governed = _governed;
    if (governed != null) {
      latest = _concatLatest(latest, governed.watchPendingFailures());
    }
    final subTracks = _subTrackCommands;
    if (subTracks != null) {
      latest = _concatLatest(latest, subTracks.watchPendingFailures());
    }
    final backup = _backupReplay;
    if (backup != null) {
      latest = _concatLatest(latest, backup.watchPendingFailures());
    }
    return latest;
  }

  @override
  Future<CaptureResult> retry(String pendingFailureId) => _gated((
    stamp,
    history,
  ) async {
    final subTracks = _subTrackCommands;
    if (subTracks != null && subTracks.hasPendingFailure(pendingFailureId)) {
      return subTracks.retry(pendingFailureId);
    }
    final outcome = await _dispatcher.retry(pendingFailureId);
    if (outcome == null) {
      final governed = await _governed?.retry(pendingFailureId);
      if (governed != null) return governed;
      if (subTracks != null) return subTracks.retry(pendingFailureId);
      final backup = await _backupReplay?.retry(
        pendingFailureId,
        afterEvents: _afterWrite,
      );
      return backup ??
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

  @override
  Future<bool> whenSubTrackChangeConfirmed(String changeId) =>
      _subTrackCommands?.whenConfirmed(changeId) ?? Future.value(true);

  /// The post-write step of every command that saved (or queued) events,
  /// a first write or a retry: the AD-50 achievement latch over the learn
  /// events the write recorded (DNI-480). It runs in the background and
  /// never delays or fails the command; the latch retries its own
  /// failures.
  ///
  /// The latch is monotonic, so it checks only what the server accepted:
  /// it waits for the write's acknowledgement (a queued write is checked
  /// when it reaches the server, a rejected one never), and the totals it
  /// reads leave out every event the server rejected.
  void _afterWrite(DispatchOutcome outcome) {
    final achievements = _achievements;
    if (achievements == null) return;
    unawaited(
      outcome.acknowledgedLearnEventIds.then(
        (ids) => achievements.afterWrite(
          _scope,
          ids.toSet(),
          unsaved: () => _dispatcher.unsavedEventIds,
        ),
      ),
    );
  }

  /// Closes the pending-failure streams.
  Future<void> dispose() async {
    await _dispatcher.dispose();
    await _backupReplay?.dispose();
  }

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

  /// Whether a counted learn other than [target] is its undo copy: the same
  /// learn fields at `effectiveAt(target)` (`copyOf`), so undoing the void
  /// again would only duplicate it.
  static bool _hasCountedCopy(LearningLogView log, LearningEvent target) =>
      log.byId.values.any(
        (e) =>
            e.isLearn &&
            e.id != target.id &&
            log.isCounted(e.id) &&
            effectiveAt(e) == effectiveAt(target) &&
            e.curriculumId == target.curriculumId &&
            e.ref == target.ref &&
            e.level == target.level &&
            e.source == target.source &&
            e.dateState == target.dateState &&
            e.learnedOn == target.learnedOn &&
            e.stage == target.stage,
      );

  /// Encodes every event once (AD-52 validation) before any write.
  static void _validate(List<WriteUnit> units) {
    for (final unit in units) {
      for (final e in unit.events) {
        e.toStorage();
      }
    }
  }
}
