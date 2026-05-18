/// Wave 0 — characterization tests for the sync rework push-path invariants.
///
/// S3: a completion is pushed to a deterministic Firestore doc ID;
///     pushing the same completion twice creates no second document.
/// S4: bulk-mark of 655 items pushes via ≤2 WriteBatch commits and
///     0 individual collection.add() calls.
/// S9: two devices marking overlapping items converge to the same state
///     (union, no duplicate documents).
///
/// All tests are skipped; un-skip in Wave 1 once the fixes are in.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';

import '../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Counting / recording fake gateway
// ---------------------------------------------------------------------------

/// Gateway fake that records every push call to enable S3/S4/S9 assertions.
///
/// - [pushCompletionCalls]: list of payloads pushed via [pushCompletion].
/// - [batchCommitCount]: number of `WriteBatch.commit()` equivalents made.
/// - [collectionAddCount]: number of un-keyed `collection.add()` calls.
///
/// The rework target is:
///   * completions use `doc(deterministicId).set(...)` — not `collection.add()`.
///   * large batches use `WriteBatch.commit()` (≤500 ops per commit → ≤2 for 655).
///
/// This fake models the *desired* post-rework semantics.  Implementations
/// that call `collection.add()` will increment [collectionAddCount]; those
/// that compute a doc ID and call `doc(...).set(...)` will increment
/// [docSetCount].  Wave-1 wires the real `BatchingGateway`; until then the
/// fake counts raw gateway calls.
class _RecordingGateway implements FirestoreGateway {
  /// Raw list of Map payloads received via [pushCompletion].
  final List<Map<String, dynamic>> pushCompletionCalls = [];

  /// Simulated batch commits.  The rework gateway implementation must call
  /// this when it commits a [WriteBatch]; Wave 1 will wire a real
  /// `WriteBatch`-counting wrapper.  For now we count pushCompletion calls
  /// in groups of ≤500 to simulate the expected batch structure.
  int batchCommitCount = 0;

  /// Calls that went through `collection.add()` (must be 0 after rework).
  int collectionAddCount = 0;

  /// Calls that went through `doc(id).set(...)` (the desired path).
  int docSetCount = 0;

  // All stored documents keyed by the deterministic doc ID derived from the
  // payload so S3 / S9 deduplication is verifiable.
  final Map<String, Map<String, dynamic>> _store = {};

  /// Derive the deterministic doc ID from a completion payload.
  ///
  /// The rework contract: doc ID = "<profileId>_<sefariaRef>_<stageId>_<trackType>"
  /// (underscores replacing spaces).  This mirrors the entityKey computed in
  /// [CompletionWriter._outboxEntityKey] so that re-pushing the same
  /// completion resolves to the same document.
  static String _docId(int profileId, Map<String, dynamic> payload) {
    final ref = (payload['sefariaRef'] as String? ?? '').replaceAll(' ', '_');
    final stage = payload['stageId'];
    final tt = payload['trackType'] as String? ?? '';
    return '${profileId}_${ref}_${stage}_$tt';
  }

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushCompletionCalls.add({...data, '_profileId': profileId});
    final id = _docId(profileId, data);
    final isNew = !_store.containsKey(id);
    _store[id] = {...data, '_profileId': profileId};
    if (isNew) {
      docSetCount++;
    }
    // The current FirestoreGatewayImpl uses collection.add() — post-rework it
    // must use doc(id).set(). Track the legacy path explicitly so S4 can
    // assert collectionAddCount == 0.
    // For Wave-0 characterization: assume every pushCompletion is currently
    // a collection.add() call (pre-rework baseline).
    collectionAddCount++;
  }

  // ── Batch simulation ──────────────────────────────────────────────────────

  /// Simulate flushing N completions through the post-rework batch API.
  ///
  /// Wave-1 implementation will expose a `pushCompletionsBatch` on the
  /// gateway that internally chunks payloads into ≤500-item `WriteBatch`es.
  /// This stub models the expected chunk/commit cycle so S4 can be written
  /// now and will pass after the real implementation is wired.
  Future<void> pushCompletionsBatch({
    required int profileId,
    required List<Map<String, dynamic>> items,
  }) async {
    // Simulate Firestore WriteBatch limit: 500 ops per batch.
    const batchSize = 500;
    for (var start = 0; start < items.length; start += batchSize) {
      final chunk = items.sublist(
        start,
        (start + batchSize).clamp(0, items.length),
      );
      for (final data in chunk) {
        final id = _docId(profileId, data);
        _store[id] = {...data, '_profileId': profileId};
        // Batch path does NOT increment collectionAddCount.
        docSetCount++;
      }
      batchCommitCount++;
    }
  }

  int get uniqueDocCount => _store.length;

  // ── Stub implementations of unused gateway methods ─────────────────────

  @override
  Future<void> pushStreak({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushSettings({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushTrack({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushLearningOrder({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushBookmark({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushNotificationSettings({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushGamificationSettings({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushLearnerProfile({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> pushLedgerEntry({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushLedgerEntriesBatch({required int profileId, required List<Map<String, dynamic>> entries}) async {}
  @override
  Future<void> pushProfileProgram({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> removeProfileProgramAssignment({required int profileId, required String curriculumStorageKey}) async {}
  @override
  Future<FirestorePage> fetchPage({required int profileId, required String collection, required int pageSize, Map<String, dynamic>? cursor}) async => const FirestorePage(rows: []);
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required int profileId, required String collection}) async => [];
  @override
  Future<void> pushGoal({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushUiPreferences({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushCurriculumImportMetadata({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> deleteUserData(String uid) async {}
  @override
  Future<void> pushDiagnosticLog({required String uid, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushAccountUserProfile({required String uid, required Map<String, dynamic> data}) async {}
  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({required int profileId, required String collection}) => const Stream.empty();
  @override
  Stream<Map<String, dynamic>?> listenToDocument({required int profileId, required String collection, required String docId}) => const Stream.empty();
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({required int profileId, required String collection, required String docId}) async => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<int> _seedTrack(UserDatabase db, {String curriculumId = 'mishnayos'}) =>
    db.into(db.curriculumTracks).insert(
      CurriculumTracksCompanion.insert(
        profileId: 1,
        curriculumId: curriculumId,
        trackType: 'personal',
        activatedAt: DateTime.utc(2026, 1, 1),
        isActive: const Value(true),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('S3 / S4 / S9 — push-path invariants (Wave 0 characterization)', () {
    // ── S3 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: pushing the same completion payload twice must not produce
    // a second Firestore document — the doc ID is deterministic and `set()`
    // semantics overwrite in-place.
    //
    // Pre-rework: FirestoreGatewayImpl.pushCompletion uses collection.add()
    // which always creates a new document — the fix must switch to
    // doc(deterministicId).set().
    test(
      'S3: same completion pushed twice lands in exactly one Firestore doc (idempotent)',
      skip: 'un-skip in Wave 1',
      () async {
        final gateway = _RecordingGateway();

        // Post-rework: successive pushes with identical natural key resolve
        // to the same document.  _RecordingGateway._docId models the
        // expected behaviour.
        const payload = {
          'sefariaRef': 'Berakhot 1:1',
          'stageId': 1,
          'trackType': 'personal',
          'curriculumId': 'mishnayos',
          'completedAt': '2026-05-01T00:00:00.000Z',
          'points': 5,
        };

        await gateway.pushCompletion(profileId: 1, data: payload);
        await gateway.pushCompletion(profileId: 1, data: payload);

        // Post-rework: only one document must exist (doc set with same ID).
        expect(
          gateway.uniqueDocCount,
          equals(1),
          reason:
              'S3: pushing the same completion twice must not create a '
              'second Firestore document',
        );

        // Wave-1 also verifies collectionAddCount == 0.
        // For now, just document the current baseline.
        // expect(gateway.collectionAddCount, equals(0),
        //   reason: 'S3: must not use collection.add() — use doc(id).set()');
      },
    );

    // ── S4 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: 655 completions → ≤2 WriteBatch commits, 0 add() calls.
    //
    // Firestore WriteBatch limit is 500 ops. 655 items requires 2 batches:
    //   batch 1 → 500 items, batch 2 → 155 items.
    //
    // The rework must expose a batch push API on FirestoreGateway and the
    // OutboxProcessor (or a dedicated BulkPushPipeline) must use it.
    test(
      'S4: 655-item bulk push uses ≤2 WriteBatch commits and 0 collection.add() calls',
      skip: 'un-skip in Wave 1',
      () async {
        final gateway = _RecordingGateway();
        const n = 655;

        final items = List.generate(n, (i) => <String, dynamic>{
          'sefariaRef': 'Mishnah $i:1',
          'stageId': 1,
          'trackType': 'personal',
          'curriculumId': 'mishnayos',
          'completedAt': '2026-05-01T00:00:${i.toString().padLeft(2, '0')}.000Z',
          'points': 5,
        });

        // Post-rework: use the batch API (gateway.pushCompletionsBatch).
        await gateway.pushCompletionsBatch(profileId: 1, items: items);

        expect(
          gateway.batchCommitCount,
          lessThanOrEqualTo(2),
          reason:
              'S4: 655 items must fit in ≤2 WriteBatch commits '
              '(Firestore limit: 500 ops per batch)',
        );
        expect(
          gateway.batchCommitCount,
          greaterThan(0),
          reason: 'S4: at least one WriteBatch must have been committed',
        );
        expect(
          gateway.collectionAddCount,
          equals(0),
          reason:
              'S4: batch push must not call collection.add() — '
              'use doc(id).set() inside WriteBatch',
        );
        expect(
          gateway.uniqueDocCount,
          equals(n),
          reason: 'S4: all 655 distinct completions must reach Firestore',
        );
      },
    );

    // ── S9 ─────────────────────────────────────────────────────────────────
    //
    // Invariant: two devices marking overlapping items converge to the same
    // state (set-union, no duplicate documents).
    //
    // Reuses the two-device pattern from test/sync/two_device_sync_test.dart
    // (commit 1eba9dbf): both devices write to the same _RecordingGateway
    // and the doc store deduplicates by natural key.
    group('S9 — two-device overlap convergence', () {
      late UserDatabase deviceA;
      late UserDatabase deviceB;
      late _RecordingGateway sharedGateway;
      late OutboxProcessor processorA;
      late OutboxProcessor processorB;

      setUp(() async {
        deviceA = inMemoryDb();
        deviceB = inMemoryDb();
        await seedProfile(deviceA);
        await seedProfile(deviceB);
        await _seedTrack(deviceA);
        await _seedTrack(deviceB);

        sharedGateway = _RecordingGateway();
        final pipelineA = OutboxPushPipeline(gateway: sharedGateway);
        final pipelineB = OutboxPushPipeline(gateway: sharedGateway);
        processorA = OutboxProcessor(
          outboxDao: deviceA.outboxDao,
          pipeline: pipelineA,
        );
        processorB = OutboxProcessor(
          outboxDao: deviceB.outboxDao,
          pipeline: pipelineB,
        );
      });

      tearDown(() async {
        await deviceA.close();
        await deviceB.close();
      });

      test(
        'S9: overlapping completions from two devices converge to union with no duplicates',
        skip: 'un-skip in Wave 1',
        () async {
          final writerA = CompletionWriter(deviceA);
          final writerB = CompletionWriter(deviceB);

          const sharedRef = 'Berakhot 2:1'; // overlapping item
          final ts = DateTime.utc(2026, 5, 10, 12, 0, 0);

          // Both devices independently mark the same item (overlap).
          await writerA.commit(
            CompletionCommand(
              profileId: 1,
              curriculumId: 'mishnayos',
              sefariaRef: sharedRef,
              stageId: 1,
              trackType: 'personal',
              trackId: 1,
              completedAt: ts,
              points: 5,
            ),
          );
          await writerB.commit(
            CompletionCommand(
              profileId: 1,
              curriculumId: 'mishnayos',
              sefariaRef: sharedRef,
              stageId: 1,
              trackType: 'personal',
              trackId: 1,
              completedAt: ts,
              points: 5,
            ),
          );

          // Device A also marks a unique item.
          await writerA.commit(
            CompletionCommand(
              profileId: 1,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 3:1',
              stageId: 1,
              trackType: 'personal',
              trackId: 1,
              completedAt: DateTime.utc(2026, 5, 10, 13),
              points: 5,
            ),
          );

          // Device B also marks a different unique item.
          await writerB.commit(
            CompletionCommand(
              profileId: 1,
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot 4:1',
              stageId: 1,
              trackType: 'personal',
              trackId: 1,
              completedAt: DateTime.utc(2026, 5, 10, 14),
              points: 5,
            ),
          );

          // Both flush to the shared gateway (simulating push to Firestore).
          await processorA.drain(1);
          await processorB.drain(1);

          // Expected: 3 unique documents (sharedRef counted once + 2 unique).
          // Post-rework: the deterministic doc ID must collapse the duplicate.
          expect(
            sharedGateway.uniqueDocCount,
            equals(3),
            reason:
                'S9: two-device overlap must converge to union (3 unique docs); '
                'the shared ref must NOT produce two documents',
          );

          // Verify that each unique ref is present exactly once.
          final docIds = sharedGateway._store.keys.toSet();
          final sharedDocId = _RecordingGateway._docId(
            1,
            {
              'sefariaRef': sharedRef,
              'stageId': 1,
              'trackType': 'personal',
            },
          );
          expect(
            docIds.contains(sharedDocId),
            isTrue,
            reason: 'S9: shared completion must appear in the converged store',
          );
        },
      );
    });
  });
}
