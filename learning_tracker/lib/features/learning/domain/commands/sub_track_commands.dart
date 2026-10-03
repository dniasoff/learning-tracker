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
///   [SubTrackCommands.whenConfirmed] tells a caller holding a queued
///   result whether the server finally accepted it (DNI-499). Both live in
///   a [SubTrackWriteLedger] that outlives one commands instance, so a
///   rebuild of the commands for the same learner keeps them.
/// - **Analytics** (AD-47): `subtrack_lifecycle` is emitted once the server
///   has accepted the write — at once when it acknowledges within
///   [SubTrackCommands.ackTimeout], else when the queued write (or its
///   retry) is acknowledged. A queued write the server refuses emits
///   nothing.
///
/// Imports only `lib/domain/learner_state/**`, sibling command files and
/// `dart:` (C0 AC-1).
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/append_ground.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart'
    show OnlineRequiredException;
import 'package:learning_tracker/domain/learner_state/ports/sub_track_latest_write.dart';
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
/// `ground`, when given, replaces the whole ordered list; [appendGround]
/// instead appends picked nodes to the latest stored ground (Story 2.7).
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
    this.appendGround,
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

  /// Ground-picker nodes to append (Story 2.7 / DNI-498, FR-10/FR-11).
  ///
  /// The command re-reads the sub-track's latest `ground`, drops every
  /// picked leaf an existing entry already covers, and appends the rest in
  /// ContentIndex order (`groundToAppend`); the stored entries are kept as
  /// entered and the result is written as the whole new `ground` list with
  /// one change-log entry. Every node must belong to the sub-track's own
  /// curriculum. Exclusive with [ground]; a replay appends nothing.
  ///
  /// An append needs the server: the new list is derived from the row the
  /// server holds at commit time inside one transaction
  /// ([SubTrackLatestWrite]), so two devices appending at once both keep
  /// their nodes. It is never queued: a whole list derived from a cached
  /// row and replayed after reconnecting would, under AD-38 per-field LWW,
  /// overwrite nodes another device appended meanwhile, and the rules do
  /// not compare `ground` with the server row. Offline, or when the
  /// repository has no latest-row write, the command returns
  /// `CaptureResult.onlineRequired()` and writes nothing.
  final List<NodeEntry>? appendGround;
}

/// The in-memory comparison of a track's creation forecast with its
/// distinct in-window leaves. This is never persisted.
final class SubTrackForecastComparison {
  /// Creates a forecast comparison.
  const SubTrackForecastComparison({
    required this.forecast,
    required this.actual,
    required this.windowWeeks,
  });

  /// Capacity forecast when the track was created.
  final int forecast;

  /// Distinct leaves learned in the original window.
  final int actual;

  /// Length of the original window in weeks.
  final int windowWeeks;
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
    SubTrackWriteLedger? ledger,
    Future<SubTrackForecastComparison?> Function(SubTrack track)?
    forecastComparison,
    this.ackTimeout = const Duration(seconds: 3),
    this.readTimeout = const Duration(seconds: 10),
  }) : _ledger = ledger ?? SubTrackWriteLedger(),
       _ownsLedger = ledger == null,
       _subTracks = subTracks,
       _intent = intent,
       _today = today,
       _nowUtc = nowUtc,
       _newId = newId,
       _corpusOf = corpusOf,
       _analytics = analytics,
       _forecastComparison = forecastComparison;

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
  final Future<SubTrackForecastComparison?> Function(SubTrack track)?
  _forecastComparison;

  final SubTrackWriteLedger _ledger;
  final bool _ownsLedger;

  Map<String, (PendingFailure, SubTrackChange, void Function()?)>
  get _pending => _ledger._pending;

  Map<String, Completer<bool>> get _unconfirmed => _ledger._unconfirmed;

  StreamController<List<PendingFailure>> get _pendingController =>
      _ledger._controller;

  /// Pending-failure ids whose retry is in flight.
  Set<String> get _retrying => _ledger._retrying;

  /// Creates a sub-track from [draft]. [subTrackId] is the new doc ULID
  /// (minted when omitted); it is the entry's `entity_id`.
  ///
  /// [nextYearOf] makes the create the *Add next year* rollover of that
  /// school-year sub-track (Story 2.8): the source is re-read in the same
  /// complete read as the AD-45 check, and the create is refused
  /// (`rejected(targetNotFound)`, nothing written) when the source is gone,
  /// tombstoned (ended or deleted, e.g. on another device after the form
  /// opened), not a school year, or of another curriculum. The write is
  /// otherwise identical and is reported as `add_next_year` in
  /// `subtrack_lifecycle`. The source is never written.
  Future<CaptureResult> createSubTrack(
    SubTrackDraft draft, {
    String? subTrackId,
    String? nextYearOf,
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
    final read = await _readSubTracks();
    if (read.refusal case final refusal?) return refusal;
    final siblings = read.items;
    if (siblings.any((s) => s.id == id)) {
      return const CaptureResult.rejected(CaptureRejection.invalid);
    }
    if (nextYearOf != null) {
      final source = _find(siblings, nextYearOf);
      if (source == null ||
          source.isEnded ||
          source.type != SubTrackType.schoolYear ||
          source.curriculumId != draft.curriculumId) {
        return const CaptureResult.rejected(CaptureRejection.targetNotFound);
      }
    }
    final refused = await _validate(candidate, prior: null, siblings: siblings);
    if (refused != null) return refused;
    if (!_encodes(candidate)) {
      return const CaptureResult.rejected(CaptureRejection.invalid);
    }
    // Absent optional fields are not written (nor logged as null → null).
    final fields = _fieldsOf(candidate)..removeWhere((_, v) => v == null);
    final entry = _entry(id, entryId, before: const {}, after: fields);
    return _commit(
      SubTrackChange.create(
        subTrackId: id,
        changedFields: fields,
        entry: entry,
      ),
      onConfirmed: _emitter(
        candidate,
        nextYearOf != null
            ? SubTrackLifecycleAction.addNextYear
            : SubTrackLifecycleAction.create,
        forecastTrack: nextYearOf == null ? null : _find(siblings, nextYearOf),
      ),
    );
  }

  /// Edits sub-track [subTrackId] with [edit] (any field; `ground` replaced
  /// whole). Writes and logs only the fields that change.
  Future<CaptureResult> editSubTrack(
    String subTrackId,
    SubTrackEdit edit,
  ) async {
    if (actor.role == ActorRole.child) return const CaptureResult.childLimit();
    final read = await _readSubTracks();
    if (read.refusal case final refusal?) return refusal;
    final siblings = read.items;
    final current = _find(siblings, subTrackId);
    if (current == null) {
      return const CaptureResult.rejected(CaptureRejection.targetNotFound);
    }
    final (appended, corpus, refusedAppend) = await _appendedGround(
      current,
      edit,
    );
    if (refusedAppend != null) return refusedAppend;
    final candidate = _applyEdit(current, edit, ground: appended);
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
    if (appended != null) {
      // Never queue a whole-list `ground` built from the cached row (see
      // SubTrackEdit.appendGround): an append commits on the server or not
      // at all.
      if (_subTracks case final SubTrackLatestWrite writer
          when corpus != null) {
        return await _appendToLatest(
              writer,
              subTrackId,
              edit,
              corpus: corpus,
              siblings: siblings,
            ) ??
            const CaptureResult.onlineRequired();
      }
      return const CaptureResult.onlineRequired();
    }
    final entryId = _newId();
    final entry = _entry(subTrackId, entryId, before: before, after: after);
    return _commit(
      SubTrackChange.fields(
        subTrackId: subTrackId,
        changedFields: after,
        entry: entry,
      ),
      onConfirmed: _emitter(
        candidate,
        _groundAction(current.ground, candidate.ground),
      ),
    );
  }

  /// The whole new `ground` of an [SubTrackEdit.appendGround] edit of
  /// [current] (its latest stored value, read by this command) and the
  /// corpus it was derived with — nulls when [edit] does not append — or
  /// the result refusing it: a picked node outside the sub-track's
  /// curriculum (`crossCurriculumGround`), an ended sub-track, a missing
  /// corpus, or `ground` given as well.
  Future<(List<NodeEntry>?, Corpus?, CaptureResult?)> _appendedGround(
    SubTrack current,
    SubTrackEdit edit,
  ) async {
    const invalid = CaptureResult.rejected(CaptureRejection.invalid);
    final picked = edit.appendGround;
    if (picked == null) return (null, null, null);
    if (edit.ground != null || current.isEnded) return (null, null, invalid);
    final corpus = await _corpusOf?.call(current.curriculumId);
    if (corpus == null) return (null, null, invalid);
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
      return (
        null,
        null,
        CaptureResult.rejected(CaptureRejection.invalid, violations: foreign),
      );
    }
    return (_appendTo(current.ground, picked, corpus), corpus, null);
  }

  static List<NodeEntry> _appendTo(
    List<NodeEntry> ground,
    List<NodeEntry> picked,
    Corpus corpus,
  ) => [
    ...ground,
    ...groundToAppend(current: ground, selected: picked, corpus: corpus),
  ];

  /// Commits an append [edit] of [subTrackId] through [writer]: the new
  /// whole `ground` is re-derived from the row the server holds at commit
  /// time (re-run by the transaction if another write lands first) and
  /// written with one change-log entry whose `before` is that row. The
  /// picks were already checked against [corpus] on the cached row.
  ///
  /// Returns null when the server cannot be reached (nothing written or
  /// queued; the caller answers `onlineRequired`), else the command
  /// result. A latest row that already covers every pick writes nothing
  /// (success).
  Future<CaptureResult?> _appendToLatest(
    SubTrackLatestWrite writer,
    String subTrackId,
    SubTrackEdit edit, {
    required Corpus corpus,
    required List<SubTrack> siblings,
  }) async {
    final entryId = _newId();
    final today = _today();
    SubTrack? written;
    SubTrackChange? build(SubTrack latest) {
      written = null;
      if (latest.isEnded) {
        throw const _Refused(CaptureResult.rejected(CaptureRejection.invalid));
      }
      final candidate = _applyEdit(
        latest,
        edit,
        ground: _appendTo(latest.ground, edit.appendGround!, corpus),
      );
      final old = _fieldsOf(latest);
      final now = _fieldsOf(candidate);
      final changed = [
        for (final key in now.keys)
          if (!storageValueEquals(old[key], now[key])) key,
      ];
      if (changed.isEmpty) return null;
      final violations = [
        ...subTrackIntentViolations(candidate, corpus: corpus),
        ...subTrackLimitViolations(
          candidate: candidate,
          prior: latest,
          siblings: [for (final s in siblings) s.id == latest.id ? latest : s],
          today: today,
          calendarProgramId: null,
        ),
      ];
      if (violations.isNotEmpty) {
        throw _Refused(
          CaptureResult.rejected(
            CaptureRejection.invalid,
            violations: violations,
          ),
        );
      }
      if (!_encodes(candidate)) {
        throw const _Refused(CaptureResult.rejected(CaptureRejection.invalid));
      }
      final after = {for (final k in changed) k: now[k]};
      written = candidate;
      return SubTrackChange.fields(
        subTrackId: subTrackId,
        changedFields: after,
        entry: _entry(
          subTrackId,
          entryId,
          before: {for (final k in changed) k: old[k]},
          after: after,
        ),
      );
    }

    final SubTrackChange? change;
    try {
      change = await writer.applyGovernedChangeToLatest(
        scope,
        subTrackId,
        build,
      );
    } on _Refused catch (refused) {
      return refused.result;
    } on OnlineRequiredException {
      return null;
    } on Object catch (error, stack) {
      return _refusalOf(error, stack);
    }
    final track = written;
    if (change == null || track == null) return const CaptureResult.success();
    // The latest-row transaction is online-only: committed means accepted.
    _emitter(track, SubTrackLifecycleAction.groundAdd)();
    return CaptureResult.success(
      changeIds: [change.entry.id],
      actionId: change.entry.actionId,
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

  /// Whether [pendingFailureId] is one of these commands' pending failures
  /// (so `LearningCommands.retry` routes it here).
  bool hasPendingFailure(String pendingFailureId) =>
      _pending.containsKey(pendingFailureId);

  /// Whether the write of change-log entry [changeId] was accepted by the
  /// server. Completes true at its acknowledgement (at once when it is not
  /// waiting for one: acknowledged already, or never queued here) and
  /// false when the server refused it for good — it is then a pending
  /// failure, and a [retry] that queues again can be awaited anew.
  Future<bool> whenConfirmed(String changeId) {
    if (_pending.containsKey(changeId)) return Future.value(false);
    return _unconfirmed[changeId]?.future ?? Future.value(true);
  }

  /// Re-sends the identical batch of pending failure [pendingFailureId]
  /// (AD-46: the retry payload carries no freshly stamped time).
  ///
  /// The pending record stays listed until the retry is accepted (saved,
  /// or queued again; a queued retry the server later refuses is recorded
  /// afresh under the same id). A retry refused at once or one that throws
  /// leaves the identical record in place, so the "not saved — retry"
  /// entry is never lost for an operation that did not succeed. A second
  /// retry of the same record while one is in flight is `targetNotFound`
  /// (it is not re-sent twice).
  Future<CaptureResult> retry(String pendingFailureId) async {
    final pending = _pending[pendingFailureId];
    if (pending == null || !_retrying.add(pendingFailureId)) {
      return const CaptureResult.rejected(CaptureRejection.targetNotFound);
    }
    try {
      final result = await _commit(pending.$2, onConfirmed: pending.$3);
      if (result is CaptureSuccess &&
          // Records have no identity; compare the failure object.
          identical(_pending[pendingFailureId]?.$1, pending.$1)) {
        _pending.remove(pendingFailureId);
        _publishPending();
      }
      return result;
    } finally {
      _retrying.remove(pendingFailureId);
    }
  }

  /// Closes the pending-failure feed, unless the ledger was handed in (its
  /// owner closes it).
  Future<void> dispose() => _ownsLedger ? _ledger.dispose() : Future.value();

  // ── internals ─────────────────────────────────────────────────────────

  Future<CaptureResult> _tombstone(
    String subTrackId,
    SubTrackEndReason reason,
  ) async {
    if (actor.role == ActorRole.child) return const CaptureResult.childLimit();
    final read = await _readSubTracks();
    if (read.refusal case final refusal?) return refusal;
    final siblings = read.items;
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
    return _commit(
      SubTrackChange.tombstone(
        subTrackId: subTrackId,
        endedAt: endedAt,
        reason: reason,
        entry: entry,
      ),
      onConfirmed: _emitter(
        current,
        reason == SubTrackEndReason.ended
            ? SubTrackLifecycleAction.end
            : SubTrackLifecycleAction.delete,
      ),
    );
  }

  /// The AD-47 lifecycle summary — enums and counts only — that [_commit]
  /// runs once the server has accepted the write. An end, delete or *Add
  /// next year* also reports SM-5 for [forecastTrack] (the closed school
  /// year of an *Add next year*), else for [track].
  void Function() _emitter(
    SubTrack track,
    SubTrackLifecycleAction action, {
    SubTrack? forecastTrack,
  }) =>
      () => unawaited(
        _emitLifecycleSummary(track, action, forecastTrack ?? track),
      );

  Future<void> _emitLifecycleSummary(
    SubTrack track,
    SubTrackLifecycleAction action,
    SubTrack forecastTrack,
  ) async {
    var leaves = 0;
    if (_analytics != null && _corpusOf != null) {
      try {
        final corpus = await _corpusOf(track.curriculumId);
        if (corpus != null) leaves = expandGround(track.ground, corpus).length;
      } on Object {
        // Analytics is best-effort and must never fail a durable command.
      }
    }
    _analytics?.subTrackLifecycleSummary(
      curriculumId: track.curriculumId,
      type: track.type,
      action: action,
      groundEntries: track.ground.length,
      leaves: leaves,
    );
    if (_forecastComparison != null &&
        (action == SubTrackLifecycleAction.end ||
            action == SubTrackLifecycleAction.delete ||
            action == SubTrackLifecycleAction.addNextYear)) {
      try {
        final comparison = await _forecastComparison(forecastTrack);
        if (comparison != null) {
          _analytics?.subTrackForecastVsActual(
            type: forecastTrack.type,
            forecast: comparison.forecast,
            actual: comparison.actual,
            windowWeeks: comparison.windowWeeks,
          );
        }
      } on Object {
        // A missing history page cannot fail an already durable close.
      }
    }
  }

  static SubTrackLifecycleAction _groundAction(
    List<NodeEntry> before,
    List<NodeEntry> after,
  ) {
    if (after.length > before.length && after.toSet().containsAll(before)) {
      return SubTrackLifecycleAction.groundAdd;
    }
    if (after.length < before.length && before.toSet().containsAll(after)) {
      return SubTrackLifecycleAction.remove;
    }
    if (after.length == before.length &&
        after.toSet().length == before.toSet().length &&
        after.toSet().containsAll(before) &&
        after.indexed.any((entry) => entry.$2 != before[entry.$1])) {
      return SubTrackLifecycleAction.reorder;
    }
    return SubTrackLifecycleAction.edit;
  }

  /// The complete sub-track read of [scope] (live and ended), or a refusal:
  /// - `onlineRequired` when it is not available within [readTimeout]
  ///   (offline with no cache);
  /// - `rejected(invalid)` when the read holds rows that failed strict
  ///   decode. Their limits cannot be checked, so every write fails closed
  ///   rather than validating against a partial sibling set (AD-35 complete
  ///   inputs, AD-45).
  Future<({List<SubTrack> items, CaptureResult? refusal})>
  _readSubTracks() async {
    try {
      final ready = await _subTracks
          .watchAll(scope)
          .firstWhere((r) => r is CompleteReadReady<SubTrack>)
          .timeout(readTimeout);
      final complete = ready as CompleteReadReady<SubTrack>;
      if (!complete.isClean) {
        return (
          items: const <SubTrack>[],
          refusal: const CaptureResult.rejected(CaptureRejection.invalid),
        );
      }
      return (items: complete.items, refusal: null);
    } on TimeoutException {
      return (
        items: const <SubTrack>[],
        refusal: const CaptureResult.onlineRequired(),
      );
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
  /// [onConfirmed] runs once the server accepts the write, however late.
  Future<CaptureResult> _commit(
    SubTrackChange change, {
    void Function()? onConfirmed,
  }) async {
    final id = change.entry.id;
    final success = CaptureResult.success(
      changeIds: [id],
      actionId: change.entry.actionId,
    );
    final outcome = Completer<Object?>();
    unawaited(
      _subTracks
          .applyGovernedChange(scope, change)
          .then(
            (_) {
              if (!outcome.isCompleted) outcome.complete(null);
              _unconfirmed.remove(id)?.complete(true);
              onConfirmed?.call();
            },
            onError: (Object error, StackTrace stack) {
              if (!outcome.isCompleted) {
                outcome.complete(_Failed(error, stack));
              } else {
                _recordPending(change, error, onConfirmed);
                _unconfirmed.remove(id)?.complete(false);
              }
            },
          ),
    );
    final timer = Timer(ackTimeout, () {
      if (outcome.isCompleted) return;
      // Registered with the outcome, before any late ack can run.
      _unconfirmed[id] = Completer<bool>();
      outcome.complete(_queued);
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
    return _refusalOf(result.error, result.stack);
  }

  /// The result of a write that failed before it counted as queued; an
  /// unexpected error is rethrown.
  static CaptureResult _refusalOf(Object error, StackTrace stack) =>
      switch (error) {
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
        _ => Error.throwWithStackTrace(error, stack),
      };

  void _recordPending(
    SubTrackChange change,
    Object error,
    void Function()? onConfirmed,
  ) {
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
    _pending[failure.id] = (failure, change, onConfirmed);
    _publishPending();
  }

  List<PendingFailure> _pendingList() => [
    for (final (failure, _, _) in _pending.values) failure,
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

  /// The AD-52 intent fields of [track] (every governed field except the
  /// tombstone keys) — the payload the owner batch and the tutor's
  /// `tutorUpsertSubTrack` (Story 4.1, DNI-509) both diff and write.
  static Map<String, Object?> intentFieldsOf(SubTrack track) =>
      _fieldsOf(track);

  /// [track] with [edit] applied (`ground` replaced whole) — the one edit
  /// rule the owner and tutor paths share.
  static SubTrack applyEdit(SubTrack track, SubTrackEdit edit) =>
      _applyEdit(track, edit);

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

  static SubTrack _applyEdit(
    SubTrack t,
    SubTrackEdit e, {
    List<NodeEntry>? ground,
  }) => SubTrack(
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
    ground: ground ?? e.ground ?? t.ground,
    endedAt: t.endedAt,
    endReason: t.endReason,
    lastChangeId: t.lastChangeId,
  );
}

/// One learner's queued sub-track writes for the session (AD-54 Recovery):
/// the writes still waiting for the server's acknowledgement and the ones
/// it refused for good (pending failures with a retry).
///
/// [SubTrackCommands] keeps them here rather than in itself so that a
/// rebuild of the commands for the same learner (a parent-PIN, profile or
/// clock change) neither drops a refused write's retry nor loses the
/// acknowledgement a caller is waiting on: a write queued by the previous
/// instance still settles here, and the new instance retries it. Like the
/// event and governed pending failures, it lives in memory for the session
/// — there is no outbox; the Firestore SDK's offline queue carries the
/// write itself across restarts.
final class SubTrackWriteLedger {
  final Map<String, (PendingFailure, SubTrackChange, void Function()?)>
  _pending = {};

  /// Queued writes not yet acknowledged, by change-log entry id: completes
  /// true on the server ack, false when the server refuses it for good.
  final Map<String, Completer<bool>> _unconfirmed = {};

  /// Pending-failure ids whose retry is in flight.
  final Set<String> _retrying = {};
  final _controller = StreamController<List<PendingFailure>>.broadcast(
    sync: true,
  );

  /// Closes the pending-failure feed.
  Future<void> dispose() => _controller.close();
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

/// A latest-row append the validation refused inside the transaction;
/// thrown out of the build so nothing is written.
final class _Refused implements Exception {
  const _Refused(this.result);

  final CaptureResult result;
}
