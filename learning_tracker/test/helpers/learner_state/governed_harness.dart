/// A [DefaultGovernedLearningCommands] over the in-memory ports, shared by
/// the DNI-470 governed-change and undo command tests.
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/history_page.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_action_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';

import '../learner_state_fixtures.dart';
import 'c0_fixtures.dart';
import 'engine_fixtures.dart';
import 'in_memory_ports.dart';

/// The governed test clock.
final governedNow = DateTime.utc(2026, 9, 10, 12);

/// A child actor (another device / session).
const childActor = Actor(
  uid: 'child-uid',
  role: ActorRole.child,
  displayName: 'Dovi',
);

/// A [ChangeLogRepository] whose commits can be held (queued offline) or
/// failed, recording the order commits were issued in.
final class ScriptedChangeLog implements ChangeLogRepository {
  /// Wraps [inner].
  ScriptedChangeLog(this.inner);

  /// Where accepted batches land.
  final InMemoryChangeLogRepository inner;

  /// Entry ids in the order their commits were issued.
  final List<String> issued = [];

  /// Entry ids whose commit stays pending until [release].
  final Set<String> hold = {};

  /// Entry ids whose commit throws the mapped error.
  final Map<String, Exception> fail = {};

  final Map<String, Completer<void>> _held = {};

  /// Acknowledges the held commit of [entryId].
  void release(String entryId) => _held.remove(entryId)!.complete();

  /// Fails the held commit of [entryId] with [error] (a queued batch the
  /// server refuses later).
  void rejectHeld(String entryId, Exception error) =>
      _held.remove(entryId)!.completeError(error);

  @override
  Future<void> commitGoverned(LearnerScope scope, GovernedBatch batch) async {
    final id = batch.entry.id;
    issued.add(id);
    final error = fail[id];
    if (error != null) throw error;
    await inner.commitGoverned(scope, batch); // applied locally at once
    if (hold.contains(id)) {
      final c = _held[id] = Completer<void>();
      await c.future;
    }
  }

  @override
  Future<HistoryPage<ChangeLogEntry>> historyPage(
    LearnerScope scope, {
    HistoryCursor? after,
    int limit = kChangeHistoryPageSize,
  }) => inner.historyPage(scope, after: after, limit: limit);

  @override
  Future<List<ChangeLogEntry>> entriesOfAction(
    LearnerScope scope,
    String actionId,
  ) => inner.entriesOfAction(scope, actionId);

  @override
  Stream<CompleteRead<ChangeLogEntry>> watchIntentHistory(LearnerScope scope) =>
      inner.watchIntentHistory(scope);

  @override
  Stream<bool> watchIsReverted(LearnerScope scope, String actionId) =>
      inner.watchIsReverted(scope, actionId);
}

/// A [GovernedDocReader] that reads `sub_tracks` rows from [subTracks] and
/// everything else from [changeLog], counting reads.
final class HarnessReader implements GovernedDocReader {
  /// Creates the reader.
  HarnessReader(this.changeLog, this.subTracks);

  /// Non-sub-track docs and entries.
  final InMemoryChangeLogRepository changeLog;

  /// Sub-track rows.
  final InMemorySubTrackRepository subTracks;

  /// Every doc read, as `{collection}/{docId}`.
  final List<String> reads = [];

  /// When set, every doc read throws it.
  Exception? failWith;

  @override
  Future<Map<String, Object?>?> currentDoc(
    LearnerScope scope,
    String collection,
    String docId,
  ) async {
    reads.add('$collection/$docId');
    final error = failWith;
    if (error != null) throw error;
    if (collection == 'sub_tracks') {
      for (final t in subTracks.tracksOf(scope)) {
        if (t.id == docId) return t.toStorage();
      }
      return null;
    }
    return changeLog.currentDoc(scope, collection, docId);
  }

  @override
  Future<ChangeLogEntry?> entry(LearnerScope scope, String entryId) =>
      changeLog.entry(scope, entryId);
}

/// The commands under test plus their in-memory ports.
final class GovernedHarness {
  /// Creates the harness; ids are `engineUlid(firstId)`, `+1`, ...
  GovernedHarness({
    Actor actor = parentActor,
    int firstId = 100,
    InMemoryChangeLogRepository? store,
    InMemorySubTrackRepository? subTracks,
    OversizedGovernedWritePort? oversizedPort,
    this.failureReporter,
    this.ackWait = const Duration(milliseconds: 20),
  }) : _next = firstId,
       store = store ?? InMemoryChangeLogRepository(),
       subTracks = subTracks ?? InMemorySubTrackRepository() {
    changeLog = ScriptedChangeLog(this.store);
    reader = HarnessReader(this.store, this.subTracks);
    commands = DefaultGovernedLearningCommands(
      scope: scope,
      actor: actor,
      changeLog: changeLog,
      subTracks: this.subTracks,
      reader: reader,
      oversized: oversizedPort ?? oversized,
      clock: () => governedNow,
      newUlid: (at) {
        assert(at == governedNow, 'ids are minted at the command instant');
        return engineUlid(_next++);
      },
      failureReporter: failureReporter,
      ackWait: ackWait,
    );
  }

  /// Receives the governed write rejections, when set.
  final LearningFailureReporter? failureReporter;

  int _next;

  /// The scope every command writes to.
  final LearnerScope scope = c0Scope();

  /// The batch ack wait.
  final Duration ackWait;

  /// Governed docs and the change log.
  final InMemoryChangeLogRepository store;

  /// Sub-track rows.
  final InMemorySubTrackRepository subTracks;

  /// The scripted change log the commands write through.
  late final ScriptedChangeLog changeLog;

  /// The doc reader the commands read through.
  late final HarnessReader reader;

  /// The oversized callable fake.
  final FakeOversizedGovernedWritePort oversized =
      FakeOversizedGovernedWritePort();

  /// The commands.
  late final DefaultGovernedLearningCommands commands;

  /// The stored fields of `{collection}/{docId}`.
  Map<String, Object?>? doc(String collection, String docId) =>
      store.doc(scope, collection, docId);

  /// Seeds `{collection}/{docId}` with [fields].
  void seedDoc(String collection, String docId, Map<String, Object?> fields) =>
      store.seedDoc(scope, collection, docId, fields);

  /// Every committed batch, in order.
  List<GovernedBatch> get batches => [for (final (_, b) in store.batches) b];
}

/// A one-entity action patching [docs] of [entity] [entityId].
GovernedAction oneEntity(
  GovernedEntity entity,
  String entityId,
  List<GovernedDocPatch> docs,
) => GovernedAction([
  GovernedEntityChange(entity: entity, entityId: entityId, docs: docs),
]);

/// A patch of `{entity.collection}/{docId}`.
GovernedDocPatch patch(
  GovernedEntity entity,
  String docId,
  Map<String, Object?> fields, {
  DocMode mode = DocMode.upsert,
}) => GovernedDocPatch(
  collection: entity.collection,
  docId: docId,
  fields: fields,
  mode: mode,
);
