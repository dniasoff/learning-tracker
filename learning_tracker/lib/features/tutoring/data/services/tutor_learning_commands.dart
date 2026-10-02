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
///   (`planUnlearn`, ruling B9).
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

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';
import 'package:learning_tracker/features/learning/domain/commands/unlearn_plan.dart';
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
  /// target-learner lock checks; [events] reads the talmid's complete event
  /// log; [corpus] a curriculum's ContentIndex corpus.
  TutorLearningCommands({
    required TutoredProfileSelection selection,
    required TutorWriteService service,
    required TutorWritePreflight preflight,
    required Future<List<LearningEvent>> Function() events,
    required Future<Corpus?> Function(String curriculumId) corpus,
    required UtcClock clock,
    required UlidSource newUlid,
  }) : _selection = selection,
       _service = service,
       _checks = preflight,
       _events = events,
       _corpus = corpus,
       _clock = clock,
       _newUlid = newUlid;

  final TutoredProfileSelection _selection;
  final TutorWriteService _service;
  final TutorWritePreflight _checks;
  final Future<List<LearningEvent>> Function() _events;
  final Future<Corpus?> Function(String) _corpus;
  final UtcClock _clock;
  final UlidSource _newUlid;

  static const _invalid = CaptureResult.rejected(CaptureRejection.invalid);

  final Map<String, (PendingFailure, List<_PlannedCall>)> _pending = {};
  final StreamController<List<PendingFailure>> _changes =
      StreamController<List<PendingFailure>>.broadcast();

  /// Releases the pending-failure feed.
  void dispose() => unawaited(_changes.close());

  // ── Preflight ──────────────────────────────────────────────────────────

  /// Runs [body] only when the grant allows editing, the device is online
  /// and the target learner is outside a lock — all checked before any
  /// callable is invoked.
  Future<CaptureResult> _preflight(
    Future<CaptureResult> Function(DateTime nowUtc, LearnerSettingsHistory h)
    body,
  ) async => switch (await _checks.check()) {
    TutorPreflightPassed(:final nowUtc, :final history) => body(
      nowUtc,
      history,
    ),
    TutorPreflightNoEditAccess() => _invalid,
    TutorPreflightOffline() => const CaptureResult.onlineRequired(),
    TutorPreflightLocked(:final window) => CaptureResult.locked(window),
  };

  List<String> _ids(DateTime nowUtc, int count) =>
      [for (var i = 0; i < count; i++) _newUlid(nowUtc)]..sort();

  // ── Dispatch ───────────────────────────────────────────────────────────

  /// Sends [calls] in order. Stops at the first failure: a retryable one
  /// (timeout, no network) parks it and every later call as ONE pending
  /// failure with a retry; any other maps to a rejection. Returns the
  /// result of what was written, or the refusal when nothing was.
  Future<CaptureResult> _dispatch(
    List<_PlannedCall> calls, {
    CaptureResult Function(TutorWriteFailure failure)? rejection,
    List<String> Function(List<(_PlannedCall, TutorLearningWritten)> written)?
    eventIdsOf,
  }) async {
    final written = <(_PlannedCall, TutorLearningWritten)>[];
    for (var i = 0; i < calls.length; i++) {
      final result = await calls[i].send();
      switch (result) {
        case TutorLearningWritten():
          written.add((calls[i], result));
          continue;
        case TutorWriteSuccess():
          written.add((calls[i], const TutorLearningWritten(actionId: '')));
          continue;
        case TutorWriteFailure():
          if (result.isRetryable) _park(calls.sublist(i), result);
          if (written.isNotEmpty) break;
          return result.isRetryable
              ? const CaptureResult.rejected(CaptureRejection.notSaved)
              : (rejection ?? _rejectionOf)(result);
      }
      break;
    }
    final ids =
        eventIdsOf?.call(written) ??
        [for (final (_, w) in written) ...w.eventIds];
    return CaptureResult.success(eventIds: ids);
  }

  static CaptureResult _rejectionOf(TutorWriteFailure failure) =>
      switch (failure.code) {
        'not-found' => const CaptureResult.rejected(
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
  }) => _preflight((now, history) async {
    // Epic 1: tutors record main-track learning, dated or before tracking.
    if (curriculumId.isEmpty ||
        source != LearningEvent.sourceMain ||
        dateState == DateState.catchUp) {
      return _invalid;
    }
    if (nodes.isNotEmpty && dateState != DateState.beforeTracking) {
      return _invalid;
    }
    if (stage != null && stage < 0) return _invalid;
    final leaves = refs.where((r) => r.isNotEmpty).toSet().toList();
    final nodeList = nodes.toSet().toList();
    if (leaves.length != refs.toSet().length) return _invalid;
    if (leaves.isEmpty && nodeList.isEmpty) {
      return const CaptureResult.success();
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
    return _dispatch([
      for (var start = 0; start < events.length; start += tutorCaptureChunkSize)
        _recordCall(
          events.sublist(
            start,
            (start + tutorCaptureChunkSize).clamp(0, events.length),
          ),
        ),
    ], eventIdsOf: (written) => [for (final (c, _) in written) ...c.eventIds]);
  });

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
      switch (failure.code) {
        'not-found' => const CaptureResult.rejected(
          CaptureRejection.targetNotFound,
        ),
        'invalid-argument' || 'failed-precondition' =>
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
    // Epic 1 tutor captures are main-track and dated or before tracking.
    if (fields == null ||
        fields.source != LearningEvent.sourceMain ||
        fields.dateState == DateState.catchUp) {
      return _invalid;
    }
    if (fields.sameAs(target)) return const CaptureResult.success();
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
      [
        _PlannedCall(
          ids,
          () => _service.replaceLearning(
            grantId: _selection.grantId,
            ownerUid: _selection.ownerUid,
            profileId: _selection.profileId,
            eventId: ids[0],
            targetId: targetId,
            replacement: copy,
          ),
        ),
      ],
      rejection: _correctionRejection,
      eventIdsOf: (_) => ids,
    );
  });

  @override
  Future<CaptureResult> unlearn(String curriculumId, Set<LeafRef> leafSet) =>
      _preflight((now, history) async {
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
        return _dispatch([
          for (var c = 0; c < chunkCount; c++)
            _unlearnCall(
              actionId: ids[c],
              curriculumId: curriculumId,
              leafSet: leaves.sublist(
                c * tutorUnlearnChunkSize,
                ((c + 1) * tutorUnlearnChunkSize).clamp(0, leaves.length),
              ),
              // The node plan rides with the first chunk only.
              nodeReissues: c == 0 ? reissues : const [],
            ),
        ]);
      });

  _PlannedCall _unlearnCall({
    required String actionId,
    required String curriculumId,
    required List<String> leafSet,
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
    return _dispatch([
      for (var i = 0; i < toVoid.length; i++) _voidCall(ids[i], toVoid[i]),
    ], rejection: _correctionRejection);
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
    return _preflight((_, _) async {
      final current = _pending.remove(pendingFailureId);
      if (current == null) return const CaptureResult.success();
      _emit();
      // A retry that fails again is parked again, so the feed re-announces
      // it with Retry.
      return _dispatch(current.$2);
    });
  }
}
