/// Codec for Firestore `learning_ledger/{ulid}` documents.
///
/// The canonical write schema (W3.18/W3.19) uses snake_case field names.
/// All live writers must route through [LearningLedgerCodec.encode] so the
/// push payload stays in sync with what [LearningLedgerMerger] reads on pull.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a learning ledger entry (live W3.18/W3.19 schema).
class LearningLedgerRow {
  const LearningLedgerRow({
    required this.ulid,
    required this.profileId,
    required this.curriculumId,
    required this.entryScope,
    required this.unitIdentifier,
    required this.unitDisplayNameHe,
    required this.unitDisplayNameEn,
    required this.trackType,
    this.trackId,
    required this.completedAt,
    required this.completionNumber,
    required this.markedBy,
    required this.isManual,
  });

  final String ulid;
  final int profileId;
  final String curriculumId;
  final String entryScope;
  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;
  final String trackType;
  final int? trackId;
  final DateTime completedAt;
  final int completionNumber;
  final int markedBy;
  final bool isManual;
}

/// Codec for the `learning_ledger` Firestore collection.
///
/// Append-only — deduplicated on `(profileId, ulid)` via INSERT OR IGNORE.
/// No `hasOnly` rule exists for this collection, so the field set is
/// unconstrained at the rules layer; the merger is the contract boundary.
class LearningLedgerCodec extends EntityCodec<LearningLedgerRow> {
  const LearningLedgerCodec();

  @override
  String get kind => EntityKind.learningLedger;

  @override
  Map<String, dynamic> encode(LearningLedgerRow model) => {
    'ulid': model.ulid,
    'profile_id': model.profileId,
    'curriculum_id': model.curriculumId,
    'entry_scope': model.entryScope,
    'unit_identifier': model.unitIdentifier,
    'unit_display_name_he': model.unitDisplayNameHe,
    'unit_display_name_en': model.unitDisplayNameEn,
    'track_type': model.trackType,
    'track_id': model.trackId,
    'completed_at': model.completedAt.toIso8601String(),
    'completion_number': model.completionNumber,
    'marked_by': model.markedBy,
    'is_manual': model.isManual,
  };

  @override
  LearningLedgerRow? decode(Map<String, dynamic> raw) {
    final ulid = raw['ulid'] as String?;
    final profileId = FirestoreCodec.parseInt(raw['profile_id']);
    final curriculumId = raw['curriculum_id'] as String?;
    final entryScope =
        (raw['entry_scope'] ?? raw['entryScope'] as Object?) as String?;
    final unitIdentifier =
        (raw['unit_identifier'] ?? raw['unitIdentifier'] as Object?) as String?;
    final trackType =
        (raw['track_type'] ?? raw['trackType'] as Object?) as String?;
    final completedAt = FirestoreCodec.parseDateTime(
      raw['completed_at'] ?? raw['completedAt'],
    );

    if (ulid == null ||
        profileId == null ||
        curriculumId == null ||
        entryScope == null ||
        unitIdentifier == null ||
        trackType == null ||
        completedAt == null) {
      return null;
    }

    return LearningLedgerRow(
      ulid: ulid,
      profileId: profileId,
      curriculumId: curriculumId,
      entryScope: entryScope,
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe:
          ((raw['unit_display_name_he'] ?? raw['unitDisplayNameHe'])
              as String?) ??
          '',
      unitDisplayNameEn:
          ((raw['unit_display_name_en'] ?? raw['unitDisplayNameEn'])
              as String?) ??
          '',
      trackType: trackType,
      trackId: FirestoreCodec.parseInt(raw['track_id'] ?? raw['trackId']),
      completedAt: completedAt,
      completionNumber:
          FirestoreCodec.parseInt(
            raw['completion_number'] ?? raw['completionNumber'],
          ) ??
          1,
      markedBy:
          FirestoreCodec.parseInt(raw['marked_by'] ?? raw['markedBy']) ?? 0,
      isManual:
          FirestoreCodec.parseBool(raw['is_manual'] ?? raw['isManual']) ??
          false,
    );
  }
}
