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
/// - **Create** (AD-49 backup replay, DNI-482): a [SubTrackChange.create]
///   admits a target the client cannot find, with the empty row as its
///   baseline; it is the same queueable doc + entry batch (ruling B6),
///   never a create claim.
/// - **Existing, valid target** (review R3). Before the batch, the target
///   `sub_tracks/{id}` row is read (cache, then server). A row the client
///   cannot find throws [SubTrackNotFoundException] — a merge on an unknown
///   id would otherwise mint a partial document [SubTrack.fromStorage]
///   rejects. The patch is then applied to the decoded row and the MERGED
///   state is validated as a whole [SubTrack] (type/academic_year,
///   window_start/window_end, ended_at/end_reason), so a change that is
///   valid field-by-field but breaks a cross-field invariant throws
///   [StorageFormatException] and nothing is written. An offline client
///   validates against its cached row; a merge stays queueable offline
///   (AD-38), so this is a client-side check, not a transaction — the
///   AD-46 rules (Story 1.9) are the atomic server-side guarantee.
/// - **Truthful audit baseline** (AD-38: an owner-path entry's `before` is
///   the writer's cached value per field, `null` when absent). Every
///   `entry.before` field is compared to the same pre-read row, an absent
///   field counting as `null`; a mismatch throws
///   [ChangeBaselineMismatchException] and nothing is written, so a later
///   undo can never "restore" a value the doc never held. Like the target
///   check this is a client-side precondition against the writer's view
///   (cache, then server); a concurrent remote edit landing after the read
///   is resolved by AD-38 per-field LWW, and the server-side owner rule
///   (Story 1.9) / `writeWithChangeLog` transaction (Story 1.10) own the
///   atomic guarantees.
/// - **Append-only change log** (AD-6, AD-38, AD-46). `change_log/{entryId}`
///   is create-only: before the batch, the entry is read through
///   [readExistingForCreate] (cache, then server). An identical entry means
///   the change already landed (the batch is atomic), so the call is a
///   no-op — the sub-track patch is NOT re-applied, which could otherwise
///   revert a later change. A different (or undecodable) entry throws
///   [ChangeLogConflictException] and nothing is written: neither the audit
///   row nor the sub-track. A read failure is rethrown, never treated as
///   "absent"; only an offline client queues without the remote check
///   (the AD-46 rules reject a non-identical write at sync time).
library;

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/create_only_guard.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/data/repositories/paged_complete_query.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
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
    CreateGuardRead? guardRead,
    CreateGuardRead? targetRead,
  }) : _firestore = firestore,
       _guardRead = guardRead ?? readExistingForCreate,
       _targetRead = targetRead ?? readExistingForCreate;

  final FirebaseFirestore _firestore;

  /// The change-log create-only pre-read (tests inject cache/server
  /// outcomes).
  final CreateGuardRead _guardRead;

  /// The target sub-track pre-read (cache, then server; null = not found).
  /// Tests inject server-only or failing outcomes.
  final CreateGuardRead _targetRead;

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
    final entryDoc = _profile(
      scope,
    ).collection(kChangeLogCollection).doc(change.entry.id);
    final existing = await _guardRead(entryDoc);
    if (existing != null) {
      // Identical replay: the atomic batch already landed. No-op.
      if (_decodesTo(change.entry, existing)) return;
      throw ChangeLogConflictException(change.entry.id);
    }
    final trackDoc = collectionFor(scope).doc(change.subTrackId);
    final current = await _targetRead(trackDoc);
    if (current == null && !change.isCreate) {
      throw SubTrackNotFoundException(change.subTrackId);
    }
    // A create's baseline is the empty row: an existing target makes its
    // all-null `before` untruthful and fails below.
    final stored = current == null
        ? const <String, Object?>{}
        : fromFirestoreMap(current);
    _requireTruthfulBaseline(change, stored);
    // Validate the full merged row; throws StorageFormatException.
    SubTrack.fromStorage(change.subTrackId, {
      ...stored,
      ...change.toMergePatch(),
    });
    final batch = _firestore.batch()
      ..set(trackDoc, patch, SetOptions(merge: true))
      ..set(entryDoc, entryPayload);
    await batch.commit();
  }

  /// Every `entry.before` field must equal the stored value (absent ⇒
  /// `null`). [SubTrackChange] already guarantees `before` covers exactly
  /// the changed `sub_tracks/{subTrackId}.{field}` keys.
  static void _requireTruthfulBaseline(
    SubTrackChange change,
    Map<String, Object?> stored,
  ) {
    for (final MapEntry(:key, :value) in change.entry.before.entries) {
      final field = ChangedFieldKey.tryParse(key)!.field;
      if (!storageValueEquals(stored[field], value)) {
        throw ChangeBaselineMismatchException(change.subTrackId, field);
      }
    }
  }

  static bool _decodesTo(ChangeLogEntry entry, Map<String, dynamic> data) {
    try {
      return ChangeLogEntry.fromStorage(entry.id, fromFirestoreMap(data)) ==
          entry;
    } on Object {
      return false; // an undecodable stored row is never silently replaced
    }
  }
}
