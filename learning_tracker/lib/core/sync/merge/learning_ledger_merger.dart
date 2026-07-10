/// Append-only merger for `learning_ledger` rows (W2.27 / closes M1).
///
/// Learning ledger is an append-only event log. Merging reduces to
/// "insert any unseen rows"; deduplication is handled by the composite
/// UNIQUE `(profileId, ulid)` index (Story 25.2 / DNI-323) via
/// `INSERT OR IGNORE`.
///
/// Field names: W3.18/W3.19 migrated the Firestore schema to snake_case
/// (`curriculum_id`, `unit_identifier`, `track_type`, `completed_at`).
/// Legacy camelCase keys are accepted as a defensive fallback so that any
/// pre-migration docs already in Firestore are still ingested.
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/time/ulid.dart';

class LearningLedgerMerger implements EntityMerger {
  LearningLedgerMerger(UserDatabase db, {AppLogger? logger})
    : _db = db,
      _logger = logger;

  final UserDatabase _db;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;

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
    final existingProfileIds = (await _db.select(_db.learnerProfiles).get())
        .map((p) => p.id)
        .toSet();

    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
        // W3.18/W3.19: snake_case is the canonical schema; accept camelCase as
        // a fallback for any legacy docs already written to Firestore.
        final curriculumId =
            (row['curriculum_id'] ?? row['curriculumId']) as String?;
        final unitIdentifier =
            (row['unit_identifier'] ?? row['unitIdentifier']) as String?;
        final trackType = (row['track_type'] ?? row['trackType']) as String?;
        final completedAt = FirestoreCodec.parseDateTime(
          row['completed_at'] ?? row['completedAt'],
        );

        if (curriculumId == null ||
            unitIdentifier == null ||
            trackType == null ||
            completedAt == null) {
          continue;
        }

        final rawPid = row['profile_id'] ?? row['profileId'];
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
                  : newUlid(completedAt),
            ),
            curriculumId: curriculumId,
            entryScope:
                (row['entry_scope'] ??
                        row['entryScope'] as Object? ??
                        'masechta')
                    as String,
            unitIdentifier: unitIdentifier,
            unitDisplayNameHe:
                ((row['unit_display_name_he'] ?? row['unitDisplayNameHe'])
                    as String?) ??
                '',
            unitDisplayNameEn:
                ((row['unit_display_name_en'] ?? row['unitDisplayNameEn'])
                    as String?) ??
                '',
            trackType: trackType,
            trackId: Value(
              FirestoreCodec.parseInt(row['track_id'] ?? row['trackId']),
            ),
            completedAt: completedAt,
            completionNumber:
                FirestoreCodec.parseInt(
                  row['completion_number'] ?? row['completionNumber'],
                ) ??
                1,
            markedBy:
                FirestoreCodec.parseInt(row['marked_by'] ?? row['markedBy']) ??
                0,
            isManual: Value(
              FirestoreCodec.parseBool(row['is_manual'] ?? row['isManual']) ??
                  false,
            ),
          ),
        );
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_learning_ledger_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
