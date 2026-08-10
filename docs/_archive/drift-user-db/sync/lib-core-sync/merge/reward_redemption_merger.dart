/// LWW merger for `reward_redemptions` rows (WS9 Wave-B / C#2).
///
/// Reward redemptions are an LWW state-machine: each doc is keyed by its
/// `ulid` and the latest `updated_at` wins. `pending_fulfilment` transitions
/// to the terminal `fulfilled` / `declined` states. The merger upserts the
/// latest-by-updated_at status. The refund-on-decline credit is carried as a
/// separate `points_ledger` entry, so this merger only reconciles the
/// redemption row's status — the balance is re-derived by the ledger merger.
///
/// AD-7 / MCF-13: the ordering decision itself is **not** made here and is no
/// longer bespoke. `PointsBalanceDao.upsertRemoteRedemption` performs the
/// read-decide-write inside one statement sequence and routes the decision
/// through the single canonical predicate
/// (`lib/data/firestore/conflict.dart`), like every other reconciliation
/// path — no per-merger exception. Deciding here instead would reintroduce a
/// read-then-write TOCTOU against the row the DAO is about to update.
library;

import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class RewardRedemptionMerger implements EntityMerger {
  RewardRedemptionMerger(UserDatabase db, {AppLogger? logger})
    : _db = db,
      _logger = logger;

  final UserDatabase _db;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;

  @override
  String get kind => EntityKind.rewardRedemption;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    // FK guard: reward_redemptions.profileId references learner_profiles.
    // AUD-core-sync-34: shared helper — see ProfileDao.existingProfileIds.
    final existingProfileIds = await _db.profileDao.existingProfileIds();

    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
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
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_reward_redemption_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
