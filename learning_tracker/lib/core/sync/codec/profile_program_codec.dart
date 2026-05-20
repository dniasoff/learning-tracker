/// Codec for Firestore `profile_programs/{id}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a profile program assignment.
class ProfileProgramRow {
  const ProfileProgramRow({
    required this.profileId,
    required this.curriculumId,
    required this.programId,
    this.trackingStartDate,
    this.trackingStartRef,
  });

  final int profileId;
  final String curriculumId;
  final int programId;
  final DateTime? trackingStartDate;
  final String? trackingStartRef;
}

/// Codec for the `profile_programs` Firestore collection.
///
/// Natural key: `(profileId, curriculumId)`.
class ProfileProgramCodec extends EntityCodec<ProfileProgramRow> {
  const ProfileProgramCodec();

  @override
  String get kind => EntityKind.profileProgram;

  @override
  ProfileProgramRow? decode(Map<String, dynamic> raw) {
    final rawProfileId = raw['profile_id'];
    final profileId = FirestoreCodec.parseInt(rawProfileId);
    final curriculumId = raw['curriculum_id'] as String?;
    final programId = FirestoreCodec.parseInt(raw['program_id']);

    if (profileId == null || curriculumId == null || programId == null) {
      return null;
    }

    return ProfileProgramRow(
      profileId: profileId,
      curriculumId: curriculumId,
      programId: programId,
      trackingStartDate: FirestoreCodec.parseDateTime(
        raw['tracking_start_date'],
      ),
      trackingStartRef: raw['tracking_start_ref'] as String?,
    );
  }

  @override
  Map<String, dynamic> encode(ProfileProgramRow model) => {
    'profile_id': model.profileId,
    'curriculum_id': model.curriculumId,
    'program_id': model.programId,
    if (model.trackingStartDate != null)
      'tracking_start_date': FirestoreCodec.encodeDateTime(
        model.trackingStartDate,
      ),
    if (model.trackingStartRef != null)
      'tracking_start_ref': model.trackingStartRef,
  };
}
