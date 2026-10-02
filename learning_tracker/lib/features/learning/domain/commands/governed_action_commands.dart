/// The AD-38 governed half of `LearningCommands` (DNI-470 / Story 1.8):
/// owner governed changes and their field-level undo.
///
/// `DefaultLearningCommands` gates every call through the `CaptureGate`
/// and then delegates here ([GovernedLearningCommands]).
///
/// ## applyGovernedChange (AC-2, AC-3)
///
/// 1. The action is validated as a whole before any read or write (each
///    doc lives in its entity's collection, a doc-is-entity entity patches
///    only its own doc, no field is `last_change_id`, a `subTrack` change
///    has exactly one doc).
/// 2. An action with any entity over the AD-54 owner budget
///    ([GovernedBatch.maxDocs] docs) is not batched: the whole action, in
///    order, goes to the [OversizedGovernedWritePort] (the
///    `ownerOversizedGovernedWrite` callable). It is online-only: offline is
///    [CaptureResult.onlineRequired] and nothing is written or applied
///    optimistically (UX-DR-85, UX-DR-101).
/// 3. Otherwise each doc is read as the writer sees it
///    ([GovernedDocReader.currentDoc], cache then server); only fields
///    whose value differs are kept (a field-level `set(merge: true)`), and
///    `before` holds each kept field's cached value, `null` when absent.
///    An entity left with no changed field writes nothing.
/// 4. Ids, `at` and the actor are fixed before the first write: one ULID
///    per written entity, the first being the `action_id`. Each entity
///    becomes one self-contained batch (its docs plus its entry:
///    [ChangeLogRepository.commitGoverned], or
///    [SubTrackRepository.applyGovernedChange] for `subTrack`), committed in
///    action order. A batch not acknowledged within the ack wait is queued
///    (the SDK owns the offline queue); a batch rejected within it is not
///    saved, and the command reports `notSaved` only when every batch was.
///
/// ## undoAction (AC-4, AC-5)
///
/// An undo is one new action whose every entry carries
/// `reverts_action_id = A`. For each member entry U and each field f it
/// changed, f is restored to `U.before[f]` only while the doc still holds
/// `U.after[f]`; any other field is returned as "changed since by
/// <actor>" (the actor of the doc's current `last_change_id` entry). A doc
/// U created (outside `learnerSettings`: U wrote its immutable
/// `curriculum_id` and every field U wrote was absent before) is undone by
/// a tombstone (`ended_at`, plus `end_reason: undo` on a
/// sub-track) only while its `last_change_id` is still U's id.
///
/// An undo is final: an action whose entries carry `reverts_action_id` is
/// rejected with [CaptureRejection.undoIsFinal] and nothing is written; an
/// action already reverted, or holding a `learnerSettings` seed entry
/// (`before` all-null), offers no undo ([CaptureRejection.undoNotOffered]).
///
/// Imports only `lib/domain/learner_state/**`, this directory and `dart:`.
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_dispatcher.dart';

/// The actor reported for a "changed since" field whose latest change-log
/// entry cannot be read (e.g. offline, not cached).
const Actor unknownChangeActor = Actor(
  uid: '',
  role: ActorRole.parent,
  displayName: '',
);

/// One governed doc as the writer sees it: null when absent.
typedef _DocView = Map<String, Object?>?;

String _docKey(String collection, String docId) => '$collection/$docId';

/// One entity's planned write: its changed fields per doc, and its
/// `before` / `after` keyed `{collection}/{docId}.{field}`.
final class _EntityPlan {
  _EntityPlan(this.change);

  final GovernedEntityChange change;
  final List<GovernedDocMerge> merges = [];
  final Map<String, Object?> before = {};
  final Map<String, Object?> after = {};

  bool get isEmpty => merges.isEmpty;
}

/// The owner-device [GovernedLearningCommands] bound to one [LearnerScope]
/// and the session [Actor].
final class DefaultGovernedLearningCommands
    implements GovernedLearningCommands {
  /// Creates the commands.
  DefaultGovernedLearningCommands({
    required LearnerScope scope,
    required Actor actor,
    required ChangeLogRepository changeLog,
    required SubTrackRepository subTracks,
    required GovernedDocReader reader,
    required OversizedGovernedWritePort oversized,
    required UtcClock clock,
    required UlidSource newUlid,
    this.ackWait = defaultLearningAckWait,
  }) : _scope = scope,
       _actor = actor,
       _changeLog = changeLog,
       _subTracks = subTracks,
       _reader = reader,
       _oversized = oversized,
       _clock = clock,
       _newUlid = newUlid;

  final LearnerScope _scope;
  final Actor _actor;
  final ChangeLogRepository _changeLog;
  final SubTrackRepository _subTracks;
  final GovernedDocReader _reader;
  final OversizedGovernedWritePort _oversized;
  final UtcClock _clock;
  final UlidSource _newUlid;

  /// How long a batch waits for the server before it counts as queued.
  final Duration ackWait;

  static const _invalid = CaptureResult.rejected(CaptureRejection.invalid);
  static const _notSaved = CaptureResult.rejected(CaptureRejection.notSaved);

  @override
  Future<CaptureResult> applyGovernedChange(GovernedAction action) =>
      _run(action.changes, now: _clock().toUtc());

  @override
  Future<CaptureResult> undoAction(String actionId) async {
    if (!isUlid(actionId)) return _invalid;
    final now = _clock().toUtc();
    final List<ChangeLogEntry> members;
    final bool reverted;
    try {
      members = await _changeLog.entriesOfAction(_scope, actionId);
      if (members.isEmpty) {
        return const CaptureResult.rejected(CaptureRejection.targetNotFound);
      }
      // AC-5: an undo is final — checked before anything else is read.
      if (members.any((e) => e.revertsActionId != null)) {
        return const CaptureResult.rejected(CaptureRejection.undoIsFinal);
      }
      if (members.any(isSettingsSeed)) {
        return const CaptureResult.rejected(CaptureRejection.undoNotOffered);
      }
      reverted = await _changeLog.watchIsReverted(_scope, actionId).first;
    } on Object {
      return _notSaved; // the history could not be read: write nothing
    }
    if (reverted) {
      return const CaptureResult.rejected(CaptureRejection.undoNotOffered);
    }

    final docs = <String, _DocView>{};
    final actors = <String, Actor>{};
    final restores = <GovernedEntityChange>[];
    final changedSince = <ChangedSinceField>[];
    try {
      for (final u in members) {
        final fieldsByDoc = <String, List<ChangedFieldKey>>{};
        for (final key in u.changedKeys) {
          fieldsByDoc
              .putIfAbsent(_docKey(key.collection, key.docId), () => [])
              .add(key);
        }
        final patches = <GovernedDocPatch>[];
        for (final keys in fieldsByDoc.values) {
          final first = keys.first;
          final docKey = _docKey(first.collection, first.docId);
          final current = docs.containsKey(docKey)
              ? docs[docKey]
              : docs[docKey] = await _reader.currentDoc(
                  _scope,
                  first.collection,
                  first.docId,
                );
          Future<void> changedSinceAll(Iterable<ChangedFieldKey> ks) async {
            final by = await _lastChangeActor(current, actors);
            changedSince.addAll([for (final k in ks) ChangedSinceField(k, by)]);
          }

          // U created this doc iff it wrote the doc's immutable, required
          // `curriculum_id` (written exactly once, at creation) and every
          // field it wrote was absent before.
          final created =
              u.entity != GovernedEntity.learnerSettings &&
              keys.any((k) => k.field == GovernedKeys.curriculumId) &&
              keys.every((k) => u.before[k.key] == null);
          if (created) {
            if (current?[GovernedKeys.lastChangeId] == u.id) {
              patches.add(
                GovernedDocPatch(
                  collection: first.collection,
                  docId: first.docId,
                  fields: {
                    GovernedKeys.endedAt: now,
                    if (u.entity == GovernedEntity.subTrack)
                      SubTrack.kEndReason: SubTrackEndReason.undo.storage,
                  },
                ),
              );
            } else {
              await changedSinceAll(keys);
            }
            continue;
          }
          final restore = <String, Object?>{};
          final conflicts = <ChangedFieldKey>[];
          for (final k in keys) {
            if (storageValueEquals(current?[k.field], u.after[k.key])) {
              restore[k.field] = u.before[k.key];
            } else {
              conflicts.add(k);
            }
          }
          if (conflicts.isNotEmpty) await changedSinceAll(conflicts);
          if (restore.isNotEmpty) {
            patches.add(
              GovernedDocPatch(
                collection: first.collection,
                docId: first.docId,
                fields: restore,
              ),
            );
          }
        }
        if (patches.isNotEmpty) {
          restores.add(
            GovernedEntityChange(
              entity: u.entity,
              entityId: u.entityId,
              docs: patches,
            ),
          );
        }
      }
    } on Object {
      return _notSaved; // a doc could not be read: write nothing
    }
    if (restores.isEmpty) {
      return CaptureResult.success(changedSince: changedSince);
    }
    return _run(
      restores,
      now: now,
      revertsActionId: actionId,
      changedSince: changedSince,
      knownDocs: docs,
    );
  }

  /// Whether [e] is a `learnerSettings` seed entry (`before` all-null),
  /// which never offers undo (AD-37).
  static bool isSettingsSeed(ChangeLogEntry e) =>
      e.entity == GovernedEntity.learnerSettings &&
      e.before.values.every((v) => v == null);

  /// The actor of [current]'s `last_change_id` entry (memoised in
  /// [actors]), or [unknownChangeActor].
  Future<Actor> _lastChangeActor(
    _DocView current,
    Map<String, Actor> actors,
  ) async {
    final id = current?[GovernedKeys.lastChangeId];
    if (id is! String) return unknownChangeActor;
    final known = actors[id];
    if (known != null) return known;
    final ChangeLogEntry? entry;
    try {
      entry = await _reader.entry(_scope, id);
    } on Object {
      return unknownChangeActor;
    }
    return actors[id] = entry?.actor ?? unknownChangeActor;
  }

  /// Validates, plans and writes [changes] as one action.
  Future<CaptureResult> _run(
    List<GovernedEntityChange> changes, {
    required DateTime now,
    String? revertsActionId,
    List<ChangedSinceField> changedSince = const [],
    Map<String, _DocView> knownDocs = const {},
  }) async {
    if (!_valid(changes)) return _invalid;
    if (changes.any((c) => c.docs.length > GovernedBatch.maxDocs)) {
      return _writeOversized(changes, now, revertsActionId, changedSince);
    }

    // Plan against the writer's view of every doc (AC-2).
    final plans = <_EntityPlan>[];
    try {
      for (final change in changes) {
        final plan = _EntityPlan(change);
        for (final doc in change.docs) {
          final key = _docKey(doc.collection, doc.docId);
          final current = knownDocs.containsKey(key)
              ? knownDocs[key]
              : await _reader.currentDoc(_scope, doc.collection, doc.docId);
          if (doc.mode == DocMode.create && current != null) return _invalid;
          if (doc.mode == DocMode.update && current == null) {
            return const CaptureResult.rejected(
              CaptureRejection.targetNotFound,
            );
          }
          final changed = <String, Object?>{
            for (final MapEntry(:key, :value) in doc.fields.entries)
              if (!storageValueEquals(current?[key], value)) key: value,
          };
          if (changed.isEmpty) continue;
          plan.merges.add(
            GovernedDocMerge(
              collection: doc.collection,
              docId: doc.docId,
              fields: changed,
            ),
          );
          changed.forEach((field, value) {
            final k = ChangedFieldKey(doc.collection, doc.docId, field).key;
            plan.before[k] = current?[field];
            plan.after[k] = value;
          });
        }
        if (!plan.isEmpty) plans.add(plan);
      }
    } on Object {
      return _notSaved; // a doc could not be read: write nothing
    }
    if (plans.isEmpty) {
      return CaptureResult.success(changedSince: changedSince);
    }

    // Fix every id, time and payload before the first write (AC-2, T2).
    final ids = [for (final _ in plans) _newUlid(now)];
    final actionId = ids.first;
    final units = <(String, Future<void> Function())>[];
    try {
      for (var i = 0; i < plans.length; i++) {
        final plan = plans[i];
        final entry = ChangeLogEntry(
          id: ids[i],
          entity: plan.change.entity,
          entityId: plan.change.entityId,
          actionId: actionId,
          revertsActionId: revertsActionId,
          before: plan.before,
          after: plan.after,
          at: now,
          actor: _actor,
        )..toStorage(); // AD-52 validation before any write
        if (plan.change.entity == GovernedEntity.subTrack) {
          final merge = plan.merges.single;
          final change = SubTrackChange.fields(
            subTrackId: merge.docId,
            changedFields: merge.fields,
            entry: entry,
          );
          units.add((
            entry.id,
            () => _subTracks.applyGovernedChange(_scope, change),
          ));
        } else {
          final batch = GovernedBatch(entry: entry, merges: plan.merges);
          units.add((entry.id, () => _changeLog.commitGoverned(_scope, batch)));
        }
      }
    } on StorageFormatException {
      return _invalid;
    } on ArgumentError {
      return _invalid;
    }
    return _dispatch(units, actionId, changedSince);
  }

  /// Commits [units] in action order, each waiting at most [ackWait].
  Future<CaptureResult> _dispatch(
    List<(String, Future<void> Function())> units,
    String actionId,
    List<ChangedSinceField> changedSince,
  ) async {
    final saved = <String>[];
    Object? onlyError;
    var queued = false;
    for (final (id, commit) in units) {
      final pending = commit();
      try {
        final acked = await pending
            .then((_) => true)
            .timeout(ackWait, onTimeout: () => false);
        if (!acked) {
          queued = true;
          // Keep a late outcome observed; the SDK retries transient errors.
          unawaited(pending.then<void>((_) {}, onError: (Object _) {}));
        }
        saved.add(id);
      } on Object catch (error) {
        onlyError = error;
      }
    }
    if (saved.isEmpty) {
      return switch (units.length == 1 ? onlyError : null) {
        SubTrackNotFoundException() => const CaptureResult.rejected(
          CaptureRejection.targetNotFound,
        ),
        StorageFormatException() ||
        ChangeBaselineMismatchException() => _invalid,
        _ => _notSaved,
      };
    }
    return CaptureResult.success(
      changeIds: saved,
      actionId: actionId,
      queued: queued,
      changedSince: changedSince,
    );
  }

  /// The whole action through the online-only callable (AC-3).
  Future<CaptureResult> _writeOversized(
    List<GovernedEntityChange> changes,
    DateTime now,
    String? revertsActionId,
    List<ChangedSinceField> changedSince,
  ) async {
    final entries = [
      for (final change in changes)
        OversizedGovernedEntry(entryId: _newUlid(now), change: change),
    ];
    final request = OversizedGovernedWrite(
      actionId: entries.first.entryId,
      actorRole: _actor.role,
      entries: entries,
      revertsActionId: revertsActionId,
    );
    final GovernedWriteReceipt receipt;
    try {
      receipt = await _oversized.write(_scope, request);
    } on OnlineRequiredException {
      return const CaptureResult.onlineRequired();
    } on Object {
      return _notSaved; // rejected; the callable is idempotent on actionId
    }
    return CaptureResult.success(
      changeIds: receipt.changeIds,
      actionId: receipt.actionId,
      changedSince: changedSince,
    );
  }

  /// Whether [v] is an AD-52 storage value: null, bool, num, String, a UTC
  /// instant, or a list / string-keyed map of those.
  static bool _isStorageValue(Object? v) => switch (v) {
    null || bool() || num() || String() || DateTime() => true,
    List<Object?>() => v.every(_isStorageValue),
    Map<String, Object?>() => v.values.every(_isStorageValue),
    _ => false,
  };

  /// The whole-action shape checks (nothing is read or written before).
  static bool _valid(List<GovernedEntityChange> changes) {
    if (changes.isEmpty) return false;
    for (final change in changes) {
      if (change.docs.isEmpty || change.entityId.isEmpty) return false;
      if (change.entity == GovernedEntity.subTrack && change.docs.length != 1) {
        return false;
      }
      final seen = <String>{};
      for (final doc in change.docs) {
        if (doc.collection != change.entity.collection ||
            doc.docId.isEmpty ||
            doc.docId.contains('/') ||
            doc.fields.isEmpty ||
            doc.fields.containsKey(GovernedKeys.lastChangeId) ||
            doc.fields.keys.any((f) => f.isEmpty || f.contains('.')) ||
            !doc.fields.values.every(_isStorageValue) ||
            !seen.add(doc.docId)) {
          return false;
        }
        if (change.entity.docIdIsEntityId && doc.docId != change.entityId) {
          return false;
        }
      }
    }
    return true;
  }
}
