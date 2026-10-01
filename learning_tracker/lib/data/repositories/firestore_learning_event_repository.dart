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
///   retry re-sends byte-for-byte the same value (AD-46). A plain `set()`
///   (not a transaction) keeps the write queueable offline; the rules
///   accept an identical replay (SR-1).
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
    await collectionFor(scope).doc(event.id).set(payload);
  }
}
