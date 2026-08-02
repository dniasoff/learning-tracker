import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Domain entity for one profile's program assignment within a curriculum.
///
/// **New for the Firestore rewrite** (`docs/firestore-rewrite-map.md`) — no
/// non-Drift domain model existed for `profile_programs` before this file.
/// The Drift `ProfilePrograms` row (`lib/core/database/tables/
/// profile_programs.dart`) is NOT reused: its `profileId` column is the
/// per-device autoincrement `int` this rewrite retires as a synced-payload
/// identity (see `docs/firestore-rewrite-map.md`; `profileId` is now the
/// String learner-profile ULID, carried by the repository, not this
/// entity). [programId] stays an `int` — it indexes into the static,
/// compile-time `learningProgramSeeds` catalog
/// (`lib/features/scheduler/domain/services/learning_program_service.dart`),
/// never a Drift autoincrement row id, so it is legitimate synced-payload
/// content (already written today by `FirestoreGatewayImpl.pushProfileProgram`
/// and whitelisted in `firestore.rules`' `profile_programs` `.hasOnly()`).
///
/// One instance = one program selection for one curriculum. One track per
/// (profile, curriculum), so [curriculumId] alone is the natural key
/// (`DocIds.profileProgramDocId`).
class ProfileProgramEntity {
  const ProfileProgramEntity({
    required this.curriculumId,
    required this.programId,
    required this.updatedAt,
    this.trackingStartDate,
    this.trackingStartRef,
    this.syncedAt,
  });

  final CurriculumId curriculumId;

  /// Index into the static `learningProgramSeeds` catalog — see the class
  /// doc comment for why this is safe to write, unlike a Drift-row id.
  final int programId;

  /// Start date for the tracking window (Path A onboarding). `null` clears
  /// it — see [FirestoreProfileProgramRepository]'s (`lib/data/repositories/
  /// firestore_profile_program_repository.dart`) doc comment for why a
  /// client-facing null must become an explicit `FieldValue.delete()`, not
  /// merely an omitted key, under this collection's `SetOptions(merge:
  /// true)` writes.
  final DateTime? trackingStartDate;

  /// Sefaria ref of the first item in the tracking window.
  final String? trackingStartRef;

  /// Client LWW timestamp — always written (`firestore.rules`' comment:
  /// "The client always writes it, so omitting it from the allowlist
  /// denied every enrolment push with permission-denied even for the
  /// owner").
  final DateTime updatedAt;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` at
  /// push time (client-supplied `synced_at` is never written — see the
  /// repository's [toFirestore] caller). Decode-only.
  final DateTime? syncedAt;

  /// Encodes this assignment for a Firestore write. [profileId] is the
  /// String learner-profile ULID (AD-24) — kept as a param rather than a
  /// field on this entity for the same reason [updatedAt] on
  /// `StageDefinitionFirestoreCodec.toFirestore` is a param: this entity
  /// does not otherwise need to know which profile it belongs to, the path
  /// already does. Included in the write (unlike `BookmarkEntity`/
  /// `StageDefinition`, which omit path-derived identity entirely) because
  /// `profile_id` is part of the `.hasOnly()` whitelist AND
  /// `FirestoreGatewayImpl.pushProfileProgram`/`TrackCreationService`
  /// already write it today — dropping it here would silently narrow the
  /// existing document shape.
  ///
  /// Omits `tracking_start_date`/`tracking_start_ref` when `null` — the
  /// repository is responsible for turning that omission into an explicit
  /// `FieldValue.delete()` before merging (see its doc comment); this
  /// function stays free of `cloud_firestore` so it is usable/testable
  /// outside Firebase, matching every other entity codec in this codebase.
  Map<String, dynamic> toFirestore({required String profileId}) => {
    'profile_id': profileId,
    'curriculum_id': curriculumId.storageKey,
    'program_id': programId,
    if (trackingStartDate != null)
      'tracking_start_date': FirestoreCodec.encodeDateTime(trackingStartDate),
    if (trackingStartRef != null) 'tracking_start_ref': trackingStartRef,
    'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
  };
}

/// Decodes a `profile_programs/{curriculumId}` document into a
/// [ProfileProgramEntity].
///
/// Throws [ArgumentError] for an unrecognised `curriculum_id` and
/// [FormatException] for a missing `program_id`/`updated_at` — both
/// caller-visible decode failures by design, mirroring
/// `stageDefinitionFromFirestore`/`curriculumScopeFromFirestore`.
ProfileProgramEntity profileProgramFromFirestore(Map<String, dynamic> data) {
  final curriculumId = CurriculumId.fromStorageKey(
    data['curriculum_id'] as String? ?? '',
  );
  if (curriculumId == null) {
    throw ArgumentError('Unknown curriculumId: ${data['curriculum_id']}');
  }

  final programId = FirestoreCodec.parseInt(data['program_id']);
  final updatedAt = FirestoreCodec.parseDateTime(data['updated_at']);
  if (programId == null || updatedAt == null) {
    throw FormatException(
      'profile_programs document missing program_id/updated_at: $data',
    );
  }

  return ProfileProgramEntity(
    curriculumId: curriculumId,
    programId: programId,
    trackingStartDate: FirestoreCodec.parseDateTime(
      data['tracking_start_date'],
    ),
    trackingStartRef: data['tracking_start_ref'] as String?,
    updatedAt: updatedAt,
    syncedAt: FirestoreCodec.parseDateTime(data['synced_at']),
  );
}
