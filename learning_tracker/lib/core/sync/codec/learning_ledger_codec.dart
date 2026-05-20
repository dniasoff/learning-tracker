/// Codec for Firestore `learning_ledger/{ulid}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a learning ledger entry.
class LearningLedgerRow {
  const LearningLedgerRow({
    required this.ulid,
    required this.profileId,
    required this.curriculumId,
    required this.sefariaRef,
    required this.entryType,
    required this.points,
    required this.createdAt,
  });

  final String ulid;
  final int profileId;
  final String curriculumId;
  final String sefariaRef;
  final String entryType;
  final int points;
  final DateTime createdAt;
}

/// Codec for the `learning_ledger` Firestore collection.
///
/// Append-only — deduplicated on `ulid` via INSERT OR IGNORE.
class LearningLedgerCodec extends EntityCodec<LearningLedgerRow> {
  const LearningLedgerCodec();

  @override
  String get kind => EntityKind.learningLedger;

  @override
  LearningLedgerRow? decode(Map<String, dynamic> raw) {
    final ulid = raw['ulid'] as String?;
    final profileId = FirestoreCodec.parseInt(raw['profile_id']);
    final curriculumId = raw['curriculum_id'] as String?;
    final sefariaRef = raw['sefaria_ref'] as String?;
    final entryType = raw['entry_type'] as String?;
    final points = FirestoreCodec.parseInt(raw['points']);
    final createdAt = FirestoreCodec.parseDateTime(raw['created_at']);

    if (ulid == null ||
        profileId == null ||
        curriculumId == null ||
        sefariaRef == null ||
        entryType == null ||
        points == null ||
        createdAt == null) {
      return null;
    }

    return LearningLedgerRow(
      ulid: ulid,
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      entryType: entryType,
      points: points,
      createdAt: createdAt,
    );
  }

  @override
  Map<String, dynamic> encode(LearningLedgerRow model) => {
        'ulid': model.ulid,
        'profile_id': model.profileId,
        'curriculum_id': model.curriculumId,
        'sefaria_ref': model.sefariaRef,
        'entry_type': model.entryType,
        'points': model.points,
        'created_at': FirestoreCodec.encodeDateTime(model.createdAt),
      };
}
