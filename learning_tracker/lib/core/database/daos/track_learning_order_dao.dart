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

  Future<void> upsertOrder(int trackId, List<String> refs) async {
    for (var i = 0; i < refs.length; i++) {
      await into(trackLearningOrder).insert(
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
  }

  Future<void> deleteByTrack(int trackId) =>
      (delete(trackLearningOrder)..where((t) => t.trackId.equals(trackId)))
          .go();
}
