import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/track_learning_order.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'track_learning_order_dao.g.dart';

@DriftAccessor(tables: [TrackLearningOrder])
class TrackLearningOrderDao extends DatabaseAccessor<UserDatabase>
    with _$TrackLearningOrderDaoMixin {
  TrackLearningOrderDao(super.db);

  Future<List<TrackLearningOrderData>> getByTrack(int trackId) =>
      (select(trackLearningOrder)
            ..where((t) => t.trackId.equals(trackId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  /// Upserts [refs] as the ordered learning-order rows for [trackId].
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
  Future<void> upsertOrder(int trackId, List<String> refs) async {
    await batch((b) {
      for (var i = 0; i < refs.length; i++) {
        b.insert(
          trackLearningOrder,
          TrackLearningOrderCompanion.insert(
            trackId: trackId,
            sefariaRef: refs[i],
            sortOrder: i,
          ),
          onConflict: DoUpdate(
            (_) => TrackLearningOrderCompanion(sortOrder: Value(i)),
            target: [trackLearningOrder.trackId, trackLearningOrder.sefariaRef],
          ),
        );
      }
    });
  }

  Future<void> deleteByTrack(int trackId) => (delete(
    trackLearningOrder,
  )..where((t) => t.trackId.equals(trackId))).go();
}
