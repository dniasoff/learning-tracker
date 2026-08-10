import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/track_learning_order.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'track_learning_order_dao.g.dart';

@DriftAccessor(tables: [TrackLearningOrder])
class TrackLearningOrderDao extends DatabaseAccessor<UserDatabase>
    with _$TrackLearningOrderDaoMixin {
  TrackLearningOrderDao(super.db);

  /// AUD-t-cross-06: filters by [profileId] AND [trackId] — not trackId
  /// alone — so a stale/confused trackId from a caching or profile-switch
  /// bug can never surface another profile's custom ordering.
  Future<List<TrackLearningOrderData>> getByTrack(int profileId, int trackId) =>
      (select(trackLearningOrder)
            ..where(
              (t) => t.profileId.equals(profileId) & t.trackId.equals(trackId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  /// Upserts [refs] as the ordered learning-order rows for [trackId],
  /// scoped to [profileId].
  ///
  /// AUD-core-database-05 (DB-2/DB-3): issues a single `batch()` instead of
  /// an awaited per-row loop. A per-row loop re-prepares the same statement
  /// N times (write amplification) and, more importantly, is NOT atomic — a
  /// crash or thrown error partway through a reorder of dozens/hundreds of
  /// refs left a half-old/half-new `sortOrder` sequence with no error
  /// surfaced anywhere. `batch()` runs every insert in one round trip inside
  /// its own transaction (or the caller's enclosing `transaction()`, if any
  /// — see [DatabaseConnectionUser.batch]), so a failure on any row rolls
  /// back the whole set.
  Future<void> upsertOrder(
    int profileId,
    int trackId,
    List<String> refs,
  ) async {
    await batch((b) {
      for (var i = 0; i < refs.length; i++) {
        b.insert(
          trackLearningOrder,
          TrackLearningOrderCompanion.insert(
            profileId: profileId,
            trackId: trackId,
            sefariaRef: refs[i],
            sortOrder: i,
          ),
          onConflict: DoUpdate(
            (_) => TrackLearningOrderCompanion(sortOrder: Value(i)),
            target: [
              trackLearningOrder.profileId,
              trackLearningOrder.trackId,
              trackLearningOrder.sefariaRef,
            ],
          ),
        );
      }
    });
  }

  /// AUD-t-cross-06: filters by [profileId] AND [trackId] (see [getByTrack]).
  Future<void> deleteByTrack(int profileId, int trackId) =>
      (delete(trackLearningOrder)..where(
            (t) => t.profileId.equals(profileId) & t.trackId.equals(trackId),
          ))
          .go();
}
