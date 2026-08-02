/// Firestore implementation for profile-program assignments — one of the
/// two repositories built alongside `FirestoreCurriculumScopeRepository`
/// (`docs/firestore-rewrite-map.md`). Follows the shape
/// `FirestoreBookmarkRepository`/`FirestoreStageDefinitionRepository`
/// established; see this file's own doc comments for what is genuinely new.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';

/// Firestore-backed profile-programs repository: `users/{uid}/
/// learner_profiles/{profileId}/profile_programs/{curriculumId}` (one
/// document per curriculum — `docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /profile_programs/{curriculumId}`).
///
/// **Not wired into the app yet** — same status as every other repository
/// under `lib/data/repositories/`: stands alone, nothing under
/// `lib/features/` reads it, the existing Drift-backed `ProfileProgramDao`
/// is untouched.
///
/// **No interface** — same reasoning as `FirestoreBookmarkRepository`'s doc
/// comment.
///
/// ## `profile_id` IS written — the one deliberate divergence from the
/// Bookmarks/StageDefinitions pattern
///
/// `FirestoreBookmarkRepository`/`FirestoreStageDefinitionRepository` omit
/// path-derived identity from the document body entirely (the path already
/// carries it). This repository keeps `profile_id` in the write shape
/// instead, because — unlike bookmarks/stage_definitions — it is not a new
/// choice being made here: `profile_id` is in the `profile_programs`
/// `.hasOnly()` whitelist AND `FirestoreGatewayImpl.pushProfileProgram`/
/// `TrackCreationService` already write it today (`firestore_gateway_impl.
/// dart`, `track_creation_service.dart:236`). Dropping it would silently
/// narrow the existing document shape for no benefit. It is the profile's
/// String ULID (AD-24) here, never the Drift `int` — see
/// `ProfileProgramEntity.toFirestore`'s doc comment.
///
/// ## `SetOptions(merge: true)` + nullable fields — the field-clearing trap
///
/// `tracking_start_date`/`tracking_start_ref` can go from set to `null`
/// across two calls to [setProgram] for the SAME curriculum (switching from
/// a program that has a tracking-start window to one that does not; Drift's
/// `ProfileProgramDao.setProfileProgram` always passes both as an explicit
/// `Value(...)`, overwriting even to null). `ProfileProgramEntity.
/// toFirestore` — like every other entity codec in this codebase — simply
/// OMITS a null field from its map so it stays free of `cloud_firestore`.
/// But this collection's writes use `SetOptions(merge: true)` (the
/// tutor-proxy second-writer rule every two-writer collection follows —
/// `functions/src/tutor_writes.ts`'s `tutorSetProfileProgram`), and a merge
/// set only touches keys PRESENT in the payload: an omitted key leaves
/// whatever was already on the document untouched. Silently reusing
/// [ProfileProgramEntity.toFirestore]'s map as-is would therefore leave a
/// STALE `tracking_start_date`/`tracking_start_ref` from a previous program
/// in place after switching to one with no tracking window. [_writeMap]
/// below closes that gap: it explicitly sends `FieldValue.delete()` for
/// either field the entity has as `null`, restoring the Drift DAO's
/// "always overwrite, including to null" behavior. This is the one place in
/// this repository that needs `cloud_firestore`'s `FieldValue` rather than
/// the shared `FirestoreCodec` helpers — by design, `ProfileProgramEntity`
/// itself must not import `cloud_firestore` (Rule 3, `lib/features/**` is
/// outside the confinement zone).
///
/// ## Trimmed from the Drift-era DAO — not reimplemented
///
/// `ProfileProgramDao.deleteForProfile` (whole-profile bulk clear) has no
/// counterpart here. It has zero call sites anywhere in `lib/` beyond its
/// own unit test, and whole-profile deletion in the Firestore world goes
/// through the `deleteLearnerProfile` Cloud Function's `recursiveDelete`,
/// which already sweeps this subcollection — a client-side bulk-clear
/// would be redundant even in principle, not merely uncalled. If a real
/// caller needs it later (e.g. "reset all program enrolments" without
/// deleting the profile), add it back then, chunked like
/// `FirestoreCurriculumScopeRepository`'s bulk deletes.
class FirestoreProfileProgramRepository {
  FirestoreProfileProgramRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final AppLogger _logger;

  CollectionReference<Map<String, dynamic>> get _programs => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('profile_programs');

  DocumentReference<Map<String, dynamic>> _doc(CurriculumId curriculumId) =>
      _programs.doc(
        DocIds.profileProgramDocId({'curriculum_id': curriculumId.storageKey}),
      );

  ProfileProgramEntity? _decode(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    return profileProgramFromFirestore(data);
  }

  /// Returns the program assignment for [curriculumId], or `null` if the
  /// profile is self-paced (no program assigned) for that curriculum —
  /// mirrors `ProfileProgramDao.getProgramForProfileAndCurriculum`.
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async {
    final snapshot = await _doc(curriculumId).get();
    return _decode(snapshot);
  }

  /// Live updates for [curriculumId]'s program assignment. Resubscribes
  /// with bounded exponential backoff if the underlying listener errors
  /// (`resilientDocStream`).
  Stream<ProfileProgramEntity?> watchProgram(CurriculumId curriculumId) {
    return resilientDocStream<ProfileProgramEntity?>(
      openStream: () => _doc(curriculumId).snapshots(),
      decode: _decode,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_profile_program_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    );
  }

  /// Every program assignment across this profile's curricula — mirrors
  /// `ProfileProgramDao.getProgramsForProfile`. Unfiltered — no `where()`/
  /// `orderBy()`, so no composite index needed.
  Future<List<ProfileProgramEntity>> getAllPrograms() async {
    final snapshot = await _programs.get();
    return _decodeAll(snapshot.docs);
  }

  /// Live updates for every program assignment across this profile's
  /// curricula (`resilientQueryStream` — one bad document is skipped, not
  /// the whole list, per `FirestoreStageDefinitionRepository`'s reasoning).
  Stream<List<ProfileProgramEntity>> watchAllPrograms() {
    return resilientQueryStream<ProfileProgramEntity>(
      openStream: () => _programs.snapshots(),
      decode: (doc) => profileProgramFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_profile_programs_watch_error',
        exception: error,
        stackTrace: stackTrace,
      ),
    );
  }

  List<ProfileProgramEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <ProfileProgramEntity>[];
    for (final doc in docs) {
      try {
        results.add(profileProgramFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_profile_programs_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Create or replace the program assignment for [curriculumId] — mirrors
  /// `ProfileProgramDao.setProfileProgram`'s upsert (set-or-replace)
  /// semantics, including its "always overwrite `trackingStartDate`/
  /// `trackingStartRef`, even to null" behavior — see the class doc
  /// comment's "field-clearing trap" section for why that needs
  /// [_writeMap] rather than a bare `entity.toFirestore()`.
  Future<ProfileProgramEntity> setProgram({
    required CurriculumId curriculumId,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  }) async {
    final entity = ProfileProgramEntity(
      curriculumId: curriculumId,
      programId: programId,
      trackingStartDate: trackingStartDate,
      trackingStartRef: trackingStartRef,
      updatedAt: DateTimeFactory.nowUtc(), // P5: UTC timestamps
    );
    await _doc(curriculumId).set(_writeMap(entity), SetOptions(merge: true));
    return entity;
  }

  /// See the class doc comment's "field-clearing trap" section.
  Map<String, dynamic> _writeMap(ProfileProgramEntity entity) {
    final map = entity.toFirestore(profileId: _profileId);
    if (entity.trackingStartDate == null) {
      map['tracking_start_date'] = FieldValue.delete();
    }
    if (entity.trackingStartRef == null) {
      map['tracking_start_ref'] = FieldValue.delete();
    }
    return map;
  }

  /// Removes the program enrollment for [curriculumId] (self-paced re-add
  /// or switch away from a program) — a genuine hard delete, permitted by
  /// `firestore.rules` specifically so this call succeeds (`firestore.
  /// rules`' comment: "Client deletes are permitted for the owner so that
  /// `removeProfileProgramAssignment` ... can hard-delete the document.
  /// Without this ... PERMISSION_DENIED and the deleted program resurfaces
  /// on next sync"). Mirrors `ProfileProgramDao.
  /// clearProgramForProfileAndCurriculum` and
  /// `FirestoreGatewayImpl.removeProfileProgramAssignment`.
  Future<void> removeProgram(CurriculumId curriculumId) =>
      _doc(curriculumId).delete();
}
