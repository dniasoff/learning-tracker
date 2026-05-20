/// Append-only merger for `learning_ledger` rows (W2.27 / closes M1).
///
/// Learning ledger is an append-only event log. Merging reduces to
/// "insert any unseen rows"; deduplication is handled by the composite
/// UNIQUE `(profileId, ulid)` index (Story 25.2 / DNI-323) via
/// `INSERT OR IGNORE`.
///
/// NOTE: Field names are camelCase matching the legacy SyncEngine shape.
/// W3 schema work (W3.19+) will migrate these to snake_case; at that point
/// the LearningLedgerCodec decode path will be wired in place of the inline
/// extraction below.
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class LearningLedgerMerger implements EntityMerger {
  LearningLedgerMerger(UserDatabase db) : _db = db;

  final UserDatabase _db;

  @override
  String get kind => EntityKind.learningLedger;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    // FK guard: learning_ledger.profileId references learner_profiles.
    // Skip rows whose profileId has no local counterpart to avoid
    // SqliteException 787 (FOREIGN KEY constraint failed).
    final existingProfileIds =
        (await _db.select(_db.learnerProfiles).get()).map((p) => p.id).toSet();

    for (final row in rows) {
      // Legacy camelCase field names — will become snake_case after W3.19.
      final curriculumId = row['curriculumId'] as String?;
      final unitIdentifier = row['unitIdentifier'] as String?;
      final trackType = row['trackType'] as String?;
      final completedAt = FirestoreCodec.parseDateTime(row['completedAt']);

      if (curriculumId == null ||
          unitIdentifier == null ||
          trackType == null ||
          completedAt == null) {
        continue;
      }

      final rawPid = row['profileId'] ?? row['profile_id'];
      var rowProfileId = FirestoreCodec.parseInt(rawPid) ?? 0;
      if (rowProfileId == 0) rowProfileId = profileId;

      if (!existingProfileIds.contains(rowProfileId)) continue;

      final remoteUlid = row['ulid'] as String?;
      await _db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          profileId: rowProfileId,
          ulid: Value(
            remoteUlid != null && remoteUlid.isNotEmpty
                ? remoteUlid
                : _makeUlid(completedAt),
          ),
          curriculumId: curriculumId,
          entryScope: row['entryScope'] as String? ?? 'masechta',
          unitIdentifier: unitIdentifier,
          unitDisplayNameHe: row['unitDisplayNameHe'] as String? ?? '',
          unitDisplayNameEn: row['unitDisplayNameEn'] as String? ?? '',
          trackType: trackType,
          trackId: Value(FirestoreCodec.parseInt(row['trackId'])),
          completedAt: completedAt,
          completionNumber: FirestoreCodec.parseInt(row['completionNumber']) ?? 1,
          markedBy: FirestoreCodec.parseInt(row['markedBy']) ?? 0,
          isManual: Value(FirestoreCodec.parseBool(row['isManual']) ?? false),
        ),
      );
    }
  }

  /// Fallback ULID generation when the remote row omits `ulid`.
  ///
  /// Uses a simple timestamp-based string so the row can still be inserted
  /// without violating the NOT NULL constraint. Real ULIDs from the push path
  /// are always present for new rows; this guard handles legacy data.
  String _makeUlid(DateTime ts) =>
      '${ts.millisecondsSinceEpoch.toRadixString(36).padLeft(10, '0').toUpperCase()}0000000000000000';
}
