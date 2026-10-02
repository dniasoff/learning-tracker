/// Firestore implementation of [LearningEventRepository] —
/// `users/{uid}/learner_profiles/{profileId}/learning_events/{ulid}`.
///
/// Story 1.2 (DNI-464) is the sole creator of this file (orchestrator
/// ruling B4); later stories extend it (chunked batch capture, history
/// paging) rather than recreating it.
///
/// - **Reads** go through [watchCompletePaged]: document-id pages of ≤ 500,
///   one loading emission, one complete emission, AD-9 recovery.
/// - **Writes** are create-only `set()` at the event's own client ULID.
///   The payload is the event's validated AD-52 map with timestamps
///   converted to Firestore `Timestamp`s — never a `FieldValue`, so a
///   retry re-sends byte-for-byte the same value (AD-46).
/// - **Create-only guard.** Before the `set()`, the doc is read through
///   [readExistingForCreate] (local cache, then server; see
///   `create_only_guard.dart`): an existing identical event makes the call a
///   no-op (idempotent replay); an existing different (or undecodable) event
///   throws [LearningEventConflictException] and nothing is written, so a
///   conflicting replay can never overwrite an appended event. A cache or
///   server read FAILURE is rethrown, never treated as "absent". Only an
///   offline client (server `unavailable`) proceeds without a remote check:
///   the write stays queueable offline (AD-38 offline owner create) and the
///   AD-46 rules whitelist (create-only plus identical replay, Story 1.9)
///   rejects a non-identical write at sync time.
/// - **Chunked command writes** ([commit], DNI-469, the [LearningWritePort]
///   of `LearningCommands`): one `WriteBatch` per chunk holding its events
///   and their `points_ledger/pts_{eventId}` entries (AD-50, AD-54 "each
///   chunk is self-contained"). Every payload is the prebuilt chunk's —
///   ids and times fixed before the first attempt — so a retry re-sends an
///   identical batch, which the AD-46 rules accept as an identical replay.
///   The SDK owns the offline queue (parent AD-8): the returned future
///   completes on server acknowledgement, and a terminal server rejection
///   surfaces as [PermanentWriteRejection].
/// - The `{uid}` path segment is the caller-supplied [LearnerScope.ownerUid]
///   (the persisted path uid, or a grant's owner uid — ruling B10), never
///   read from the live Auth user here.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/create_only_guard.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/data/repositories/paged_complete_query.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';

/// `learning_events` collection name.
const kLearningEventsCollection = 'learning_events';

/// Profile-scoped `learning_events` repository.
final class FirestoreLearningEventRepository
    implements LearningEventRepository, LearningWritePort {
  /// Creates the repository over an account-scoped [firestore] handle
  /// (resolved from `activeAccountFirebaseProvider`).
  FirestoreLearningEventRepository({
    required FirebaseFirestore firestore,
    this.backoffBase = const Duration(seconds: 1),
    this.backoffCap = const Duration(seconds: 30),
    this.random,
    this.onListenerError,
    this.pageProbe,
    CreateGuardRead? guardRead,
  }) : _firestore = firestore,
       _guardRead = guardRead ?? readExistingForCreate;

  final FirebaseFirestore _firestore;

  /// The create-only pre-read (tests inject cache/server outcomes).
  final CreateGuardRead _guardRead;

  /// AD-9 resubscribe backoff base.
  final Duration backoffBase;

  /// AD-9 resubscribe backoff cap.
  final Duration backoffCap;

  /// Jitter source (tests pin it).
  final math.Random? random;

  /// Called for each stream-level listener failure.
  final void Function(Object error, StackTrace stackTrace)? onListenerError;

  /// Test seam: observes every page query.
  final PageProbe? pageProbe;

  /// `users/{ownerUid}/learner_profiles/{profileId}/learning_events`.
  CollectionReference<Map<String, dynamic>> collectionFor(LearnerScope scope) =>
      _firestore
          .collection('users')
          .doc(scope.ownerUid)
          .collection('learner_profiles')
          .doc(scope.profileId)
          .collection(kLearningEventsCollection);

  @override
  Stream<CompleteRead<LearningEvent>> watchAll(LearnerScope scope) =>
      watchCompletePaged<LearningEvent>(
        collection: collectionFor(scope),
        decode: LearningEvent.fromStorage,
        backoffBase: backoffBase,
        backoffCap: backoffCap,
        random: random,
        onError: onListenerError,
        probe: pageProbe,
      );

  @override
  Future<void> create(LearnerScope scope, LearningEvent event) async {
    // Validates (throws StorageFormatException) before any I/O, and never
    // lets a null/invalid id reach `.doc()` — which would mint a random id.
    final payload = toFirestoreMap(event.toStorage());
    final doc = collectionFor(scope).doc(event.id);
    final existing = await _guardRead(doc);
    if (existing != null) {
      if (_decodesTo(event, existing)) return; // identical replay: no-op
      throw LearningEventConflictException(event.id);
    }
    await doc.set(payload);
  }

  /// Server error codes a retry can never fix: the write is rejected for
  /// good and becomes a per-item pending failure (AD-54 Recovery).
  static const permanentRejectionCodes = {
    'permission-denied',
    'invalid-argument',
    'failed-precondition',
    'already-exists',
    'not-found',
    'out-of-range',
    'unauthenticated',
  };

  @override
  Future<void> commit(LearnerScope scope, LearningWriteChunk chunk) async {
    // Encode (and validate) every document before any I/O.
    final events = [
      for (final e in chunk.events)
        (collectionFor(scope).doc(e.id), toFirestoreMap(e.toStorage())),
    ];
    final ledger = pointsLedgerCollectionFor(_firestore, scope);
    final awards = [
      for (final a in chunk.awards)
        (ledger.doc(a.docId), pointsAwardDocument(a)),
    ];
    final batch = _firestore.batch();
    for (final (doc, data) in [...events, ...awards]) {
      batch.set(doc, data);
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (permanentRejectionCodes.contains(e.code)) {
        throw PermanentWriteRejection(e.code);
      }
      rethrow;
    }
  }

  static bool _decodesTo(LearningEvent event, Map<String, dynamic> data) {
    try {
      return LearningEvent.fromStorage(event.id, fromFirestoreMap(data)) ==
          event;
    } on Object {
      return false; // an undecodable stored row is never silently replaced
    }
  }
}
