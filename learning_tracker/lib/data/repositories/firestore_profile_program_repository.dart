/// Firestore implementation for profile-program assignments —
/// `users/{uid}/learner_profiles/{profileId}/profile_programs/
/// {curriculumId}` (one doc per curriculum), the AD-38 governed entity
/// `mainTrackProgram`.
///
/// Reads are direct; every write is ONE governed action handed to
/// `LearningCommands.applyGovernedChange` through the injected
/// [OwnerGovernedWriter] (Story 1.14, DNI-476): a field-level merge with
/// `last_change_id` and a co-written `change_log` entry. This class never
/// writes or deletes a document itself.
///
/// ## AD-52 field shapes
///
/// `program_id` is written as a string and `tracking_start_date` as a
/// `YYYY-MM-DD` civil date (the shapes the engine's `MainTrackProgram`
/// codec and `writeWithChangeLog` read); [profileProgramFromFirestore]
/// accepts both these and the legacy int / ISO-instant shapes.
/// `updated_at` / `synced_at` are retired from governed docs and
/// `profile_id` is path-derived, so none of them is written. A field the
/// new assignment no longer has (`tracking_start_date` /
/// `tracking_start_ref`) is cleared with an explicit `null`, so a merge
/// never leaves a stale value from a previous program.
///
/// ## Removal is a tombstone
///
/// [removeProgram] sets `ended_at` through a logged change (client
/// `delete` is denied, AD-38); [setProgram] on an ended doc revives it.
/// Reads skip ended docs.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_intents.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';

/// Firestore-backed profile-programs repository (see the library doc
/// comment).
class FirestoreProfileProgramRepository {
  FirestoreProfileProgramRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    OwnerGovernedWriter? writer,
    AppLogger? logger,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _writer = writer,
       _logger = logger ?? AppLogger.instance,
       _clock = clock ?? DateTimeFactory.nowUtc;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final OwnerGovernedWriter? _writer;
  final AppLogger _logger;
  final DateTime Function() _clock;

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
    if (data == null || !_isLive(data)) return null;
    return profileProgramFromFirestore(data);
  }

  static bool _isLive(Map<String, dynamic> data) =>
      data[GovernedKeys.endedAt] == null;

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
    return resilientQueryStream<ProfileProgramEntity?>(
      openStream: () => _programs.snapshots(),
      decode: (doc) =>
          _isLive(doc.data()) ? profileProgramFromFirestore(doc.data()) : null,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_profile_programs_watch_error',
        exception: error,
        stackTrace: stackTrace,
      ),
    ).map((programs) => programs.whereType<ProfileProgramEntity>().toList());
  }

  List<ProfileProgramEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <ProfileProgramEntity>[];
    for (final doc in docs) {
      if (!_isLive(doc.data())) continue;
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

  /// Creates or replaces the program assignment for [curriculumId]: one
  /// logged `mainTrackProgram` change. `trackingStartDate` /
  /// `trackingStartRef` are always overwritten, to null too.
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
      updatedAt: _clock(),
    );
    await _apply([planSetProgram(entity)]);
    return entity;
  }

  /// The `mainTrackProgram` change [setProgram] writes for [entity]. Used
  /// by the one-action Add track flow (DNI-476 T5).
  GovernedEntityChange planSetProgram(ProfileProgramEntity entity) {
    final start = entity.trackingStartDate;
    return _change(entity.curriculumId, {
      MainTrackProgram.kProgramId: entity.programId.toString(),
      MainTrackProgram.kTrackingStartDate: start == null
          ? null
          : FirestoreCodec.encodeCivilDate(start),
      MainTrackProgram.kTrackingStartRef: entity.trackingStartRef,
      GovernedKeys.endedAt: null,
    });
  }

  /// Ends the program enrolment for [curriculumId] (self-paced re-add or a
  /// switch away from a program): an `ended_at` tombstone through a logged
  /// change, never a delete. No-op when there is no live assignment.
  Future<void> removeProgram(CurriculumId curriculumId) async {
    final change = await planRemoveProgram(curriculumId);
    if (change != null) await _apply([change]);
  }

  /// The tombstone [removeProgram] writes, or null when [curriculumId] has
  /// no live assignment.
  Future<GovernedEntityChange?> planRemoveProgram(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _doc(curriculumId).get();
    final data = snapshot.data();
    if (data == null || !_isLive(data)) return null;
    return _change(curriculumId, {GovernedKeys.endedAt: _clock()});
  }

  GovernedEntityChange _change(
    CurriculumId curriculumId,
    Map<String, Object?> fields,
  ) => OwnerGovernedIntents.mainTrackDocs(
    entity: GovernedEntity.mainTrackProgram,
    curriculumId: curriculumId.storageKey,
    docs: {
      DocIds.profileProgramDocId({'curriculum_id': curriculumId.storageKey}):
          fields,
    },
  );

  Future<void> _apply(List<GovernedEntityChange> changes) async {
    final writer = _writer;
    if (writer == null) throw const GovernedWriterNotReadyException();
    await applyOwnerAction(writer, GovernedAction(changes));
  }
}
