/// The governed sub-track lifecycle commands (Story 2.1 / DNI-492):
/// `createSubTrack`, `editSubTrack`, `endSubTrack` and `deleteSubTrack`.
///
/// [SubTrackCommands] is the per-concern collaborator behind
/// `LearningCommands` (orchestrator merge-hotspot ruling: the facade
/// delegates one line per command). The facade binds it to one
/// `LearnerScope` and the session actor and runs `CaptureGate` before
/// delegating; this class does neither.
///
/// Every command is one AD-38 owner batch through
/// `SubTrackRepository.applyGovernedChange`: a field-level
/// `set(merge: true)` of the changed fields plus `last_change_id` on
/// `sub_tracks/{id}`, and one `change_log` entry (`entity = subTrack`,
/// `entity_id` = the doc ULID, `before`/`after` keyed
/// `sub_tracks/{id}.{field}`). That is 2 writes and 2 Rules access calls,
/// inside the AD-54 budget, and it queues offline.
///
/// - **Create** (ruling B6): a fresh client-ULID doc written by that same
///   batch with every `before` null. It never claims the create; only
///   `writeWithChangeLog` does that, server-side.
/// - **Edit**: any field except `curriculum_id` (immutable, AD-38); `ground`
///   is replaced as a whole ordered list. Only changed fields are written
///   and logged; an edit that changes nothing writes nothing.
/// - **End / delete**: an `ended_at` + `end_reason` tombstone (`ended` /
///   `deleted`). No client `delete` is ever issued. Ending an already-ended
///   sub-track writes nothing.
/// - **Validation** (AD-45, AC-3..AC-5) runs before any write against the
///   complete sub-track read, the curriculum's live calendar program and,
///   when available, its corpus; a failure is
///   `CaptureResult.rejected(invalid, violations: ...)` naming each rule.
/// - **Offline** (AC-6): the write is applied to the local cache at once;
///   when the server has not acknowledged within [SubTrackCommands.ackTimeout]
///   the command returns `success(queued: true)`. A queued batch the server
///   later refuses for good becomes a [PendingFailure] ("not saved —
///   retry"); [SubTrackCommands.retry] re-sends the identical batch.
///
/// Imports only `lib/domain/learner_state/**`, sibling command files and
/// `dart:` (C0 AC-1).
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';

/// The intent of a new sub-track (AD-52 fields; `rate_per_week` in the
/// curriculum's leaf units, dates `YYYY-MM-DD` in the learner's time zone).
final class SubTrackDraft {
  /// Creates a draft.
  const SubTrackDraft({
    required this.curriculumId,
    required this.name,
    required this.type,
    required this.windowStart,
    required this.ratePerWeek,
    required this.weeksPerYear,
    required this.learnsOnShabbos,
    required this.ground,
    this.academicYear,
    this.windowEnd,
  });

  /// The curriculum the sub-track belongs to.
  final String curriculumId;

  /// Learner-facing name.
  final String name;

  /// `school_year` or `ongoing`.
  final SubTrackType type;

  /// Academic year (school-year only).
  final int? academicYear;

  /// Inclusive window start.
  final CivilDate windowStart;

  /// Inclusive window end; null = open.
  final CivilDate? windowEnd;

  /// Leaf units per week.
  final double ratePerWeek;

  /// Study weeks per year.
  final double weeksPerYear;

  /// Whether the learner studies it on shabbos.
  final bool learnsOnShabbos;

  /// Ordered ground, as entered.
  final List<NodeEntry> ground;
}

/// The fields an edit changes; a null field keeps its value. Nullable
/// stored fields are cleared with [clearAcademicYear] / [clearWindowEnd].
/// `ground`, when given, replaces the whole ordered list.
final class SubTrackEdit {
  /// Creates an edit.
  const SubTrackEdit({
    this.name,
    this.type,
    this.academicYear,
    this.clearAcademicYear = false,
    this.windowStart,
    this.windowEnd,
    this.clearWindowEnd = false,
    this.ratePerWeek,
    this.weeksPerYear,
    this.learnsOnShabbos,
    this.ground,
  });

  /// New name.
  final String? name;

  /// New type.
  final SubTrackType? type;

  /// New academic year.
  final int? academicYear;

  /// Removes `academic_year` (e.g. when turning a school year ongoing).
  final bool clearAcademicYear;

  /// New window start.
  final CivilDate? windowStart;

  /// New window end.
  final CivilDate? windowEnd;

  /// Opens the window (`window_end` = null).
  final bool clearWindowEnd;

  /// New leaf units per week.
  final double? ratePerWeek;

  /// New study weeks per year.
  final double? weeksPerYear;

  /// New shabbos flag.
  final bool? learnsOnShabbos;

  /// The whole new ordered ground.
  final List<NodeEntry>? ground;
}

/// The sub-track lifecycle commands for one learner and actor.
final class SubTrackCommands {
  /// Creates the commands.
  ///
  /// [intent] supplies the curriculum's live calendar program (AD-45);
  /// [corpusOf], when given, the curriculum corpus for the cross-curriculum
  /// ground check (skipped when it is absent or returns null). [today] is
  /// the learner's civil date (AD-41); [nowUtc] stamps `at` / `ended_at`;
  /// [newId] mints ULIDs.
  SubTrackCommands({
    required this.scope,
    required this.actor,
    required SubTrackRepository subTracks,
    required GovernedIntentRepository intent,
    required CivilDate Function() today,
    required DateTime Function() nowUtc,
    required String Function() newId,
    Future<Corpus?> Function(String curriculumId)? corpusOf,
    LearningAnalytics? analytics,
    this.ackTimeout = const Duration(seconds: 3),
    this.readTimeout = const Duration(seconds: 10),
  }) : _subTracks = subTracks,
       _intent = intent,
       _today = today,
       _nowUtc = nowUtc,
       _newId = newId,
       _corpusOf = corpusOf,
       _analytics = analytics;

  /// The learner the commands write for.
  final LearnerScope scope;

  /// The session actor stamped on every entry.
  final Actor actor;

  /// How long a write waits for the server before it counts as queued
  /// offline (mirrors the data layer's `kFirestoreWriteAckTimeout`).
  final Duration ackTimeout;

  /// How long validation waits for the complete local read; past it the
  /// command needs a connection (`CaptureResult.onlineRequired`).
  final Duration readTimeout;

  final SubTrackRepository _subTracks;
  final GovernedIntentRepository _intent;
  final CivilDate Function() _today;
  final DateTime Function() _nowUtc;
  final String Function() _newId;
  final Future<Corpus?> Function(String curriculumId)? _corpusOf;
  final LearningAnalytics? _analytics;

  final Map<String, (PendingFailure, SubTrackChange)> _pending = {};
  final _pendingController = StreamController<List<PendingFailure>>.broadcast(
    sync: true,
  );

  /// Creates a sub-track from [draft]. [subTrackId] is the new doc ULID
  /// (minted when omitted); it is the entry's `entity_id`.
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
  }) async {
    if (actor.role == ActorRole.child) return const CaptureResult.childLimit();
    final id = subTrackId ?? _newId();
    final entryId = _newId();
    final candidate = SubTrack(
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
      lastChangeId: entryId,
    );
    final siblings = await _readSubTracks();
    if (siblings == null) return const CaptureResult.onlineRequired();
    if (siblings.any((s) => s.id == id)) {
      return const CaptureResult.rejected(CaptureRejection.invalid);
    }
    final refused = await _validate(candidate, prior: null, siblings: siblings);
    if (refused != null) return refused;
    if (!_encodes(candidate)) {
      return const CaptureResult.rejected(CaptureRejection.invalid);
    }
    // Absent optional fields are not written (nor logged as null → null).
    final fields = _fieldsOf(candidate)..removeWhere((_, v) => v == null);
    final entry = _entry(id, entryId, before: const {}, after: fields);
    return _emitOnSuccess(
      await _commit(
        SubTrackChange.create(
          subTrackId: id,
          changedFields: fields,
          entry: entry,
        ),
      ),
      candidate,
      SubTrackLifecycleAction.create,
    );
  }

  /// Edits sub-track [subTrackId] with [edit] (any field; `ground` replaced
  /// whole). Writes and logs only the fields that change.
  Future<CaptureResult> editSubTrack(
    String subTrackId,
    SubTrackEdit edit,
  ) async {
    if (actor.role == ActorRole.child) return const CaptureResult.childLimit();
    final siblings = await _readSubTracks();
    if (siblings == null) return const CaptureResult.onlineRequired();
    final current = _find(siblings, subTrackId);
    if (current == null) {
      return const CaptureResult.rejected(CaptureRejection.targetNotFound);
    }
    final candidate = _applyEdit(current, edit);
    final old = _fieldsOf(current);
    final now = _fieldsOf(candidate);
    final changed = [
      for (final key in now.keys)
        if (!storageValueEquals(old[key], now[key])) key,
    ];
    if (changed.isEmpty) return const CaptureResult.success();
    final before = {for (final k in changed) k: old[k]};
    final after = {for (final k in changed) k: now[k]};
    final refused = await _validate(
      candidate,
      prior: current,
      siblings: siblings,
    );
    if (refused != null) return refused;
    if (!_encodes(candidate)) {
      return const CaptureResult.rejected(CaptureRejection.invalid);
    }
    final entryId = _newId();
    final entry = _entry(subTrackId, entryId, before: before, after: after);
    return _emitOnSuccess(
      await _commit(
        SubTrackChange.fields(
          subTrackId: subTrackId,
          changedFields: after,
          entry: entry,
        ),
      ),
      candidate,
      SubTrackLifecycleAction.edit,
    );
  }

  /// Ends sub-track [subTrackId] (`end_reason = ended`).
  Future<CaptureResult> endSubTrack(String subTrackId) =>
      _tombstone(subTrackId, SubTrackEndReason.ended);

  /// Deletes sub-track [subTrackId] as a tombstone (`end_reason = deleted`).
  Future<CaptureResult> deleteSubTrack(String subTrackId) =>
      _tombstone(subTrackId, SubTrackEndReason.deleted);

  /// Queued sub-track batches the server refused for good, live.
  Stream<List<PendingFailure>> watchPendingFailures() async* {
    yield _pendingList();
    yield* _pendingController.stream;
  }

  /// Re-sends the identical batch of pending failure [pendingFailureId]
  /// (AD-46: the retry payload carries no freshly stamped time).
  Future<CaptureResult> retry(String pendingFailureId) async {
    final pending = _pending[pendingFailureId];
    if (pending == null) {
      return const CaptureResult.rejected(CaptureRejection.targetNotFound);
    }
    _pending.remove(pendingFailureId);
    _publishPending();
    return _commit(pending.$2);
  }

  /// Closes the pending-failure feed.
  Future<void> dispose() => _pendingController.close();

  // ── internals ─────────────────────────────────────────────────────────

  Future<CaptureResult> _tombstone(
    String subTrackId,
    SubTrackEndReason reason,
  ) async {
    if (actor.role == ActorRole.child) return const CaptureResult.childLimit();
    final siblings = await _readSubTracks();
    if (siblings == null) return const CaptureResult.onlineRequired();
    final current = _find(siblings, subTrackId);
    if (current == null) {
      return const CaptureResult.rejected(CaptureRejection.targetNotFound);
    }
    // Already ended (by end, delete, undo or track removal): nothing to do.
    if (current.isEnded) return const CaptureResult.success();
    final endedAt = _nowUtc().toUtc();
    final entryId = _newId();
    final entry = _entry(
      subTrackId,
      entryId,
      before: {SubTrack.kEndedAt: null, SubTrack.kEndReason: null},
      after: {SubTrack.kEndedAt: endedAt, SubTrack.kEndReason: reason.storage},
      at: endedAt,
    );
    return _emitOnSuccess(
      await _commit(
        SubTrackChange.tombstone(
          subTrackId: subTrackId,
          endedAt: endedAt,
          reason: reason,
          entry: entry,
        ),
      ),
      current,
      reason == SubTrackEndReason.ended
          ? SubTrackLifecycleAction.end
          : SubTrackLifecycleAction.delete,
    );
  }

  /// Emits one AD-47 `subtrack_lifecycle` event for a written (or queued)
  /// command — enums and counts only — and passes [result] through.
  CaptureResult _emitOnSuccess(
    CaptureResult result,
    SubTrack track,
    SubTrackLifecycleAction action,
  ) {
    if (result is CaptureSuccess && result.changeIds.isNotEmpty) {
      _analytics?.subTrackLifecycle(
        curriculumId: track.curriculumId,
        type: track.type,
        action: action,
        groundEntries: track.ground.length,
      );
    }
    return result;
  }

  /// The complete sub-track read of [scope] (live and ended), or null when
  /// it is not available within [readTimeout] (offline with no cache).
  Future<List<SubTrack>?> _readSubTracks() async {
    try {
      final ready = await _subTracks
          .watchAll(scope)
          .firstWhere((r) => r is CompleteReadReady<SubTrack>)
          .timeout(readTimeout);
      return (ready as CompleteReadReady<SubTrack>).items;
    } on TimeoutException {
      return null;
    }
  }

  /// The main track of [curriculumId] in the complete governed intent:
  /// whether it exists, and its live calendar program (or null).
  Future<({bool exists, String? programId})> _mainTrackOf(
    String curriculumId,
  ) async {
    final intent = await _intent.watch(scope).first.timeout(readTimeout);
    final mainTrack = intent.mainTracks[curriculumId];
    if (mainTrack == null) return (exists: false, programId: null);
    final program = mainTrack.program;
    return (
      exists: true,
      programId: program == null || program.endedAt != null
          ? null
          : program.programId,
    );
  }

  Future<CaptureResult?> _validate(
    SubTrack candidate, {
    required SubTrack? prior,
    required List<SubTrack> siblings,
  }) async {
    final corpus = await _corpusOf?.call(candidate.curriculumId);
    String? programId;
    if (prior == null) {
      final ({bool exists, String? programId}) mainTrack;
      try {
        mainTrack = await _mainTrackOf(candidate.curriculumId);
      } on TimeoutException {
        return const CaptureResult.onlineRequired();
      }
      // A create needs the curriculum's main track: no orphan sub-track for
      // a curriculum the learner does not follow (fail closed).
      if (!mainTrack.exists) {
        return const CaptureResult.rejected(CaptureRejection.invalid);
      }
      programId = mainTrack.programId;
    }
    final violations = [
      ...subTrackIntentViolations(candidate, corpus: corpus),
      ...subTrackLimitViolations(
        candidate: candidate,
        prior: prior,
        siblings: siblings,
        today: _today(),
        calendarProgramId: programId,
      ),
    ];
    if (violations.isEmpty) return null;
    return CaptureResult.rejected(
      CaptureRejection.invalid,
      violations: violations,
    );
  }

  ChangeLogEntry _entry(
    String subTrackId,
    String entryId, {
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    DateTime? at,
  }) {
    String keyOf(String field) => ChangedFieldKey(
      GovernedEntity.subTrack.collection,
      subTrackId,
      field,
    ).key;
    return ChangeLogEntry(
      id: entryId,
      entity: GovernedEntity.subTrack,
      entityId: subTrackId,
      actionId: entryId,
      // A create's before is null per field (AD-38 Create).
      before: {for (final f in after.keys) keyOf(f): before[f]},
      after: {for (final f in after.keys) keyOf(f): after[f]},
      at: at ?? _nowUtc().toUtc(),
      actor: actor,
    );
  }

  /// Writes [change] and waits up to [ackTimeout] for the server.
  Future<CaptureResult> _commit(SubTrackChange change) async {
    final success = CaptureResult.success(
      changeIds: [change.entry.id],
      actionId: change.entry.actionId,
    );
    final outcome = Completer<Object?>();
    unawaited(
      _subTracks
          .applyGovernedChange(scope, change)
          .then(
            (_) {
              if (!outcome.isCompleted) outcome.complete(null);
            },
            onError: (Object error, StackTrace stack) {
              if (!outcome.isCompleted) {
                outcome.complete(_Failed(error, stack));
              } else {
                _recordPending(change, error);
              }
            },
          ),
    );
    final timer = Timer(ackTimeout, () {
      if (!outcome.isCompleted) outcome.complete(_queued);
    });
    final result = await outcome.future;
    timer.cancel();
    if (result is _Queued) {
      return CaptureResult.success(
        changeIds: [change.entry.id],
        actionId: change.entry.actionId,
        queued: true,
      );
    }
    if (result is! _Failed) return success;
    return switch (result.error) {
      SubTrackNotFoundException() => const CaptureResult.rejected(
        CaptureRejection.targetNotFound,
      ),
      // Refused before it was queued: the caller sees it at once, so no
      // pending "not saved — retry" entry is recorded.
      PermanentWriteRejection() ||
      ChangeLogConflictException() ||
      ChangeBaselineMismatchException() ||
      StorageFormatException() => const CaptureResult.rejected(
        CaptureRejection.invalid,
      ),
      _ => Error.throwWithStackTrace(result.error, result.stack),
    };
  }

  void _recordPending(SubTrackChange change, Object error) {
    final code = error is PermanentWriteRejection ? error.code : '';
    final failure = PendingFailure(
      id: change.entry.id,
      eventIds: const [],
      changeIds: [change.entry.id],
      reason: switch (code) {
        'permission-denied' => PendingFailureReason.permissionDenied,
        'invalid-argument' => PendingFailureReason.invalidArgument,
        'failed-precondition' => PendingFailureReason.failedPrecondition,
        _ => PendingFailureReason.other,
      },
    );
    _pending[failure.id] = (failure, change);
    _publishPending();
  }

  List<PendingFailure> _pendingList() => [
    for (final (failure, _) in _pending.values) failure,
  ];

  void _publishPending() {
    if (!_pendingController.isClosed) _pendingController.add(_pendingList());
  }

  static SubTrack? _find(List<SubTrack> tracks, String id) {
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The intent fields of [track] in AD-52 storage form, without the codec's
  /// validation (so malformed intent reaches the AD-45 validator first):
  /// every governed field except the tombstone keys; `curriculum_id` never
  /// differs on an edit (it is immutable, AD-38).
  static Map<String, Object?> _fieldsOf(SubTrack track) => {
    SubTrack.kCurriculumId: track.curriculumId,
    SubTrack.kName: track.name,
    SubTrack.kType: track.type.storage,
    SubTrack.kAcademicYear: track.academicYear,
    SubTrack.kWindowStart: track.windowStart,
    SubTrack.kWindowEnd: track.windowEnd,
    SubTrack.kRatePerWeek: track.ratePerWeek,
    SubTrack.kWeeksPerYear: track.weeksPerYear,
    SubTrack.kLearnsOnShabbos: track.learnsOnShabbos,
    SubTrack.kGround: [
      for (final node in track.ground)
        {NodeEntry.kLevel: node.level, NodeEntry.kRef: node.ref},
    ],
  };

  /// Whether [track] passes the full AD-52 codec (cross-field invariants,
  /// non-empty ground entries, ULIDs).
  static bool _encodes(SubTrack track) {
    try {
      track.toStorage();
      return true;
    } on StorageFormatException {
      return false;
    }
  }

  static SubTrack _applyEdit(SubTrack t, SubTrackEdit e) => SubTrack(
    id: t.id,
    curriculumId: t.curriculumId,
    name: e.name ?? t.name,
    type: e.type ?? t.type,
    academicYear: e.clearAcademicYear
        ? null
        : (e.academicYear ?? t.academicYear),
    windowStart: e.windowStart ?? t.windowStart,
    windowEnd: e.clearWindowEnd ? null : (e.windowEnd ?? t.windowEnd),
    ratePerWeek: e.ratePerWeek ?? t.ratePerWeek,
    weeksPerYear: e.weeksPerYear ?? t.weeksPerYear,
    learnsOnShabbos: e.learnsOnShabbos ?? t.learnsOnShabbos,
    ground: e.ground ?? t.ground,
    endedAt: t.endedAt,
    endReason: t.endReason,
    lastChangeId: t.lastChangeId,
  );
}

/// The "no server ack yet" outcome of [SubTrackCommands._commit].
final class _Queued {
  const _Queued();
}

/// A write that failed before it counted as queued.
final class _Failed {
  const _Failed(this.error, this.stack);

  final Object error;
  final StackTrace stack;
}

const _queued = _Queued();
