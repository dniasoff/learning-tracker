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
/// - **Create-only guard.** Before the `set()`, the doc is read from the
///   LOCAL cache only: an existing identical event makes the call a no-op
///   (idempotent replay); an existing different (or undecodable) event
///   throws [LearningEventConflictException] and nothing is written, so a
///   conflicting replay can never overwrite an appended event. The cache
///   holds every pending local write and every event a `watchAll` listener
///   has seen, which covers the realistic conflict (a retry that rebuilt
///   its payload). The check is cache-only — never a server round trip and
///   never a transaction — so the write stays queueable offline (AD-38
///   offline owner create). An event present only on the server is guarded
///   by the AD-46 rules whitelist (create-only plus identical replay,
///   Story 1.9), which rejects the non-identical update server-side.
/// - The `{uid}` path segment is the caller-supplied [LearnerScope.ownerUid]
///   (the persisted path uid, or a grant's owner uid — ruling B10), never
///   read from the live Auth user here.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/data/repositories/paged_complete_query.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';

/// `learning_events` collection name.
const kLearningEventsCollection = 'learning_events';

/// Profile-scoped `learning_events` repository.
final class FirestoreLearningEventRepository
    implements LearningEventRepository {
  /// Creates the repository over an account-scoped [firestore] handle
  /// (resolved from `activeAccountFirebaseProvider`).
  FirestoreLearningEventRepository({
    required FirebaseFirestore firestore,
    this.backoffBase = const Duration(seconds: 1),
    this.backoffCap = const Duration(seconds: 30),
    this.random,
    this.onListenerError,
    this.pageProbe,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

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
    final existing = await _cachedData(doc);
    if (existing != null) {
      if (_decodesTo(event, existing)) return; // identical replay: no-op
      throw LearningEventConflictException(event.id);
    }
    await doc.set(payload);
  }

  /// The doc's data from the local cache, or null when the cache holds no
  /// such document (a cache miss throws `unavailable`; never goes to the
  /// server).
  static Future<Map<String, dynamic>?> _cachedData(
    DocumentReference<Map<String, dynamic>> doc,
  ) async {
    try {
      final snapshot = await doc.get(const GetOptions(source: Source.cache));
      return snapshot.exists ? snapshot.data() : null;
    } on FirebaseException {
      return null;
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
