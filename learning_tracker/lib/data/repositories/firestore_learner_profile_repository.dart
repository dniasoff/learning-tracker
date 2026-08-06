/// Firestore implementation for learner profiles — Epic B
/// (`docs/firestore-rewrite-map.md`), built to the shape
/// `lib/data/repositories/firestore_stage_definition_repository.dart`
/// establishes as the reference. See that file's class doc comment for the
/// pattern this copies. This doc comment only calls out what is DIFFERENT
/// for `learner_profiles`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

/// Firestore-backed learner-profile repository: `users/{uid}/
/// learner_profiles/{profileId}` (`docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /learner_profiles/{profileId}`).
///
/// **Wired into the app — as a dual-write, not a full cutover.**
/// `FirestoreProfileRepositoryAdapter`
/// (`lib/features/profiles/data/repositories/profile_repository_impl.dart`)
/// reads this repository via `firestoreLearnerProfileRepositoryProvider` to
/// ensure/activate a Firestore `learner_profiles` document (P2-2: the
/// adapter mints the identity eagerly, before its own Drift insert — this
/// repository just persists whatever id it is handed) alongside every
/// Drift-side profile create/update; `profileRepositoryProvider`
/// (`profile_providers.dart`) resolves to that adapter. See that class's
/// doc comment ("Dual-write, not cutover — and why") for why this is not
/// yet the same full swap `FirestoreBookmarkRepository` made: the existing
/// Drift-backed `ProfileDao`/`ProfileRepositoryImpl` still owns every read
/// and every write's local row, unchanged.
///
/// **No interface** — same reasoning as `FirestoreBookmarkRepository`'s doc
/// comment.
///
/// ## Scoped to the ACCOUNT, not to one profile — unlike every sibling repo
///
/// `FirestoreStageDefinitionRepository`/`FirestoreGoalRepository`/etc. are
/// constructed with a `profileId` because their collection lives *inside*
/// one profile's subtree. `learner_profiles` IS the collection of an
/// account's profiles, so this repository's constructor takes only
/// [firestore] + [uid] — [profileId] is a per-call parameter (or embedded in
/// the [LearnerProfileEntity] a caller already holds), never a
/// constructor-level constant.
///
/// ## Doc-id: a caller-supplied, pre-minted ULID (AD-24) — P2-2, never
/// minted here
///
/// [createProfile] takes a REQUIRED `profileId` rather than minting one
/// itself. Before P2-2 this method called `DocIds.mintProfileUlid()`
/// directly; that mint moved to `FirestoreProfileRepositoryAdapter`
/// (`lib/features/profiles/data/repositories/profile_repository_impl.dart`)
/// so exactly ONE site in the whole codebase mints a profile's identity —
/// the adapter needs the SAME value for both the Drift row (minted before
/// its insert) and this Firestore document; letting each side mint
/// independently would silently produce two different ids for one profile.
/// Every other repository in this codebase derives its doc-id from a
/// natural key already present in the entity (`curriculumId` for bookmarks/
/// stage-definitions, `curriculumId + createdAt` for goals); a learner
/// profile has no such natural key — its identity is arbitrary and must be
/// generated, which is now the caller's job, not this repository's.
///
/// ## No `account_id` field in the write shape
///
/// The legacy sync-engine codec (`lib/core/sync/codec/
/// learner_profile_codec.dart`) wrote `account_id`/`profile_id` as int
/// fields inside the document body — remnants of the per-device
/// autoincrement-id world this rewrite retires (AD-25). This repository's
/// `users/{uid}/learner_profiles` path already scopes every document to its
/// account; repeating that fact as a stored field would just be a second
/// place for it to drift, and would trip the MCF-11 autoincrement-id-in-
/// payload ratchet the moment it derived from a real Drift int. See
/// [LearnerProfileEntity]'s class doc comment for the full reasoning.
///
/// ## Field shape matches `tutorEditProfile` — the second writer
///
/// `learner_profiles` is one of the two-writer collections: the owner
/// directly (this repository), and a tutor via `tutorEditProfile`
/// (`functions/src/tutor_writes.ts`), which merges `display_name`/`avatar`/
/// `mode`/`updated_at` onto the SAME document. [LearnerProfileEntity.
/// toFirestore] uses those exact field names so an owner write and a tutor
/// write are byte-compatible, and every write here uses
/// `SetOptions(merge: true)` so this client never clobbers a concurrent
/// tutor edit (or vice versa).
///
/// **"the SAME document" above is VERIFIED FALSE today, and stays false
/// through Phase 2 (R7, `firestore-phase2-plan.md` §7).** `tutorEditProfile`
/// (`functions/src/tutor_writes.ts:968-978,1005`) validates an INT
/// `profileId` and writes through the legacy int-keyed `profilePath`
/// (`:186-191`) — the old `learner_profiles/{int}` document, never this
/// repository's `learner_profiles/{ulid}` one. Re-keying tutoring's
/// identity is Phase 3's job (T-30/T-31), not Phase 2's — see the plan's Q1
/// ruling for why. Do not read the field-shape claim above as evidence that
/// the two writers currently agree on a document; only the field NAMES are
/// shared, not the document they're written to.
///
/// ## No delete method
///
/// `firestore.rules` denies `delete` on `learner_profiles` unconditionally
/// — the `deleteLearnerProfile` Cloud Function performs a `recursiveDelete`
/// covering every subcollection, which a client-side delete could never do
/// correctly anyway. `ProfileRepositoryImpl.deleteProfile` (Drift) clears 14
/// tables by hand for exactly this reason; none of that has a place here.
class FirestoreLearnerProfileRepository {
  FirestoreLearnerProfileRepository({
    required FirebaseFirestore firestore,
    required String uid,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final AppLogger _logger;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('users').doc(_uid).collection('learner_profiles');

  DocumentReference<Map<String, dynamic>> _doc(String profileId) =>
      _profiles.doc(profileId);

  /// Returns the profile for [profileId], or `null` if it does not exist.
  Future<LearnerProfileEntity?> getProfile(String profileId) async {
    final data = (await _doc(profileId).get()).data();
    if (data == null) return null;
    return LearnerProfileEntity.fromFirestore(profileId, data);
  }

  /// Live updates for [profileId]'s document. Resubscribes with bounded
  /// exponential backoff if the underlying listener errors
  /// (`resilientDocStream`).
  Stream<LearnerProfileEntity?> watchProfile(String profileId) {
    return resilientDocStream<LearnerProfileEntity?>(
      openStream: () => _doc(profileId).snapshots(),
      decode: (snap) {
        final data = snap.data();
        if (data == null) return null;
        return LearnerProfileEntity.fromFirestore(profileId, data);
      },
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_learner_profile_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'uid': _uid, 'profile_id': profileId},
      ),
    );
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row
  /// fail the whole read — same "one bad document should not blank the
  /// list" treatment `FirestoreStageDefinitionRepository._decodeAll`
  /// applies.
  List<LearnerProfileEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <LearnerProfileEntity>[];
    for (final doc in docs) {
      try {
        results.add(LearnerProfileEntity.fromFirestore(doc.id, doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_learner_profiles_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'uid': _uid, 'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Returns every profile belonging to this account. Unfiltered — no
  /// `where()`/`orderBy()`, so no composite index needed.
  Future<List<LearnerProfileEntity>> getProfiles() async {
    final snapshot = await _profiles.get();
    return _decodeAll(snapshot.docs);
  }

  /// Live updates for this account's whole profile list. Resubscribes with
  /// bounded exponential backoff if the underlying listener errors
  /// (`resilientQueryStream`) — a per-document decode failure is skipped
  /// rather than blanking the whole list, same as [getProfiles].
  Stream<List<LearnerProfileEntity>> watchProfiles() {
    return resilientQueryStream<LearnerProfileEntity>(
      openStream: () => _profiles.snapshots(),
      decode: (doc) => LearnerProfileEntity.fromFirestore(doc.id, doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_learner_profiles_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'uid': _uid},
      ),
    );
  }

  /// Creates (or idempotently re-writes) a learner profile document at the
  /// caller-supplied [profileId] — see the class doc comment ("Doc-id") for
  /// why this repository no longer mints the id itself (P2-2). The write
  /// uses `SetOptions(merge: true)` unconditionally, so calling this again
  /// for an already-existing [profileId] is a safe create-if-missing /
  /// heal, not a duplicate-create hazard.
  Future<LearnerProfileEntity> createProfile({
    required String profileId,
    required String displayName,
    required ProfileMode mode,
    String avatar = '',
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final entity = LearnerProfileEntity(
      profileId: profileId,
      displayName: displayName,
      mode: mode,
      avatar: avatar,
      createdAt: now,
      updatedAt: now,
    );
    await _doc(
      entity.profileId,
    ).set(entity.toFirestore(), SetOptions(merge: true));
    return entity;
  }

  /// Updates [profile] and writes the result back to the SAME document
  /// (its [LearnerProfileEntity.profileId] is unchanged by an update).
  /// Omitting [displayName]/[mode]/[avatar] leaves the existing value
  /// untouched — mirrors `FirestoreGoalRepository.updateGoal`'s "current
  /// entity + optional overrides" shape.
  Future<LearnerProfileEntity> updateProfile({
    required LearnerProfileEntity profile,
    String? displayName,
    ProfileMode? mode,
    String? avatar,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final updated = profile.copyWith(
      displayName: displayName ?? profile.displayName,
      mode: mode ?? profile.mode,
      avatar: avatar ?? profile.avatar,
      updatedAt: now,
    );
    await _doc(
      updated.profileId,
    ).set(updated.toFirestore(), SetOptions(merge: true));
    return updated;
  }
}
