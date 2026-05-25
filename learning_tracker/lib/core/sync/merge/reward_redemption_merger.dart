/// LWW merger for `reward_redemptions` rows (WS9 Wave-B / C#2).
///
/// Reward redemptions are an LWW state-machine: each doc is keyed by its
/// `ulid` and the latest `updated_at` wins. `pending_fulfilment` transitions
/// to the terminal `fulfilled` / `declined` states. The merger upserts the
/// latest-by-updated_at status. The refund-on-decline credit is carried as a
/// separate `points_ledger` entry, so this merger only reconciles the
/// redemption row's status — the balance is re-derived by the ledger merger.
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class RewardRedemptionMerger implements EntityMerger {
  RewardRedemptionMerger(UserDatabase db) : _db = db;

  final UserDatabase _db;

  @override
  String get kind => EntityKind.rewardRedemption;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    final existingProfileIds = (await _db.select(_db.learnerProfiles).get())
        .map((p) => p.id)
        .toSet();

    for (final row in rows) {
      final ulid = row['ulid'] as String?;
      final rewardTitle = row['reward_title'] as String?;
      final pointsCost = FirestoreCodec.parseInt(row['points_cost']);
      final status = row['status'] as String?;
      final createdAt = FirestoreCodec.parseDateTime(row['created_at']);
      final updatedAt = FirestoreCodec.parseDateTime(row['updated_at']);
      if (ulid == null ||
          ulid.isEmpty ||
          rewardTitle == null ||
          pointsCost == null ||
          status == null ||
          createdAt == null ||
          updatedAt == null) {
        continue;
      }

      var rowProfileId = FirestoreCodec.parseInt(row['profile_id']) ?? 0;
      if (rowProfileId == 0) rowProfileId = profileId;
      if (!existingProfileIds.contains(rowProfileId)) continue;

      await _db.pointsBalanceDao.upsertRemoteRedemption(
        profileId: rowProfileId,
        ulid: ulid,
        rewardTitle: rewardTitle,
        iconIndex: FirestoreCodec.parseInt(row['icon_index']) ?? 0,
        pointsCost: pointsCost,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    }
  }
}
