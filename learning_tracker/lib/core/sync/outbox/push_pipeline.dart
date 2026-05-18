/// Abstract interface for pushing local mutations to Firestore.
///
/// Each method handles one entity kind. Implemented by `OutboxPushPipeline`
/// (Story 25.12 — SyncEngine decomp Part 1).
///
/// The `OutboxProcessor` calls these methods when draining the outbox table.
/// Each method receives the raw JSON `payload` stored in the outbox row and
/// the `profileId` that owns the mutation.
library;

import 'package:learning_tracker/core/sync/firestore_gateway.dart';

abstract class PushPipeline {
  Future<void> pushCompletion({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  /// Push multiple completions in a single batched operation and report which
  /// entries committed.
  ///
  /// Each entry in [entries] is a record of `(entityKey, payload)`. The
  /// gateway derives the deterministic Firestore doc ID from the payload's
  /// structured natural key — the `entityKey` is only used to report which
  /// rows committed.
  ///
  /// Returns the entityKeys of the completions that genuinely reached
  /// Firestore. On full success that is every entityKey; on a partial
  /// (per-chunk) failure the implementation throws a [BatchPushException]
  /// whose `committed` field lists the entityKeys that did land.
  ///
  /// Implementations must:
  ///  1. Pass all entries to [FirestoreGateway.pushCompletionsBatch].
  ///  2. Never call [pushCompletion] in a loop — that defeats the batching.
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  });

  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushLearningOrder({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });

  Future<void> pushBookmark({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  });
}
