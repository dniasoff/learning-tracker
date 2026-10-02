/// In-memory fakes of the learner-state ports for tests written against
/// the C0 (DNI-524) contract.
///
/// Each fake `implements` its port, so a contract change breaks it at
/// compile time. Every store is keyed by [LearnerScope]. Watch streams
/// follow the port contracts: complete reads emit [CompleteReadLoading]
/// first, then a [CompleteReadReady] snapshot, and a new snapshot after
/// every write to the same scope. The fakes are not the spec (C0
/// contract-change protocol, rule 4).
library;

import 'dart:async';

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// Per-scope change notifications shared by the fakes below.
final class _ScopeChanges {
  final _controller = StreamController<LearnerScope>.broadcast(sync: true);

  void notify(LearnerScope scope) => _controller.add(scope);

  /// A single-subscription stream that emits [initial] values on listen,
  /// then [snapshot] after every change to [scope].
  Stream<T> watch<T>(
    LearnerScope scope,
    List<T> Function() initial,
    T Function() snapshot,
  ) {
    late final StreamController<T> out;
    StreamSubscription<LearnerScope>? sub;
    out = StreamController<T>(
      onListen: () {
        initial().forEach(out.add);
        sub = _controller.stream
            .where((s) => s == scope)
            .listen((_) => out.add(snapshot()));
      },
      onCancel: () async {
        await sub?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  Future<void> close() => _controller.close();
}

List<T> _sortedById<T>(Iterable<T> rows, String Function(T) id) =>
    rows.toList()..sort((a, b) => id(a).compareTo(id(b)));

/// In-memory [LearningEventRepository]: append-only, create-only.
final class InMemoryLearningEventRepository implements LearningEventRepository {
  final _changes = _ScopeChanges();
  final Map<LearnerScope, Map<String, LearningEvent>> _events = {};
  final Map<LearnerScope, List<RejectedRow>> _rejected = {};

  /// Every event actually written by [create] (replays excluded), in order.
  final List<(LearnerScope, LearningEvent)> created = [];

  /// Stores [events] for [scope] without recording them as [created].
  void seed(LearnerScope scope, Iterable<LearningEvent> events) {
    final log = _events.putIfAbsent(scope, () => {});
    for (final e in events) {
      log[e.id] = e;
    }
    _changes.notify(scope);
  }

  /// Makes every complete read of [scope] report [rows] as undecodable
  /// (`CompleteReadReady.rejected`), as a malformed stored document would;
  /// an empty list makes the reads clean again.
  void seedRejected(LearnerScope scope, List<RejectedRow> rows) {
    _rejected[scope] = List.of(rows);
    _changes.notify(scope);
  }

  /// The events of [scope] in document-id order.
  List<LearningEvent> eventsOf(LearnerScope scope) =>
      _sortedById(_events[scope]?.values ?? const [], (e) => e.id);

  CompleteReadReady<LearningEvent> _ready(LearnerScope scope) =>
      CompleteReadReady(eventsOf(scope), rejected: _rejected[scope] ?? []);

  @override
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope) =>
      _changes.watch<CompleteRead<LearningEvent>>(
        scope,
        () => [const CompleteReadLoading<LearningEvent>(), _ready(scope)],
        () => _ready(scope),
      );

  @override
  Future<void> create(LearnerScope scope, LearningEvent event) async {
    event.toStorage(); // StorageFormatException before any "I/O".
    final log = _events.putIfAbsent(scope, () => {});
    final existing = log[event.id];
    if (existing != null) {
      if (existing == event) return;
      throw LearningEventConflictException(event.id);
    }
    log[event.id] = event;
    created.add((scope, event));
    _changes.notify(scope);
  }

  /// Closes the change notifier.
  Future<void> dispose() => _changes.close();
}

/// In-memory [SubTrackRepository]. [applyGovernedChange] merges
/// `SubTrackChange.toMergePatch` into the stored row and records the entry,
/// with the same checks as the Firestore implementation (replay, conflict,
/// not found, false baseline, invalid merged row).
final class InMemorySubTrackRepository implements SubTrackRepository {
  final _changes = _ScopeChanges();
  final Map<LearnerScope, Map<String, SubTrack>> _tracks = {};
  final Map<LearnerScope, Map<String, ChangeLogEntry>> _log = {};
  final Map<LearnerScope, List<RejectedRow>> _rejected = {};

  /// Every change-log entry actually written (replays excluded), in order.
  final List<(LearnerScope, ChangeLogEntry)> entries = [];

  /// Every call, in order (replays and refused changes included).
  final List<(LearnerScope, SubTrackChange)> calls = [];

  /// Offline mode (Story 2.1 AC-6): a change is applied locally at once —
  /// visible to [watchAll], like Firestore's latency compensation — but its
  /// future completes only when [settleHeld] runs (the server ack).
  bool offline = false;

  final List<_HeldSubTrackWrite> _held = [];

  PermanentWriteRejection? _nextFailure;

  /// The next applied change is refused by the "server" with [rejection]
  /// (one-shot): online it throws at once; offline it fails at
  /// [settleHeld], reverting the local change like Firestore does.
  void failNextWith(PermanentWriteRejection rejection) =>
      _nextFailure = rejection;

  /// How many offline writes await their server acknowledgement.
  int get heldCount => _held.length;

  /// Acknowledges every held offline write (reconnect). A held write that
  /// was scripted to fail is reverted and its future throws.
  void settleHeld() {
    final held = [..._held];
    _held.clear();
    for (final h in held) {
      final failure = h.failure;
      if (failure == null) {
        h.done.complete();
        continue;
      }
      final rows = _tracks[h.scope]!;
      final before = h.before;
      if (before == null) {
        rows.remove(h.change.subTrackId);
      } else {
        rows[h.change.subTrackId] = before;
      }
      _log[h.scope]!.remove(h.change.entry.id);
      entries.removeWhere((e) => e.$2.id == h.change.entry.id);
      _changes.notify(h.scope);
      h.done.completeError(failure);
    }
  }

  /// Stores [tracks] for [scope].
  void seed(LearnerScope scope, Iterable<SubTrack> tracks) {
    final rows = _tracks.putIfAbsent(scope, () => {});
    for (final t in tracks) {
      rows[t.id] = t;
    }
    _changes.notify(scope);
  }

  /// Makes every complete read of [scope] report [rows] as undecodable
  /// (`CompleteReadReady.rejected`); an empty list makes them clean again.
  void seedRejected(LearnerScope scope, List<RejectedRow> rows) {
    _rejected[scope] = List.of(rows);
    _changes.notify(scope);
  }

  /// The sub-tracks of [scope] in document-id order.
  List<SubTrack> tracksOf(LearnerScope scope) =>
      _sortedById(_tracks[scope]?.values ?? const [], (t) => t.id);

  CompleteReadReady<SubTrack> _ready(LearnerScope scope) =>
      CompleteReadReady(tracksOf(scope), rejected: _rejected[scope] ?? []);

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) =>
      _changes.watch<CompleteRead<SubTrack>>(
        scope,
        () => [const CompleteReadLoading<SubTrack>(), _ready(scope)],
        () => _ready(scope),
      );

  @override
  Future<void> applyGovernedChange(
    LearnerScope scope,
    SubTrackChange change,
  ) async {
    calls.add((scope, change));
    final log = _log.putIfAbsent(scope, () => {});
    final existing = log[change.entry.id];
    if (existing != null) {
      if (existing == change.entry) return;
      throw ChangeLogConflictException(change.entry.id);
    }
    final failure = _nextFailure;
    _nextFailure = null;
    if (failure != null && !offline) throw failure;
    final rows = _tracks.putIfAbsent(scope, () => {});
    final current = rows[change.subTrackId];
    if (current == null && !change.isCreate) {
      throw SubTrackNotFoundException(change.subTrackId);
    }
    final stored = current?.toStorage() ?? const <String, Object?>{};
    for (final MapEntry(:key, :value) in change.entry.before.entries) {
      final field = ChangedFieldKey.tryParse(key)!.field;
      if (!storageValueEquals(stored[field], value)) {
        throw ChangeBaselineMismatchException(change.subTrackId, field);
      }
    }
    rows[change.subTrackId] = SubTrack.fromStorage(change.subTrackId, {
      ...stored,
      ...change.toMergePatch(),
    });
    log[change.entry.id] = change.entry;
    entries.add((scope, change.entry));
    _changes.notify(scope);
    if (offline) {
      final held = _HeldSubTrackWrite(scope, change, current, failure);
      _held.add(held);
      return held.done.future;
    }
  }

  /// Closes the change notifier.
  Future<void> dispose() => _changes.close();
}

/// One offline sub-track write awaiting its server acknowledgement.
final class _HeldSubTrackWrite {
  _HeldSubTrackWrite(this.scope, this.change, this.before, this.failure);

  final LearnerScope scope;
  final SubTrackChange change;
  final SubTrack? before;
  final PermanentWriteRejection? failure;
  final Completer<void> done = Completer<void>();
}

/// In-memory [ChangeLogRepository]. [commitGoverned] merges each
/// `GovernedDocMerge.toMergePatch` into [doc] and records the entry.
final class InMemoryChangeLogRepository implements ChangeLogRepository {
  final _changes = _ScopeChanges();
  final Map<LearnerScope, Map<String, ChangeLogEntry>> _log = {};
  final Map<LearnerScope, Map<String, Map<String, Object?>>> _docs = {};

  /// Every batch actually committed (replays excluded), in order.
  final List<(LearnerScope, GovernedBatch)> batches = [];

  /// Stores [entries] for [scope] (e.g. a prior intent history).
  void seed(LearnerScope scope, Iterable<ChangeLogEntry> entries) {
    final log = _log.putIfAbsent(scope, () => {});
    for (final e in entries) {
      log[e.id] = e;
    }
    _changes.notify(scope);
  }

  /// Every entry of [scope] in document-id order.
  List<ChangeLogEntry> entriesOf(LearnerScope scope) =>
      _sortedById(_log[scope]?.values ?? const [], (e) => e.id);

  /// The merged fields of `{collection}/{docId}` in [scope], or null.
  Map<String, Object?>? doc(
    LearnerScope scope,
    String collection,
    String docId,
  ) => _docs[scope]?['$collection/$docId'];

  List<ChangeLogEntry> _history(LearnerScope scope) => entriesOf(
    scope,
  ).where((e) => intentHistoryEntities.contains(e.entity)).toList();

  bool _isReverted(LearnerScope scope, String actionId) =>
      _log[scope]?.values.any((e) => e.revertsActionId == actionId) ?? false;

  @override
  Stream<CompleteRead<ChangeLogEntry>> watchIntentHistory(LearnerScope scope) =>
      _changes.watch<CompleteRead<ChangeLogEntry>>(
        scope,
        () => [
          const CompleteReadLoading<ChangeLogEntry>(),
          CompleteReadReady(_history(scope)),
        ],
        () => CompleteReadReady(_history(scope)),
      );

  @override
  Future<List<ChangeLogEntry>> entriesOfAction(
    LearnerScope scope,
    String actionId,
  ) async => entriesOf(scope).where((e) => e.actionId == actionId).toList();

  @override
  Stream<bool> watchIsReverted(LearnerScope scope, String actionId) => _changes
      .watch<bool>(
        scope,
        () => [_isReverted(scope, actionId)],
        () => _isReverted(scope, actionId),
      )
      .distinct();

  @override
  Future<void> commitGoverned(LearnerScope scope, GovernedBatch batch) async {
    final log = _log.putIfAbsent(scope, () => {});
    final entry = batch.entry;
    final existing = log[entry.id];
    if (existing != null) {
      if (existing == entry) return;
      throw ChangeLogConflictException(entry.id);
    }
    final docs = _docs.putIfAbsent(scope, () => {});
    for (final merge in batch.merges) {
      final key = '${merge.collection}/${merge.docId}';
      docs[key] = {...?docs[key], ...merge.toMergePatch(entry.id)};
    }
    log[entry.id] = entry;
    batches.add((scope, batch));
    _changes.notify(scope);
  }

  /// Closes the change notifier.
  Future<void> dispose() => _changes.close();
}

/// In-memory [GovernedIntentRepository]. [watch] emits nothing (loading)
/// until [emit] sets the scope's intent, then every later [emit].
final class InMemoryGovernedIntentRepository
    implements GovernedIntentRepository {
  final _changes = _ScopeChanges();
  final Map<LearnerScope, LearnerIntent> _intents = {};

  /// Sets the complete intent of [scope].
  void emit(LearnerScope scope, LearnerIntent intent) {
    _intents[scope] = intent;
    _changes.notify(scope);
  }

  @override
  Stream<LearnerIntent> watch(LearnerScope scope) =>
      _changes.watch<LearnerIntent>(
        scope,
        () => [if (_intents[scope] case final intent?) intent],
        () => _intents[scope]!,
      );

  /// Closes the change notifier.
  Future<void> dispose() => _changes.close();
}

/// In-memory [LearningWritePort]: records committed chunks; can be
/// scripted to reject the next commit permanently.
final class InMemoryLearningWritePort implements LearningWritePort {
  /// Every committed chunk with its scope, in order.
  final List<(LearnerScope, LearningWriteChunk)> commits = [];

  /// Every commit attempt (committed, failed or held), in order.
  final List<LearningWriteChunk> attempts = [];

  PermanentWriteRejection? _nextFailure;
  final List<Completer<void>> _holds = [];
  int _toHold = 0;

  /// The committed chunks, in order.
  List<LearningWriteChunk> get chunks => [for (final (_, c) in commits) c];

  /// Makes the next [commit] throw [rejection] and record nothing.
  void failNextWith(PermanentWriteRejection rejection) =>
      _nextFailure = rejection;

  /// Makes the next [count] commits wait for the server: each stays
  /// pending (the SDK has queued it offline) until [release] or [reject].
  /// Added by DNI-469.
  void holdNext([int count = 1]) => _toHold += count;

  /// The commits currently held.
  int get heldCount => _holds.length;

  /// Acknowledges the oldest held commit (records it as committed).
  void release() => _holds.removeAt(0).complete();

  /// Rejects the oldest held commit with [rejection].
  void reject(Object rejection) => _holds.removeAt(0).completeError(rejection);

  @override
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk) async {
    attempts.add(chunk);
    final failure = _nextFailure;
    if (failure != null) {
      _nextFailure = null;
      throw failure;
    }
    if (_toHold > 0) {
      _toHold--;
      final held = Completer<void>();
      _holds.add(held);
      await held.future;
    }
    commits.add((scope, chunk));
  }
}

/// Fake [OversizedGovernedWritePort]: throws [OnlineRequiredException]
/// while [online] is false; otherwise records the request and returns
/// [nextReceipt] (one-shot) or a receipt echoing the request's ids.
final class FakeOversizedGovernedWritePort
    implements OversizedGovernedWritePort {
  /// Creates the fake, online by default.
  FakeOversizedGovernedWritePort({this.online = true});

  /// Whether the device is online.
  bool online;

  /// The receipt the next [write] returns, if scripted.
  GovernedWriteReceipt? nextReceipt;

  /// Every request sent while online, with its scope.
  final List<(LearnerScope, OversizedGovernedWrite)> requests = [];

  @override
  Future<GovernedWriteReceipt> write(
    LearnerScope scope,
    OversizedGovernedWrite request,
  ) async {
    if (!online) throw const OnlineRequiredException();
    requests.add((scope, request));
    final scripted = nextReceipt;
    nextReceipt = null;
    return scripted ??
        GovernedWriteReceipt(
          actionId: request.actionId,
          changeIds: [for (final e in request.entries) e.entryId],
        );
  }
}
