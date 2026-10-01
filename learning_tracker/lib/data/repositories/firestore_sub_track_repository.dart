/// Firestore implementation of [SubTrackRepository] —
/// `users/{uid}/learner_profiles/{profileId}/sub_tracks/{ulid}`.
///
/// - **Reads**: [watchCompletePaged] (≤ 500 per query, loading until
///   complete, never partial, AD-9 recovery). Tombstoned rows are included;
///   readers decide what an ended sub-track means.
/// - **Governed writes** (AD-38): one [WriteBatch] holding a field-level
///   `set(merge: true)` of the changed fields + `last_change_id` on the
///   sub-track doc and the create of its `change_log/{entryId}` entry, so
///   the two land atomically (and queue together offline). Removal is a
///   tombstone (`ended_at` + `end_reason`); this class never calls
///   `delete()`.
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/data/repositories/paged_complete_query.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// `sub_tracks` collection name.
const kSubTracksCollection = 'sub_tracks';

/// `change_log` collection name.
const kChangeLogCollection = 'change_log';

/// Profile-scoped `sub_tracks` repository.
final class FirestoreSubTrackRepository implements SubTrackRepository {
  /// Creates the repository over an account-scoped [firestore] handle.
  FirestoreSubTrackRepository({
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

  DocumentReference<Map<String, dynamic>> _profile(LearnerScope scope) =>
      _firestore
          .collection('users')
          .doc(scope.ownerUid)
          .collection('learner_profiles')
          .doc(scope.profileId);

  /// `users/{ownerUid}/learner_profiles/{profileId}/sub_tracks`.
  CollectionReference<Map<String, dynamic>> collectionFor(LearnerScope scope) =>
      _profile(scope).collection(kSubTracksCollection);

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) =>
      watchCompletePaged<SubTrack>(
        collection: collectionFor(scope),
        decode: SubTrack.fromStorage,
        backoffBase: backoffBase,
        backoffCap: backoffCap,
        random: random,
        onError: onListenerError,
        probe: pageProbe,
      );

  @override
  Future<void> applyGovernedChange(
    LearnerScope scope,
    SubTrackChange change,
  ) async {
    // Both payloads are validated by their domain types before any I/O.
    final entryPayload = toFirestoreMap(change.entry.toStorage());
    final patch = toFirestoreMap(change.toMergePatch());
    final batch = _firestore.batch()
      ..set(
        collectionFor(scope).doc(change.subTrackId),
        patch,
        SetOptions(merge: true),
      )
      ..set(
        _profile(scope).collection(kChangeLogCollection).doc(change.entry.id),
        entryPayload,
      );
    await batch.commit();
  }
}
