/// The [LearningCommands] of a tutored session (Story 1.24, DNI-486).
///
/// A tutor never writes the talmid's Firestore tree: every learning write
/// is a Story 1.23 callable through [TutorWriteService] (AD-53). This class
/// gives the existing capture surfaces — the reader's Mark complete, Browse
/// free tick and Tick up to here, Mishna history corrections, and the
/// capture Undo / Retry feedback — the same [LearningCommands] seam the
/// owner uses, so each surface calls only the typed service methods:
///
/// * `capture` → [TutorWriteService.recordLearning];
/// * `voidEvent` / `undoEvents` → [TutorWriteService.voidLearning];
/// * `replace` → [TutorWriteService.replaceLearning];
/// * `unlearn` → [TutorWriteService.unlearn] with the shared AD-31 planner
///   (`planUnlearn`, ruling B9);
/// * Story 4.2 (DNI-510): a capture whose `source` is one of the talmid's
///   sub-tracks (the Learn row's *+1* / *Up to…*, the Browse free-tick
///   sheet) → [TutorWriteService.recordLearning] with that source; a Mishna
///   history correction of a main-track event to a sub-track source → ONE
///   [TutorWriteService.replaceLearning] whose copy carries the sub-track
///   source (the server checks the sub-track is live and writes the void
///   and the copy in one transaction);
/// * Story 4.2: `createSubTrack` / `editSubTrack` / `endSubTrack` /
///   `deleteSubTrack` → the typed `tutorUpsertSubTrack` service methods
///   (Story 4.1), one governed action each, its client ULIDs frozen in the
///   session ledger until a definitive receipt so a retried save replays.
///
/// Every command first checks, before any callable is invoked: the grant's
/// `can_edit_learning` (AD-53), a positive connectivity probe (online-only,
/// deviation #3 — nothing is queued) and the TARGET learner's [CaptureGate]
/// computed with that learner's settings (AD-36). A result is returned only
/// once the callable has answered, so nothing is shown before success (no
/// optimistic state). Every client ULID is allocated once, before the first
/// invocation: a call that times out becomes a pending failure whose retry
/// re-sends the identical payload, and the callable's idempotent replay
/// returns the stored result.
///
/// Governed main-track changes do not go through [applyGovernedChange]:
/// the tutor forms call the typed governed service methods directly.
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/append_ground.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart'
    show CaptureGesture;
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/unlearn_plan.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

/// Events per `tutorRecordLearning` call: each dated event writes its
/// `pts_` entry too, so 200 events stay well inside the callable's
/// 450-write transaction (AD-54).
const int tutorCaptureChunkSize = 200;

/// Leaves per `tutorUnlearn` call (the server accepts at most 450).
const int tutorUnlearnChunkSize = 200;

/// One tutor learning call, frozen with its client ULIDs so a retry
/// re-sends it unchanged.
typedef _TutorCall = Future<TutorWriteResult> Function();

/// A frozen call and the event ids it was planned with.
final class _PlannedCall {
  _PlannedCall(this.eventIds, this.send);

  final List<String> eventIds;
  final _TutorCall send;
}

/// Tutor [LearningCommands] bound to one tutored [selection].
final class TutorLearningCommands implements LearningCommands {
  /// Creates the commands. [preflight] runs the permission, online and
  /// device-user lock checks; [events] reads the talmid's complete event
  /// log; [corpus] a curriculum's ContentIndex corpus. [subTracks] reads
  /// the talmid's complete `sub_tracks` (null when unavailable — a
  /// sub-track command then answers `onlineRequired`); [ledger] freezes a
  /// sub-track action's client ULIDs until a definitive receipt (pass the
  /// session-wide one, so a retried save from a re-opened form replays).
  TutorLearningCommands({
    required TutoredProfileSelection selection,
    required TutorWriteService service,
    required TutorWritePreflight preflight,
    required Future<List<LearningEvent>> Function() events,
    required Future<Corpus?> Function(String curriculumId) corpus,
    required UtcClock clock,
    required UlidSource newUlid,
    Future<List<SubTrack>?> Function()? subTracks,
    TutorGovernedActionLedger? ledger,
  }) : _selection = selection,
       _service = service,
       _checks = preflight,
       _events = events,
       _corpus = corpus,
       _clock = clock,
       _newUlid = newUlid,
       _subTracks = subTracks,
       _ledger = ledger ?? TutorGovernedActionLedger();

  final TutoredProfileSelection _selection;
  final TutorWriteService _service;
  final TutorWritePreflight _checks;
  final Future<List<LearningEvent>> Function() _events;
  final Future<Corpus?> Function(String) _corpus;
  final UtcClock _clock;
  final UlidSource _newUlid;
  final Future<List<SubTrack>?> Function()? _subTracks;
  final TutorGovernedActionLedger _ledger;

  static const _invalid = CaptureResult.rejected(CaptureRejection.invalid);

  /// The parent turned off "Can edit learning" (AD-53; DNI-487 AC-6).
  static const _editingTurnedOff = CaptureResult.rejected(
    CaptureRejection.editingTurnedOff,
  );

  final Map<String, (PendingFailure, List<_PlannedCall>)> _pending = {};
  final StreamController<List<PendingFailure>> _changes =
      StreamController<List<PendingFailure>>.broadcast();

  /// Releases the pending-failure feed.
  void dispose() => unawaited(_changes.close());

  // ── Preflight ──────────────────────────────────────────────────────────

  /// Runs [body] only when the grant allows editing, the device is online
  /// and the device user is outside a lock — all checked before any
  /// callable is invoked.
  Future<CaptureResult> _preflight(
    Future<CaptureResult> Function(DateTime nowUtc, LearnerSettingsHistory h)
    body,
  ) async => switch (await _checks.check()) {
    TutorPreflightPassed(:final nowUtc, :final history) => body(
      nowUtc,
      history,
    ),
    // The control was enabled when tapped: the grant changed since.
    TutorPreflightNoEditAccess() => _editingTurnedOff,
    TutorPreflightOffline() => const CaptureResult.onlineRequired(),
    TutorPreflightTargetSettingsUnavailable() => const CaptureResult.rejected(
      CaptureRejection.notSaved,
    ),
    TutorPreflightLocked(:final window) => CaptureResult.locked(window),
  };

  List<String> _ids(DateTime nowUtc, int count) =>
      [for (var i = 0; i < count; i++) _newUlid(nowUtc)]..sort();

  // ── Dispatch ───────────────────────────────────────────────────────────

  /// Sends [calls] in order; the action they make up is all or nothing
  /// on screen. Only when EVERY call has succeeded is a success returned
  /// (and only then may a surface change). At the first failure the whole
  /// action — every frozen call, including any already written — is parked
  /// as ONE pending failure, so its outcome is reported explicitly and a
  /// retry re-sends the identical calls (same ULIDs and action ids): a call
  /// that did commit is replayed by the server, never duplicated. A
  /// retryable failure (timeout, no network) returns the AD-54 `notSaved`
  /// refusal; any other maps to a rejection. Nothing partial is returned.
  Future<CaptureResult> _dispatch(
    List<_PlannedCall> calls, {
    CaptureResult Function(TutorWriteFailure failure)? rejection,
    List<String> Function(List<(_PlannedCall, TutorLearningWritten)> written)?
    eventIdsOf,
    LearnerSettingsHistory? history,
  }) async {
    final written = <(_PlannedCall, TutorLearningWritten)>[];
    for (final call in calls) {
      final result = await call.send();
      switch (result) {
        case TutorLearningWritten():
          written.add((call, result));
        case TutorWriteSuccess():
          written.add((call, const TutorLearningWritten(actionId: '')));
        case TutorWriteFailure():
          // A single call that was refused outright wrote nothing and has
          // nothing to retry; anything else — a lost answer, or a refusal
          // after part of the action was written — stays pending.
          if (result.isRetryable || written.isNotEmpty) _park(calls, result);
          return result.isRetryable
              ? const CaptureResult.rejected(CaptureRejection.notSaved)
              : (rejection ?? _rejectionOf)(result);
      }
    }
    final ids =
        eventIdsOf?.call(written) ??
        [for (final (_, w) in written) ...w.eventIds];
    return CaptureResult.success(
      eventIds: ids,
      keptNotCounted: history == null
          ? const []
          : [
              // AD-36 / AC-7: a call that started before the learner's lock
              // may be stamped inside it. The server keeps its events; they
              // are not counted.
              for (final (c, w) in written)
                if (w.recordedAt case final at? when _checks.stampedInLock(at))
                  ...c.eventIds,
            ],
    );
  }

  static CaptureResult _rejectionOf(TutorWriteFailure failure) =>
      switch (failure) {
        TutorWriteEditingTurnedOff() => _editingTurnedOff,
        TutorWriteFailure(code: 'not-found') => const CaptureResult.rejected(
          CaptureRejection.targetNotFound,
        ),
        _ => _invalid,
      };

  void _park(List<_PlannedCall> calls, TutorWriteFailure failure) {
    final id = _newUlid(_clock().toUtc());
    _pending[id] = (
      PendingFailure(
        id: id,
        eventIds: [for (final c in calls) ...c.eventIds],
        changeIds: const [],
        reason: _reasonOf(failure.code),
      ),
      calls,
    );
    _emit();
  }

  static PendingFailureReason _reasonOf(String? code) => switch (code) {
    'permission-denied' => PendingFailureReason.permissionDenied,
    'invalid-argument' => PendingFailureReason.invalidArgument,
    'failed-precondition' => PendingFailureReason.failedPrecondition,
    _ => PendingFailureReason.other,
  };

  void _emit() {
    if (_changes.isClosed) return;
    _changes.add(_pendingList);
  }

  List<PendingFailure> get _pendingList =>
      List.unmodifiable([for (final (f, _) in _pending.values) f]);

  // ── Commands ───────────────────────────────────────────────────────────

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
    CaptureGesture gesture = CaptureGesture.plusOne,
    int skippedCount = 0,
    int taps = 1,
  }) => _preflight((now, history) async {
    // Epic 1: tutors record main-track learning, dated or before tracking.
    // Story 4.2 (AC-1): or the talmid's sub-track learning — the Story 4.1
    // contract: a dated leaf event with no stage.
    if (curriculumId.isEmpty || dateState == DateState.catchUp) {
      return _invalid;
    }
    final onSubTrack = source != LearningEvent.sourceMain;
    if (onSubTrack &&
        (!isUlid(source) ||
            dateState != DateState.dated ||
            nodes.isNotEmpty ||
            stage != null)) {
      return _invalid;
    }
    if (nodes.isNotEmpty && dateState != DateState.beforeTracking) {
      return _invalid;
    }
    if (stage != null && stage < 0) return _invalid;
    var leaves = refs.where((r) => r.isNotEmpty).toSet().toList();
    final nodeList = nodes.toSet().toList();
    if (leaves.length != refs.toSet().length) return _invalid;
    var alreadyRecorded = const <LeafRef>[];
    if (skipRecorded && leaves.isNotEmpty) {
      // DNI-501 AC-2 on a tutor device: a leaf the log already records in
      // this track is never written twice.
      final recorded = await _recordedIn(curriculumId, source, now, history);
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
      return CaptureResult.success(alreadyRecordedRefs: alreadyRecorded);
    }
    String? day;
    if (dateState == DateState.dated) {
      day = learnedOn ?? civilDate(now, history);
      if (!isCivilDate(day)) return _invalid;
    }
    final ids = _ids(now, leaves.length + nodeList.length);
    var i = 0;
    final events = [
      for (final ref in leaves)
        TutorLearnEvent(
          id: ids[i++],
          curriculumId: curriculumId,
          ref: ref,
          dateState: dateState,
          learnedOn: day,
          stage: stage,
          source: source,
        ),
      for (final node in nodeList)
        TutorLearnEvent(
          id: ids[i++],
          curriculumId: curriculumId,
          ref: node.ref,
          level: node.level,
          dateState: dateState,
          stage: stage,
        ),
    ];
    final result = await _dispatch(
      [
        for (
          var start = 0;
          start < events.length;
          start += tutorCaptureChunkSize
        )
          _recordCall(
            events.sublist(
              start,
              (start + tutorCaptureChunkSize).clamp(0, events.length),
            ),
          ),
      ],
      eventIdsOf: (written) => [for (final (c, _) in written) ...c.eventIds],
      history: history,
    );
    if (result case CaptureSuccess(
      :final eventIds,
      :final keptNotCounted,
    ) when alreadyRecorded.isNotEmpty) {
      return CaptureResult.success(
        eventIds: eventIds,
        keptNotCounted: keptNotCounted,
        alreadyRecordedRefs: alreadyRecorded,
      );
    }
    return result;
  });

  @override
  Future<CaptureResult> recordCatchUp(CatchUpAction action) async =>
      const CaptureResult.rejected(CaptureRejection.invalid);

  /// The leaves of [curriculumId] the talmid's log already records in the
  /// track [source] (see `capture`'s `skipRecorded`): for a sub-track, its
  /// counted learn events; for `main`, any counted learn event of the
  /// curriculum. Null when the log or the corpus cannot be read.
  Future<Set<LeafRef>?> _recordedIn(
    String curriculumId,
    String source,
    DateTime now,
    LearnerSettingsHistory history,
  ) async {
    try {
      final (log, corpus) = await (
        _log(now, history),
        _corpus(curriculumId),
      ).wait.timeout(_readWait);
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

  /// How long a tutor command waits for the talmid's log or sub-tracks.
  static const Duration _readWait = Duration(seconds: 5);

  _PlannedCall _recordCall(List<TutorLearnEvent> chunk) => _PlannedCall(
    [for (final e in chunk) e.id],
    () => _service.recordLearning(
      grantId: _selection.grantId,
      ownerUid: _selection.ownerUid,
      profileId: _selection.profileId,
      actionId: chunk.first.id,
      events: chunk,
    ),
  );

  /// ONE `tutorVoidLearning` replace: the void [ids] `[0]` of [targetId]
  /// and its corrected [copy] (`ids[1]`), committed together.
  _PlannedCall _replaceCall(
    List<String> ids,
    String targetId,
    TutorLearnEvent copy,
  ) => _PlannedCall(
    ids,
    () => _service.replaceLearning(
      grantId: _selection.grantId,
      ownerUid: _selection.ownerUid,
      profileId: _selection.profileId,
      eventId: ids[0],
      targetId: targetId,
      replacement: copy,
    ),
  );

  _PlannedCall _voidCall(String voidId, String targetId) => _PlannedCall(
    [voidId],
    () => _service.voidLearning(
      grantId: _selection.grantId,
      ownerUid: _selection.ownerUid,
      profileId: _selection.profileId,
      eventId: voidId,
      targetId: targetId,
    ),
  );

  Future<LearningLogView> _log(DateTime now, LearnerSettingsHistory h) =>
      _events().then((events) => LearningLogView.of(events, h, now));

  @override
  Future<CaptureResult> voidEvent(String targetId) => _preflight((
    now,
    history,
  ) async {
    if (!isUlid(targetId)) return _invalid;
    final log = await _log(now, history);
    final target = log.byId[targetId];
    if (target != null) {
      if (target.isVoid) {
        return const CaptureResult.rejected(
          CaptureRejection.voidTargetNotLearn,
        );
      }
      if (log.isLockIgnored(targetId)) {
        return const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget);
      }
      if (log.isVoided(targetId)) return const CaptureResult.success();
    }
    final voidId = _ids(now, 1).single;
    return _dispatch(
      [_voidCall(voidId, targetId)],
      rejection: _correctionRejection,
      eventIdsOf: (_) => [voidId],
    );
  });

  /// A correction the server refused: the AD-31 void-target rule, a
  /// missing target, or anything else (the row stays as it was).
  static CaptureResult _correctionRejection(TutorWriteFailure failure) =>
      switch (failure) {
        TutorWriteEditingTurnedOff() => _editingTurnedOff,
        TutorWriteFailure(code: 'not-found') => const CaptureResult.rejected(
          CaptureRejection.targetNotFound,
        ),
        TutorWriteFailure(code: 'invalid-argument' || 'failed-precondition') =>
          const CaptureResult.rejected(CaptureRejection.voidTargetNotLearn),
        _ => _invalid,
      };

  @override
  Future<CaptureResult> replace(
    String targetId,
    EventReplacement replacement,
  ) => _preflight((now, history) async {
    final log = await _log(now, history);
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
    final fields = resolveReplacement(target, replacement, now, history);
    // Epic 1 tutor captures are main-track and dated or before tracking;
    // Story 4.1 keeps a tutor's corrections to main-track events.
    if (fields == null ||
        target.source != LearningEvent.sourceMain ||
        fields.dateState == DateState.catchUp) {
      return _invalid;
    }
    if (fields.sameAs(target)) return const CaptureResult.success();
    if (fields.source != LearningEvent.sourceMain) {
      return _correctToSubTrack(targetId, target, fields, now, history);
    }
    final ids = _ids(now, 2);
    final copy = TutorLearnEvent(
      id: ids[1],
      curriculumId: target.curriculumId!,
      ref: fields.ref,
      level: fields.level,
      dateState: fields.dateState,
      learnedOn: fields.learnedOn,
      stage: fields.stage,
    );
    return _dispatch(
      [_replaceCall(ids, targetId, copy)],
      rejection: _correctionRejection,
      eventIdsOf: (_) => ids,
      history: history,
    );
  });

  /// Story 4.2 (AC-1): *Correct source* of the main-track event [targetId]
  /// to one of the talmid's sub-tracks: ONE `replaceLearning` call whose
  /// copy carries the sub-track source (a dated leaf event, no stage, its
  /// `learned_on` kept). The server validates that the sub-track is live
  /// and on the target's curriculum and commits the void and the copy in
  /// one transaction, so a refused or failed correction leaves the
  /// original counted — never a void without its replacement. Both ULIDs
  /// are frozen before the call; a retry replays the stored result.
  Future<CaptureResult> _correctToSubTrack(
    String targetId,
    LearningEvent target,
    ResolvedReplacement fields,
    DateTime now,
    LearnerSettingsHistory history,
  ) async {
    if (!isUlid(fields.source) ||
        fields.dateState != DateState.dated ||
        fields.level != null ||
        target.curriculumId == null) {
      return _invalid;
    }
    final ids = _ids(now, 2);
    final copy = TutorLearnEvent(
      id: ids[1],
      curriculumId: target.curriculumId!,
      ref: fields.ref,
      dateState: DateState.dated,
      learnedOn: fields.learnedOn,
      source: fields.source,
    );
    return _dispatch(
      [_replaceCall(ids, targetId, copy)],
      rejection: _correctionRejection,
      eventIdsOf: (_) => ids,
      history: history,
    );
  }

  @override
  Future<CaptureResult> unlearn(
    String curriculumId,
    Set<LeafRef> leafSet,
  ) => _preflight((now, history) async {
    if (leafSet.isEmpty) return const CaptureResult.success();
    final corpus = await _corpus(curriculumId);
    if (corpus == null) return _invalid;
    final log = await _log(now, history);
    final plan = planUnlearn(
      curriculumId: curriculumId,
      leafSet: leafSet,
      counted: log.counted.learns,
      corpus: corpus,
    );
    if (plan.isEmpty) return const CaptureResult.success();
    final leaves = leafSet.toList();
    final chunkCount = (leaves.length / tutorUnlearnChunkSize).ceil();
    final reissueCount = plan.nodes.fold<int>(
      0,
      (n, node) => n + node.reissues.length,
    );
    final ids = _ids(now, chunkCount + reissueCount);
    var r = chunkCount;
    final reissues = [
      for (final node in plan.nodes)
        TutorNodeReissue(
          targetEventId: node.target.id,
          reissues: [
            for (final entry in node.reissues)
              (eventId: ids[r++], ref: entry.ref, level: entry.level),
          ],
        ),
    ];
    // AD-36 / AC-7: the server voids exactly the leaf events the engine
    // COUNTS (`plan.leafVoids`), never a stored but lock-ignored event
    // that shares a ref — it cannot evaluate the lock predicate itself.
    final leafEventsByRef = <String, List<String>>{};
    for (final e in plan.leafVoids) {
      // Epic 1 tutors un-learn main-track learning only (as the server).
      if (e.source != LearningEvent.sourceMain) continue;
      (leafEventsByRef[e.ref!] ??= []).add(e.id);
    }
    return _dispatch([
      for (var c = 0; c < chunkCount; c++)
        if (leaves.sublist(
              c * tutorUnlearnChunkSize,
              ((c + 1) * tutorUnlearnChunkSize).clamp(0, leaves.length),
            )
            case final chunk
            when c == 0 || chunk.any((ref) => leafEventsByRef.containsKey(ref)))
          _unlearnCall(
            actionId: ids[c],
            curriculumId: curriculumId,
            leafSet: chunk,
            leafEventIds: [for (final ref in chunk) ...?leafEventsByRef[ref]],
            // The node plan rides with the first chunk only.
            nodeReissues: c == 0 ? reissues : const [],
          ),
    ], history: history);
  });

  _PlannedCall _unlearnCall({
    required String actionId,
    required String curriculumId,
    required List<String> leafSet,
    required List<String> leafEventIds,
    required List<TutorNodeReissue> nodeReissues,
  }) => _PlannedCall(
    [
      for (final n in nodeReissues) ...[for (final r in n.reissues) r.eventId],
    ],
    () => _service.unlearn(
      grantId: _selection.grantId,
      ownerUid: _selection.ownerUid,
      profileId: _selection.profileId,
      actionId: actionId,
      curriculumId: curriculumId,
      leafSet: leafSet,
      leafEventIds: leafEventIds,
      nodeReissues: nodeReissues,
    ),
  );

  /// Undo of a tutor capture voids each of its learn events. An id the
  /// log does not hold yet is one this session just wrote (the read
  /// mirror lags the callable), so it is voided too; the server treats a
  /// void of an absent target as no error (AD-31). Re-issuing voided
  /// events (undo of a void or un-learn) is owner-only.
  @override
  Future<CaptureResult> undoEvents(List<String> eventIds) => _preflight((
    now,
    history,
  ) async {
    final targets = eventIds.toSet().toList();
    if (targets.isEmpty) return const CaptureResult.success();
    if (!targets.every(isUlid)) return _invalid;
    final log = await _log(now, history);
    final toVoid = <String>[];
    for (final id in targets) {
      final e = log.byId[id];
      if (e == null) {
        toVoid.add(id);
        continue;
      }
      if (log.isLockIgnored(id)) {
        return const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget);
      }
      if (!e.isLearn) {
        return const CaptureResult.rejected(CaptureRejection.undoNotOffered);
      }
      if (!log.isVoided(id)) toVoid.add(id);
    }
    if (toVoid.isEmpty) return const CaptureResult.success();
    final ids = _ids(now, toVoid.length);
    return _dispatch(
      [for (var i = 0; i < toVoid.length; i++) _voidCall(ids[i], toVoid[i])],
      rejection: _correctionRejection,
      history: history,
    );
  });

  /// Tutor governed edits use the typed governed service methods.
  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) async =>
      _invalid;

  /// Tutor governed edits use the typed governed service methods.
  @override
  Future<CaptureResult> undoAction(String actionId) async => _invalid;

  @override
  Stream<List<PendingFailure>> watchPendingFailures() =>
      Stream<List<PendingFailure>>.multi((controller) {
        controller.add(_pendingList);
        final sub = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  /// Re-sends the parked calls of [pendingFailureId] unchanged (same ULIDs)
  /// after the same preflight. A refused preflight leaves it pending.
  @override
  Future<CaptureResult> retry(String pendingFailureId) async {
    final entry = _pending[pendingFailureId];
    if (entry == null) {
      return const CaptureResult.rejected(CaptureRejection.targetNotFound);
    }
    return _preflight((_, history) async {
      final current = _pending.remove(pendingFailureId);
      if (current == null) return const CaptureResult.success();
      _emit();
      // A retry that fails again is parked again, so the feed re-announces
      // it with Retry.
      return _dispatch(current.$2, history: history);
    });
  }

  // Track lifecycle is an owner-only command. Keep the shared interface
  // complete while refusing to expose those operations in a tutor session.
  @override
  Future<CaptureResult> removeTrack(String curriculumId) async => _invalid;

  @override
  Future<CaptureResult> reAddTrack(String curriculumId) async => _invalid;

  // ── Sub-tracks (Story 4.2, DNI-510) ──────────────────────────────────────
  //
  // The shared Epic 2 forms, detail and ground picker call these; each is
  // ONE typed `tutorUpsertSubTrack` call (Story 4.1) after the preflight,
  // and its result comes only from the callable's answer: nothing is
  // queued and nothing shows as saved before success (AD-53). The AD-45
  // limits are checked here first against the talmid's sub-tracks, so the
  // forms get the same violations as on the owner path; the server
  // (`writeWithChangeLog`) re-validates and is the final authority, also
  // for the calendar-program rule and the grant.

  /// Creates a sub-track for the talmid. [subTrackId] is the new doc ULID
  /// (frozen per draft in the session ledger when omitted); [nextYearOf]
  /// names the school-year sub-track an *Add next year* rolls over — the
  /// create is refused (`targetNotFound`) when it is missing or ended.
  @override
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
    String? nextYearOf,
  }) => _preflight((now, history) async {
    if (subTrackId != null && !isUlid(subTrackId)) return _invalid;
    final tracks = await _readSubTracks();
    if (tracks == null) return const CaptureResult.onlineRequired();
    if (nextYearOf != null) {
      final source = _findSubTrack(tracks, nextYearOf);
      if (source == null || source.isEnded) {
        return const CaptureResult.rejected(CaptureRejection.targetNotFound);
      }
    }
    final fingerprint =
        tutorGovernedActionFingerprint('tutorUpsertSubTrack:create', {
          'profileId': _selection.profileId,
          'subTrackId': subTrackId,
          'nextYearOf': nextYearOf,
          'fields': SubTrackCommands.intentFieldsOf(_draftTrack('', draft)),
        });
    final id = subTrackId ?? _ledger.reserve(fingerprint, () => _newUlid(now));
    final candidate = _draftTrack(id, draft);
    final refused = await _violations(candidate, null, tracks, now, history);
    if (refused != null) return refused;
    return _governedSubTrack(
      fingerprint,
      () => _service.createSubTrack(
        grantId: _selection.grantId,
        ownerUid: _selection.ownerUid,
        profileId: _selection.profileId,
        subTrackId: id,
        draft: draft,
        nextYear: nextYearOf != null,
      ),
    );
  });

  /// Edits the talmid's sub-track [subTrackId]: any field but
  /// `curriculum_id`; `ground` replaced whole (reorder, remove) or, for an
  /// [SubTrackEdit.appendGround] edit (the ground picker), the picked nodes
  /// appended to the latest stored ground in ContentIndex order. An edit
  /// that changes nothing calls nothing.
  @override
  Future<CaptureResult> editSubTrack(String subTrackId, SubTrackEdit edit) =>
      _preflight((now, history) async {
        final tracks = await _readSubTracks();
        if (tracks == null) return const CaptureResult.onlineRequired();
        final current = _findSubTrack(tracks, subTrackId);
        if (current == null) {
          return const CaptureResult.rejected(CaptureRejection.targetNotFound);
        }
        if (current.isEnded) return _invalid;
        var effective = edit;
        final picked = edit.appendGround;
        if (picked != null) {
          if (edit.ground != null) return _invalid;
          final corpus = await _corpus(current.curriculumId);
          if (corpus == null) return _invalid;
          final foreign = [
            for (final node in picked)
              if (corpus.curriculumId != current.curriculumId ||
                  !corpusHoldsNode(corpus, node))
                SubTrackViolation(
                  SubTrackLimit.crossCurriculumGround,
                  subject: node.ref,
                ),
          ];
          if (foreign.isNotEmpty) {
            return CaptureResult.rejected(
              CaptureRejection.invalid,
              violations: foreign,
            );
          }
          effective = _withGround(edit, [
            ...current.ground,
            ...groundToAppend(
              current: current.ground,
              selected: picked,
              corpus: corpus,
            ),
          ]);
        }
        final candidate = SubTrackCommands.applyEdit(current, effective);
        final before = SubTrackCommands.intentFieldsOf(current);
        final after = SubTrackCommands.intentFieldsOf(candidate);
        final changed = <String, Object?>{
          for (final MapEntry(:key, :value) in after.entries)
            if (!storageValueEquals(before[key], value)) key: value,
        };
        if (changed.isEmpty) return const CaptureResult.success();
        final refused = await _violations(
          candidate,
          current,
          tracks,
          now,
          history,
        );
        if (refused != null) return refused;
        final fingerprint =
            tutorGovernedActionFingerprint('tutorUpsertSubTrack:edit', {
              'profileId': _selection.profileId,
              'subTrackId': subTrackId,
              'changed': changed,
            });
        final actionId = _ledger.reserve(fingerprint, () => _newUlid(now));
        return _governedSubTrack(
          fingerprint,
          () => _service.editSubTrack(
            grantId: _selection.grantId,
            ownerUid: _selection.ownerUid,
            profileId: _selection.profileId,
            current: current,
            edit: effective,
            actionId: actionId,
          ),
        );
      });

  /// Ends the talmid's sub-track [subTrackId] (`end_reason = ended`).
  @override
  Future<CaptureResult> endSubTrack(String subTrackId) =>
      _tombstone(subTrackId, delete: false);

  /// Deletes the talmid's sub-track [subTrackId] as a tombstone
  /// (`end_reason = deleted`); its learning events stay.
  @override
  Future<CaptureResult> deleteSubTrack(String subTrackId) =>
      _tombstone(subTrackId, delete: true);

  Future<CaptureResult> _tombstone(String subTrackId, {required bool delete}) =>
      _preflight((now, _) async {
        final tracks = await _readSubTracks();
        if (tracks == null) return const CaptureResult.onlineRequired();
        final current = _findSubTrack(tracks, subTrackId);
        if (current == null) {
          return const CaptureResult.rejected(CaptureRejection.targetNotFound);
        }
        // Already ended: nothing to write (the server would no-op too).
        if (current.isEnded) return const CaptureResult.success();
        final op = delete ? 'delete' : 'end';
        final fingerprint = tutorGovernedActionFingerprint(
          'tutorUpsertSubTrack:$op',
          {'profileId': _selection.profileId, 'subTrackId': subTrackId},
        );
        final actionId = _ledger.reserve(fingerprint, () => _newUlid(now));
        return _governedSubTrack(
          fingerprint,
          () => delete
              ? _service.deleteSubTrack(
                  grantId: _selection.grantId,
                  ownerUid: _selection.ownerUid,
                  profileId: _selection.profileId,
                  subTrack: current,
                  actionId: actionId,
                )
              : _service.endSubTrack(
                  grantId: _selection.grantId,
                  ownerUid: _selection.ownerUid,
                  profileId: _selection.profileId,
                  subTrack: current,
                  actionId: actionId,
                ),
        );
      });

  /// The talmid's complete `sub_tracks` read, or null when it cannot be
  /// read in time (or no reader is bound).
  Future<List<SubTrack>?> _readSubTracks() async {
    final read = _subTracks;
    if (read == null) return null;
    try {
      return await read().timeout(_readWait);
    } on Object {
      return null;
    }
  }

  static SubTrack? _findSubTrack(List<SubTrack> tracks, String id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  static SubTrack _draftTrack(String id, SubTrackDraft draft) => SubTrack(
    id: id,
    curriculumId: draft.curriculumId,
    name: draft.name,
    type: draft.type,
    academicYear: draft.academicYear,
    windowStart: draft.windowStart,
    windowEnd: draft.windowEnd,
    ratePerWeek: draft.ratePerWeek,
    weeksPerYear: draft.weeksPerYear,
    learnsOnShabbos: draft.learnsOnShabbos,
    ground: draft.ground,
    lastChangeId: id,
  );

  /// [edit] with its `ground` replaced by [ground] and no append.
  static SubTrackEdit _withGround(SubTrackEdit edit, List<NodeEntry> ground) =>
      SubTrackEdit(
        name: edit.name,
        type: edit.type,
        academicYear: edit.academicYear,
        clearAcademicYear: edit.clearAcademicYear,
        windowStart: edit.windowStart,
        windowEnd: edit.windowEnd,
        clearWindowEnd: edit.clearWindowEnd,
        ratePerWeek: edit.ratePerWeek,
        weeksPerYear: edit.weeksPerYear,
        learnsOnShabbos: edit.learnsOnShabbos,
        ground: ground,
      );

  /// The AD-45 refusal of writing [candidate] over [prior] (null: a
  /// create) among the talmid's [tracks], or null. The ground's curriculum
  /// is checked when its corpus is readable; the calendar-program rule is
  /// left to the server.
  Future<CaptureResult?> _violations(
    SubTrack candidate,
    SubTrack? prior,
    List<SubTrack> tracks,
    DateTime now,
    LearnerSettingsHistory history,
  ) async {
    Corpus? corpus;
    try {
      corpus = await _corpus(candidate.curriculumId);
    } on Object {
      corpus = null;
    }
    final violations = [
      ...subTrackIntentViolations(candidate, corpus: corpus),
      ...subTrackLimitViolations(
        candidate: candidate,
        prior: prior,
        siblings: tracks,
        today: civilDate(now, history),
        calendarProgramId: null,
      ),
    ];
    if (violations.isEmpty) return null;
    return CaptureResult.rejected(
      CaptureRejection.invalid,
      violations: violations,
    );
  }

  /// Sends one sub-track action and maps its answer: success only from a
  /// validated receipt; a retryable failure keeps the action's ULIDs frozen
  /// (a re-tapped Save replays it) and answers `notSaved`; any definitive
  /// answer releases them.
  Future<CaptureResult> _governedSubTrack(
    String fingerprint,
    Future<TutorWriteResult> Function() send,
  ) async {
    final result = await send();
    switch (result) {
      case TutorGovernedWritten(:final actionId, :final changeIds):
        _ledger.release(fingerprint);
        return CaptureResult.success(changeIds: changeIds, actionId: actionId);
      case TutorWriteSuccess():
        _ledger.release(fingerprint);
        return const CaptureResult.success();
      case TutorWriteFailure():
        if (result.isRetryable) {
          return const CaptureResult.rejected(CaptureRejection.notSaved);
        }
        _ledger.release(fingerprint);
        return _rejectionOf(result);
    }
  }

  /// A tutor write is never queued (AD-53 online-only): nothing awaits.
  @override
  Future<bool> whenSubTrackChangeConfirmed(String changeId) async => true;

  // Backup import is an owner-only operation; a tutor session cannot replay
  // a backup into the learner's account.
  @override
  Future<BackupReplayResult> importBackup(BackupReplayInput input) async =>
      const BackupReplayResult(result: _invalid);
}
