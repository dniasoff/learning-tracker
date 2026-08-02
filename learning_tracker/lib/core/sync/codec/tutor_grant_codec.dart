/// Codec for Firestore `tutor_grants/{grantId}` documents.
library;

import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a tutor grant document.
///
/// See `docs/planning/tutor-mode-brief.md` for the full data model.
class TutorGrantRow {
  const TutorGrantRow({
    required this.grantId,
    required this.tutorUid,
    required this.parentUid,
    required this.childProfileId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.tutorEmail,
    this.revokedAt,
  });

  final String grantId;
  final String tutorUid;
  final String parentUid;
  final int childProfileId;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? tutorEmail;
  final DateTime? revokedAt;
}

/// Codec for the `tutor_grants` Firestore collection.
///
/// Natural key: `grantId`.
/// LWW: remote wins when `updated_at` is strictly newer.
///
/// NOTE (W3.38): The tutor_grants collection was added in W3.38 (S3 stream).
/// This codec was added in parallel as W3.17 (S2 stream, closes T17).
class TutorGrantCodec extends EntityCodec<TutorGrantRow> {
  const TutorGrantCodec();

  @override
  String get kind => EntityKind.tutorGrant;

  @override
  TutorGrantRow? decode(Map<String, dynamic> raw) {
    final grantId = raw['grant_id'] as String?;
    final tutorUid = raw['tutor_uid'] as String?;
    final parentUid = raw['parent_uid'] as String?;
    final childProfileId = FirestoreCodec.parseInt(raw['child_profile_id']);
    final state = raw['state'] as String?;
    final createdAt = FirestoreCodec.parseDateTime(raw['created_at']);
    final updatedAt = FirestoreCodec.parseDateTime(raw['updated_at']);

    if (grantId == null ||
        tutorUid == null ||
        parentUid == null ||
        childProfileId == null ||
        state == null ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    return TutorGrantRow(
      grantId: grantId,
      tutorUid: tutorUid,
      parentUid: parentUid,
      childProfileId: childProfileId,
      state: state,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tutorEmail: raw['tutor_email'] as String?,
      revokedAt: FirestoreCodec.parseDateTime(raw['revoked_at']),
    );
  }

  @override
  Map<String, dynamic> encode(TutorGrantRow model) => {
    'grant_id': model.grantId,
    'tutor_uid': model.tutorUid,
    'parent_uid': model.parentUid,
    'child_profile_id': model.childProfileId,
    'state': model.state,
    'created_at': FirestoreCodec.encodeDateTime(model.createdAt),
    'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
    if (model.tutorEmail != null) 'tutor_email': model.tutorEmail,
    if (model.revokedAt != null)
      'revoked_at': FirestoreCodec.encodeDateTime(model.revokedAt),
  };
}
