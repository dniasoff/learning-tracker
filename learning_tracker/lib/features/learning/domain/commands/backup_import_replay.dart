/// The AD-49 backup import replay (DNI-482 / Story 1.20):
/// `LearningCommands.importBackup` delegates here.
///
/// A backup carries one learner's learning record in storage form
/// ([BackupReplayInput]). Replay rebuilds it on the destination profile
/// through the same write paths as every other command, in this order
/// ([BackupReplayStep]):
///
/// 1. **learnerSettings** — the source's `learnerSettings` change-log
///    entries, ordered by `original_at ?? at`, become field-level logged
///    updates of the destination profile's import-time settings (its
///    seed), each carrying `original_at` = the old entry's effective
///    instant. Fields an entry would not change are left out; an entry
///    that changes nothing writes nothing.
/// 2. **governed** — every governed doc (goals and the `mainTrack*`
///    collections) as a field-level logged update against the writer's
///    view of the destination doc (`before` = its cached value, `null` when
///    absent). Never a create claim. One entry per entity and at most
///    [GovernedBatch.maxDocs] docs per batch (AD-54).
/// 3. **subTracks** — every sub-track under a fresh ULID (the old → new
///    map is [BackupReplayResult.subTrackIds]), written through
///    `SubTrackRepository.applyGovernedChange`: a create, then a tombstone
///    entry for a sub-track that was ended (a create is never a
///    tombstone).
/// 4. **learnEvents** — every `learn` event under a fresh ULID, with its
///    `source` remapped through the sub-track map and
///    `original_recorded_at = effectiveAt(old)`; every one AD-50 pairs
///    with an award gets a freshly derived `pts_{eventId}` entry in the
///    same chunk. Old event-linked point entries are never imported.
/// 5. **voidEvents** — every `void` whose target was mapped in step 4,
///    remapped, also carrying `original_recorded_at = effectiveAt(old)` so
///    the lock-ignore rule judges it at its original instant. A void whose
///    target is unmapped (absent, or not a `learn`) is dropped.
/// 6. **records** — the non-event `points_ledger` entries and the
///    `reward_redemptions`, as new records under fresh ULIDs (a points
///    entry's `redemption_ulid` follows its redemption's new id).
///
/// No other change-log entry is replayed.
///
/// Every id, time and payload is fixed before the first write. Events go
/// out in AD-54 chunks of at most [LearningWriteChunk.maxWrites] writes,
/// each event with its `pts_` entry. A batch or chunk the server does not
/// save becomes one "not saved — retry" [PendingFailure]
/// ([watchPendingFailures], [retry]); the result lists them in
/// [BackupReplayResult.notSaved] and never reports the import as saved.
///
/// Imports only `lib/domain/learner_state/**`, this directory and `dart:`.
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ports/backup_record_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_pending_failures.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_event_plans.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_chunker.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_write_dispatcher.dart';

/// The governed entities a backup carries besides `subTrack` and
/// `learnerSettings`, in replay order (AD-38, AD-49).
const List<GovernedEntity> backupGovernedEntities = [
  GovernedEntity.mainTrack,
  GovernedEntity.mainTrackProgram,
  GovernedEntity.mainTrackScope,
  GovernedEntity.mainTrackStudyDays,
  GovernedEntity.mainTrackStages,
  GovernedEntity.mainTrackOrder,
  GovernedEntity.goal,
];

/// Governed-doc keys a replay never writes: `last_change_id` (set from the
/// new entry) and the keys retired from governed docs (AD-38).
const Set<String> _unreplayedGovernedKeys = {
  GovernedKeys.lastChangeId,
  ...GovernedKeys.retired,
};

/// One backed-up document: its id and storage-form fields (instants as
/// UTC `DateTime`s).
final class BackupDoc {
  /// Creates the doc; [fields] are deep-copied and frozen.
  BackupDoc(this.id, Map<String, Object?> fields)
    : fields = freezeStorageMap(fields);

  /// The document id.
  final String id;

  /// The fields, storage form.
  final Map<String, Object?> fields;

  @override
  String toString() => 'BackupDoc($id)';
}

/// One learner's AD-49 learning record, decoded from a backup.
final class BackupReplayInput {
  /// Creates the input.
  BackupReplayInput({
    List<LearningEvent> events = const [],
    List<SubTrack> subTracks = const [],
    List<ChangeLogEntry> changeLog = const [],
    Map<GovernedEntity, List<BackupDoc>> governed = const {},
    List<BackupDoc> pointsEntries = const [],
    List<BackupDoc> rewardRedemptions = const [],
  }) : events = List.unmodifiable(events),
       subTracks = List.unmodifiable(subTracks),
       changeLog = List.unmodifiable(changeLog),
       governed = Map.unmodifiable(governed),
       pointsEntries = List.unmodifiable(pointsEntries),
       rewardRedemptions = List.unmodifiable(rewardRedemptions);

  /// Every `learning_events` row.
  final List<LearningEvent> events;

  /// Every `sub_tracks` row, live and tombstoned.
  final List<SubTrack> subTracks;

  /// Every `change_log` row (only `learnerSettings` entries replay).
  final List<ChangeLogEntry> changeLog;

  /// The governed docs by entity ([backupGovernedEntities]).
  final Map<GovernedEntity, List<BackupDoc>> governed;

  /// The `points_ledger` rows; event entries are ignored.
  final List<BackupDoc> pointsEntries;

  /// The `reward_redemptions` rows.
  final List<BackupDoc> rewardRedemptions;
}

/// The replay steps, in order (AD-49).
enum BackupReplayStep {
  /// `learnerSettings` updates of the import seed.
  learnerSettings,

  /// Governed docs as logged updates.
  governed,

  /// Sub-tracks under fresh ids.
  subTracks,

  /// `learn` events and their `pts_` entries.
  learnEvents,

  /// `void` events.
  voidEvents,

  /// Non-event points entries and reward redemptions.
  records,
}

/// What an import did.
final class BackupReplayResult {
  /// Creates the result.
  const BackupReplayResult({
    required this.result,
    this.notSaved = const [],
    this.subTrackIds = const {},
    this.eventIds = const {},
    this.steps = const [],
  });

  /// The command result: a success for the writes saved or queued, the
  /// gate's lock, `invalid` for a backup that cannot be replayed, or
  /// `notSaved` when nothing was saved.
  final CaptureResult result;

  /// The "not saved — retry" failures this import left behind.
  final List<PendingFailure> notSaved;

  /// Old → new sub-track ids.
  final Map<String, String> subTrackIds;

  /// Old → new learning-event ids (learns and the voids kept).
  final Map<String, String> eventIds;

  /// The steps that wrote, in write order.
  final List<BackupReplayStep> steps;

  /// Whether every write was saved or queued: no "not saved" failure.
  bool get saved => result is CaptureSuccess && notSaved.isEmpty;

  @override
  String toString() =>
      'BackupReplayResult($result, ${notSaved.length} not saved)';
}

/// A backup that cannot be replayed (an invalid payload). Nothing was
/// written.
final class BackupReplayInvalid implements Exception {
  /// Creates the failure.
  const BackupReplayInvalid(this.reason);

  /// Why.
  final String reason;

  @override
  String toString() => 'BackupReplayInvalid: $reason';
}

/// The planned writes of one import, fixed before the first write.
final class BackupReplayPlan {
  BackupReplayPlan._();

  /// Step 1 batches.
  final List<GovernedBatch> settings = [];

  /// Step 2 batches.
  final List<GovernedBatch> governed = [];

  /// Step 3 changes: each sub-track's create and, if ended, its tombstone.
  final List<(SubTrackChange, SubTrackChange?)> subTracks = [];

  /// Step 4 units.
  final List<WriteUnit> learns = [];

  /// Step 5 units.
  final List<WriteUnit> voids = [];

  /// Step 6 writes, redemptions first.
  final List<BackupRecordWrite> records = [];

  /// Old → new sub-track ids.
  final Map<String, String> subTrackIds = {};

  /// Old → new event ids.
  final Map<String, String> eventIds = {};

  /// Whether the plan writes nothing.
  bool get isEmpty =>
      settings.isEmpty &&
      governed.isEmpty &&
      subTracks.isEmpty &&
      learns.isEmpty &&
      voids.isEmpty &&
      records.isEmpty;
}

/// Plans an import: every id, time and payload, from [input] and the
/// destination's current docs read through [reader].
///
/// [amount] is the AD-50 points amount of an earning event. Throws
/// [BackupReplayInvalid] for a record no write could carry.
Future<BackupReplayPlan> planBackupReplay({
  required BackupReplayInput input,
  required LearnerScope scope,
  required CommandStamp stamp,
  required GovernedDocReader reader,
  required Future<int> Function(String curriculumId, int? stage) amount,
}) async {
  final plan = BackupReplayPlan._();
  final now = stamp.nowUtc;
  String? actionId;
  String nextChangeId() {
    final id = stamp.ids(1).single;
    actionId ??= id;
    return id;
  }

  ChangeLogEntry entry({
    required GovernedEntity entity,
    required String entityId,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    DateTime? originalAt,
  }) {
    final id = nextChangeId();
    return ChangeLogEntry(
      id: id,
      entity: entity,
      entityId: entityId,
      actionId: actionId!,
      before: before,
      after: after,
      at: now,
      actor: stamp.actor,
      originalAt: originalAt,
    )..toStorage();
  }

  try {
    await _planSettings(plan, input, scope, reader, entry);
    await _planGoverned(plan, input, scope, reader, entry);
    _planSubTracks(plan, input, stamp, entry);
    await _planEvents(plan, input, stamp, amount);
    _planRecords(plan, input, stamp);
  } on StorageFormatException catch (e) {
    throw BackupReplayInvalid('$e');
  } on ArgumentError catch (e) {
    throw BackupReplayInvalid('$e');
  }
  return plan;
}

typedef _EntryOf =
    ChangeLogEntry Function({
      required GovernedEntity entity,
      required String entityId,
      required Map<String, Object?> before,
      required Map<String, Object?> after,
      DateTime? originalAt,
    });

DateTime _entryInstant(ChangeLogEntry e) => e.originalAt ?? e.at;

const Set<String> _settingsFields = {
  LearnerSettings.kLatitude,
  LearnerSettings.kLongitude,
  LearnerSettings.kTimeZone,
  LearnerSettings.kInIsrael,
};

/// Step 1: the source `learnerSettings` history as ordered updates of the
/// destination's current settings.
Future<void> _planSettings(
  BackupReplayPlan plan,
  BackupReplayInput input,
  LearnerScope scope,
  GovernedDocReader reader,
  _EntryOf entryOf,
) async {
  final history =
      input.changeLog
          .where((e) => e.entity == GovernedEntity.learnerSettings)
          .toList()
        ..sort((a, b) {
          final byTime = _entryInstant(a).compareTo(_entryInstant(b));
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
  if (history.isEmpty) return;
  const collection = 'learner_profiles';
  assert(collection == GovernedEntity.learnerSettings.collection, 'AD-38');
  final profileId = scope.profileId;
  final current = await reader.currentDoc(scope, collection, profileId);
  final running = <String, Object?>{
    for (final f in _settingsFields) f: current?[f],
  };
  String key(String field) => ChangedFieldKey(collection, profileId, field).key;
  for (final old in history) {
    final changed = <String, Object?>{};
    for (final MapEntry(key: k, :value) in old.after.entries) {
      final parsed = ChangedFieldKey.tryParse(k);
      if (parsed == null ||
          parsed.collection != collection ||
          !_settingsFields.contains(parsed.field)) {
        continue;
      }
      if (!storageValueEquals(running[parsed.field], value)) {
        changed[parsed.field] = value;
      }
    }
    if (changed.isEmpty) continue;
    final entry = entryOf(
      entity: GovernedEntity.learnerSettings,
      entityId: profileId,
      before: {for (final f in changed.keys) key(f): running[f]},
      after: {
        for (final MapEntry(key: f, :value) in changed.entries) key(f): value,
      },
      originalAt: _entryInstant(old),
    );
    plan.settings.add(
      GovernedBatch(
        entry: entry,
        merges: [
          GovernedDocMerge(
            collection: collection,
            docId: profileId,
            fields: changed,
          ),
        ],
      ),
    );
    running.addAll(changed);
  }
}

/// Step 2: governed docs as field-level logged updates, one entry per
/// entity and at most [GovernedBatch.maxDocs] docs per batch.
Future<void> _planGoverned(
  BackupReplayPlan plan,
  BackupReplayInput input,
  LearnerScope scope,
  GovernedDocReader reader,
  _EntryOf entryOf,
) async {
  for (final entity in backupGovernedEntities) {
    final docs = [...?input.governed[entity]]
      ..sort((a, b) => a.id.compareTo(b.id));
    // entity_id → its changed docs, in doc order.
    final byEntity = <String, List<GovernedDocMerge>>{};
    final before = <String, Map<String, Object?>>{};
    for (final doc in docs) {
      final fields = <String, Object?>{
        for (final MapEntry(:key, :value) in doc.fields.entries)
          if (!_unreplayedGovernedKeys.contains(key)) key: value,
      };
      final current = await reader.currentDoc(scope, entity.collection, doc.id);
      final changed = <String, Object?>{
        for (final MapEntry(:key, :value) in fields.entries)
          if (!storageValueEquals(current?[key], value)) key: value,
      };
      if (changed.isEmpty) continue;
      final curriculumId = fields[GovernedKeys.curriculumId];
      final entityId = entity.docIdIsEntityId || curriculumId is! String
          ? doc.id
          : curriculumId;
      byEntity
          .putIfAbsent(entityId, () => [])
          .add(
            GovernedDocMerge(
              collection: entity.collection,
              docId: doc.id,
              fields: changed,
            ),
          );
      before[doc.id] = {
        for (final f in changed.keys)
          ChangedFieldKey(entity.collection, doc.id, f).key: current?[f],
      };
    }
    for (final MapEntry(key: entityId, value: merges) in byEntity.entries) {
      for (var i = 0; i < merges.length; i += GovernedBatch.maxDocs) {
        final chunk = merges.sublist(
          i,
          (i + GovernedBatch.maxDocs).clamp(0, merges.length),
        );
        final entry = entryOf(
          entity: entity,
          entityId: entityId,
          before: {for (final m in chunk) ...before[m.docId]!},
          after: {
            for (final m in chunk)
              for (final MapEntry(:key, :value) in m.fields.entries)
                ChangedFieldKey(m.collection, m.docId, key).key: value,
          },
        );
        plan.governed.add(GovernedBatch(entry: entry, merges: chunk));
      }
    }
  }
}

/// Step 3: each sub-track under a fresh id — a create and, when it was
/// ended, a tombstone.
void _planSubTracks(
  BackupReplayPlan plan,
  BackupReplayInput input,
  CommandStamp stamp,
  _EntryOf entryOf,
) {
  final tracks = [...input.subTracks]..sort((a, b) => a.id.compareTo(b.id));
  final ids = stamp.ids(tracks.length);
  for (var i = 0; i < tracks.length; i++) {
    final old = tracks[i];
    final id = ids[i];
    plan.subTrackIds[old.id] = id;
    final stored = old.toStorage();
    final fields = <String, Object?>{
      for (final MapEntry(:key, :value) in stored.entries)
        if (key != SubTrack.kLastChangeId &&
            key != SubTrack.kEndedAt &&
            key != SubTrack.kEndReason)
          key: value,
    };
    String k(String field) => ChangedFieldKey('sub_tracks', id, field).key;
    final create = SubTrackChange.create(
      subTrackId: id,
      changedFields: fields,
      entry: entryOf(
        entity: GovernedEntity.subTrack,
        entityId: id,
        before: {for (final f in fields.keys) k(f): null},
        after: {
          for (final MapEntry(key: f, :value) in fields.entries) k(f): value,
        },
      ),
    );
    SubTrackChange? tombstone;
    final endedAt = old.endedAt;
    final reason = old.endReason;
    if (endedAt != null && reason != null) {
      tombstone = SubTrackChange.tombstone(
        subTrackId: id,
        endedAt: endedAt,
        reason: reason,
        entry: entryOf(
          entity: GovernedEntity.subTrack,
          entityId: id,
          before: {k(SubTrack.kEndedAt): null, k(SubTrack.kEndReason): null},
          after: {
            k(SubTrack.kEndedAt): endedAt.toUtc(),
            k(SubTrack.kEndReason): reason.storage,
          },
        ),
      );
    }
    plan.subTracks.add((create, tombstone));
  }
}

int _byEffectiveAt(LearningEvent a, LearningEvent b) {
  final byTime = effectiveAt(a).compareTo(effectiveAt(b));
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

/// Steps 4 and 5: learns (with re-derived awards), then the voids whose
/// target was mapped.
Future<void> _planEvents(
  BackupReplayPlan plan,
  BackupReplayInput input,
  CommandStamp stamp,
  Future<int> Function(String curriculumId, int? stage) amount,
) async {
  final learns = input.events.where((e) => e.isLearn).toList()
    ..sort(_byEffectiveAt);
  final learnIds = stamp.ids(learns.length);
  final amounts = <(String, int?), int>{};
  for (var i = 0; i < learns.length; i++) {
    final old = learns[i];
    final source = old.source!;
    final copy = LearningEvent.learn(
      id: learnIds[i],
      curriculumId: old.curriculumId!,
      ref: old.ref!,
      level: old.level,
      // A source sub-track absent from the backup keeps its id: the
      // learning is never dropped.
      source: plan.subTrackIds[source] ?? source,
      dateState: old.dateState!,
      learnedOn: old.learnedOn,
      stage: old.stage,
      originalRecordedAt: effectiveAt(old),
      recordedAt: stamp.nowUtc,
      actor: stamp.actor,
    )..toStorage();
    plan.eventIds[old.id] = copy.id;
    int? award;
    if (earnsPointsEntry(copy)) {
      final key = (copy.curriculumId!, copy.stage);
      award = amounts[key] ??= await amount(key.$1, key.$2);
    }
    plan.learns.add(learnUnit(copy, award, stamp.nowUtc));
  }

  final voids = input.events.where((e) => e.isVoid).toList()
    ..sort(_byEffectiveAt);
  final kept = [
    for (final v in voids)
      if (plan.eventIds.containsKey(v.targetId)) v,
  ];
  final voidIds = stamp.ids(kept.length);
  for (var i = 0; i < kept.length; i++) {
    final old = kept[i];
    final reverts = old.revertsActionId;
    final copy = LearningEvent.voidOf(
      id: voidIds[i],
      targetId: plan.eventIds[old.targetId]!,
      revertsActionId: reverts == null
          ? null
          : plan.eventIds[reverts] ?? reverts,
      originalRecordedAt: effectiveAt(old),
      recordedAt: stamp.nowUtc,
      actor: stamp.actor,
    )..toStorage();
    plan.eventIds[old.id] = copy.id;
    plan.voids.add(WriteUnit([copy]));
  }
}

/// Step 6: reward redemptions, then the non-event points entries, under
/// fresh ids.
void _planRecords(
  BackupReplayPlan plan,
  BackupReplayInput input,
  CommandStamp stamp,
) {
  const ulidKey = 'ulid';
  const redemptionKey = 'redemption_ulid';
  final redemptions = [...input.rewardRedemptions]
    ..sort((a, b) => a.id.compareTo(b.id));
  final points = [
    for (final p in input.pointsEntries)
      if (!isEventPointsEntry(p.id, p.fields)) p,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final ids = stamp.ids(redemptions.length + points.length);
  var i = 0;
  final redemptionIds = <String, String>{};
  for (final r in redemptions) {
    final id = ids[i++];
    redemptionIds[r.id] = id;
    final old = r.fields[ulidKey];
    if (old is String) redemptionIds[old] = id;
    plan.records.add(
      BackupRecordWrite(
        collection: BackupRecordCollection.rewardRedemptions,
        docId: id,
        fields: {...r.fields, if (r.fields.containsKey(ulidKey)) ulidKey: id},
      ),
    );
  }
  for (final p in points) {
    final id = ids[i++];
    final redemption = p.fields[redemptionKey];
    plan.records.add(
      BackupRecordWrite(
        collection: BackupRecordCollection.pointsLedger,
        docId: id,
        fields: {
          ...p.fields,
          if (p.fields.containsKey(ulidKey)) ulidKey: id,
          if (redemption is String)
            redemptionKey: redemptionIds[redemption] ?? redemption,
        },
      ),
    );
  }
}

/// Runs AD-49 imports for one [LearnerScope] and owns their "not saved —
/// retry" failures.
final class BackupImportReplay {
  /// Creates the replay.
  BackupImportReplay({
    required LearnerScope scope,
    required ChangeLogRepository changeLog,
    required SubTrackRepository subTracks,
    required GovernedDocReader reader,
    required LearningWritePort writePort,
    required BackupRecordWritePort records,
    LearningFailureReporter? failureReporter,
    this.ackWait = defaultLearningAckWait,
  }) : _scope = scope,
       _changeLog = changeLog,
       _subTracks = subTracks,
       _reader = reader,
       _records = records,
       _failures = GovernedPendingFailures(
         reporter: failureReporter,
         ackWait: ackWait,
       ),
       _events = LearningWriteDispatcher(
         scope: scope,
         port: writePort,
         reporter: failureReporter ?? const _SilentReporter(),
         ackWait: ackWait,
       );

  /// How long one write waits for the server before it counts as queued.
  final Duration ackWait;

  final LearnerScope _scope;
  final ChangeLogRepository _changeLog;
  final SubTrackRepository _subTracks;
  final GovernedDocReader _reader;
  final BackupRecordWritePort _records;
  final GovernedPendingFailures _failures;
  final LearningWriteDispatcher _events;

  static const _kind = LearningCommandKind.backupImport;

  /// Plans and writes [input] at [stamp] (the caller has passed the
  /// capture gate). [amount] is the AD-50 award amount; [afterEvents]
  /// receives the event write's outcome (the achievement latch).
  Future<BackupReplayResult> replay(
    BackupReplayInput input, {
    required CommandStamp stamp,
    required Future<int> Function(String curriculumId, int? stage) amount,
    void Function(DispatchOutcome outcome)? afterEvents,
  }) async {
    final BackupReplayPlan plan;
    try {
      plan = await planBackupReplay(
        input: input,
        scope: _scope,
        stamp: stamp,
        reader: _reader,
        amount: amount,
      );
    } on BackupReplayInvalid {
      return const BackupReplayResult(
        result: CaptureResult.rejected(CaptureRejection.invalid),
      );
    } on Object {
      // A destination doc could not be read: write nothing.
      return const BackupReplayResult(
        result: CaptureResult.rejected(CaptureRejection.notSaved),
      );
    }
    if (plan.isEmpty) {
      return const BackupReplayResult(result: CaptureResult.success());
    }

    final steps = <BackupReplayStep>[];
    final savedChanges = <String>[];
    final failedUnits = <String>[];
    var queued = false;
    var attempted = 0;
    String? actionId;

    Future<void> runUnits(
      BackupReplayStep step,
      List<GovernedWriteUnit> units,
    ) async {
      if (units.isEmpty) return;
      steps.add(step);
      actionId ??= units.first.actionId;
      for (final unit in units) {
        attempted++;
        final pending = unit.send();
        try {
          final acked = await pending
              .then((_) => true)
              .timeout(ackWait, onTimeout: () => false);
          if (!acked) {
            queued = true;
            unawaited(
              pending.then<void>(
                (_) {},
                onError: (Object e) => _failures.record(_kind, unit, e),
              ),
            );
          }
          savedChanges.addAll(unit.changeIds);
        } on Object catch (error) {
          _failures.record(_kind, unit, error);
          failedUnits.add(unit.id);
        }
      }
    }

    await runUnits(BackupReplayStep.learnerSettings, [
      for (final b in plan.settings) _governedUnit(b),
    ]);
    await runUnits(BackupReplayStep.governed, [
      for (final b in plan.governed) _governedUnit(b),
    ]);
    await runUnits(BackupReplayStep.subTracks, [
      for (final (create, tombstone) in plan.subTracks)
        _subTrackUnit(create, tombstone),
    ]);

    final eventIds = <String>[];
    final failedChunks = <String>[];
    final chunks = chunkWrites([...plan.learns, ...plan.voids]);
    if (chunks.isNotEmpty) {
      if (plan.learns.isNotEmpty) steps.add(BackupReplayStep.learnEvents);
      if (plan.voids.isNotEmpty) steps.add(BackupReplayStep.voidEvents);
      attempted += chunks.length;
      try {
        final outcome = await _events.dispatch(_kind, chunks);
        queued = queued || outcome.queued;
        eventIds.addAll(outcome.eventIds);
        final saved = outcome.eventIds.toSet();
        for (final c in chunks) {
          if (!saved.contains(c.events.first.id)) {
            failedChunks.add(c.events.first.id);
          }
        }
        afterEvents?.call(outcome);
      } on Object {
        // A non-permanent failure inside the ack window: nothing of the
        // event step was accepted locally.
        failedChunks.addAll(chunks.map((c) => c.events.first.id));
      }
    }

    await runUnits(BackupReplayStep.records, [
      for (
        var i = 0;
        i < plan.records.length;
        i += BackupRecordWritePort.maxWrites
      )
        _recordUnit(
          plan.records.sublist(
            i,
            (i + BackupRecordWritePort.maxWrites).clamp(0, plan.records.length),
          ),
          actionId,
        ),
    ]);

    final failedEventIds = failedChunks.toSet();
    final failedUnitIds = failedUnits.toSet();
    final notSaved = [
      for (final f in _events.pendingFailures)
        if (failedEventIds.contains(f.id)) f,
      for (final f in _failures.pendingFailures)
        if (failedUnitIds.contains(f.id)) f,
    ];
    final failed = failedChunks.length + failedUnits.length;
    final result = failed == attempted
        ? const CaptureResult.rejected(CaptureRejection.notSaved)
        : CaptureResult.success(
            eventIds: eventIds,
            changeIds: savedChanges,
            actionId: actionId,
            queued: queued,
          );
    return BackupReplayResult(
      result: result,
      notSaved: notSaved,
      subTrackIds: Map.unmodifiable(plan.subTrackIds),
      eventIds: Map.unmodifiable(plan.eventIds),
      steps: List.unmodifiable(steps),
    );
  }

  GovernedWriteUnit _governedUnit(GovernedBatch batch) => GovernedWriteUnit(
    id: batch.entry.id,
    actionId: batch.entry.actionId,
    changeIds: [batch.entry.id],
    writeCount: batch.merges.length + 1,
    queueable: true,
    send: () => _changeLog.commitGoverned(_scope, batch),
  );

  /// One sub-track's create and tombstone. The tombstone pre-reads the
  /// row, so it is sent once the create is acknowledged or, offline, has
  /// waited [ackWait] (its batch is then in the local cache).
  GovernedWriteUnit _subTrackUnit(
    SubTrackChange create,
    SubTrackChange? tombstone,
  ) => GovernedWriteUnit(
    id: create.entry.id,
    actionId: create.entry.actionId,
    changeIds: [create.entry.id, if (tombstone != null) tombstone.entry.id],
    writeCount: tombstone == null ? 2 : 4,
    queueable: true,
    send: () async {
      final created = _subTracks.applyGovernedChange(_scope, create);
      if (tombstone == null) return created;
      await Future.any<void>([created, Future<void>.delayed(ackWait)]);
      final ended = _subTracks.applyGovernedChange(_scope, tombstone);
      await Future.wait([created, ended]);
    },
  );

  GovernedWriteUnit _recordUnit(
    List<BackupRecordWrite> writes,
    String? actionId,
  ) => GovernedWriteUnit(
    id: writes.first.docId,
    actionId: actionId ?? writes.first.docId,
    changeIds: const [],
    writeCount: writes.length,
    queueable: true,
    send: () => _records.commit(_scope, writes),
  );

  /// The import writes the server did not save, live: event chunks, then
  /// governed, sub-track and record batches.
  Stream<List<PendingFailure>> watchPendingFailures() {
    late final StreamController<List<PendingFailure>> out;
    StreamSubscription<List<PendingFailure>>? a;
    StreamSubscription<List<PendingFailure>>? b;
    List<PendingFailure>? latestA;
    List<PendingFailure>? latestB;
    void publish() {
      final x = latestA;
      final y = latestB;
      if (x != null && y != null) out.add(List.unmodifiable([...x, ...y]));
    }

    out = StreamController<List<PendingFailure>>(
      onListen: () {
        a = _events.watchPendingFailures().listen((v) {
          latestA = v;
          publish();
        }, onError: out.addError);
        b = _failures.watchPendingFailures().listen((v) {
          latestB = v;
          publish();
        }, onError: out.addError);
      },
      onCancel: () async {
        await a?.cancel();
        await b?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  /// Re-sends the import failure [pendingFailureId] unchanged; null when
  /// it is not one of this replay's failures. [afterEvents] receives a
  /// retried event chunk's outcome.
  Future<CaptureResult?> retry(
    String pendingFailureId, {
    void Function(DispatchOutcome outcome)? afterEvents,
  }) async {
    final outcome = await _events.retry(pendingFailureId);
    if (outcome == null) return _failures.retry(pendingFailureId);
    if (outcome.allRejected) {
      return const CaptureResult.rejected(CaptureRejection.notSaved);
    }
    afterEvents?.call(outcome);
    return CaptureResult.success(
      eventIds: outcome.eventIds,
      queued: outcome.queued,
    );
  }

  /// Closes the failure streams.
  Future<void> dispose() async {
    await _events.dispose();
    await _failures.dispose();
  }
}

/// The reporter used when none is given.
final class _SilentReporter implements LearningFailureReporter {
  const _SilentReporter();

  @override
  void writeRejected({
    required LearningCommandKind command,
    required PendingFailureReason reason,
    required int writeCount,
  }) {}
}
