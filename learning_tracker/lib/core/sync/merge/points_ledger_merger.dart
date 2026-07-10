/// Append-only merger for `points_ledger` rows (WS9 Wave-B / C#2).
///
/// The points ledger is an append-only event log. Merging reduces to "insert
/// any unseen rows" (deduplicated on `ulid` via INSERT-OR-IGNORE), then
/// re-derive the denormalised [PointsBalance] from the merged ledger so the
/// stored balance stays consistent. The mutable balance row itself is NEVER
/// synced — re-deriving from the append-only ledger avoids the classic counter
/// LWW lost-update.
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class PointsLedgerMerger implements EntityMerger {
  PointsLedgerMerger(UserDatabase db, {AppLogger? logger})
    : _db = db,
      _logger = logger;

  final UserDatabase _db;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;

  @override
  String get kind => EntityKind.pointsLedger;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    // FK guard: points_ledger.profileId references learner_profiles. Skip rows
    // whose profileId has no local counterpart to avoid a FK constraint failure.
    final existingProfileIds = (await _db.select(_db.learnerProfiles).get())
        .map((p) => p.id)
        .toSet();

    final touchedProfiles = <int>{};

    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
        final ulid = row['ulid'] as String?;
        final entryKind = row['entry_kind'] as String?;
        final delta = FirestoreCodec.parseInt(row['delta']);
        final createdAt = FirestoreCodec.parseDateTime(row['created_at']);
        if (ulid == null ||
            ulid.isEmpty ||
            entryKind == null ||
            delta == null ||
            createdAt == null) {
          continue;
        }

        var rowProfileId = FirestoreCodec.parseInt(row['profile_id']) ?? 0;
        if (rowProfileId == 0) rowProfileId = profileId;
        if (!existingProfileIds.contains(rowProfileId)) continue;

        final inserted = await _db.pointsBalanceDao
            .insertRemoteLedgerEntryIfAbsent(
              profileId: rowProfileId,
              ulid: ulid,
              entryKind: entryKind,
              delta: delta,
              note: row['note'] as String?,
              // The remote row references a redemption by its stable ULID, not
              // the device-local autoincrement id; the local redemption_id FK
              // is not reconstructed here (it is informational for the ledger
              // view).
              redemptionId: null,
              createdAt: createdAt,
            );
        if (inserted) touchedProfiles.add(rowProfileId);
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_points_ledger_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }

    // Re-derive the balance for every profile that gained at least one row.
    for (final pid in touchedProfiles) {
      await _db.pointsBalanceDao.reDeriveBalanceFromLedger(pid);
    }
  }
}
