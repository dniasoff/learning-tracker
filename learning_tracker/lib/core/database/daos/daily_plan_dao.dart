import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/daily_plans.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'daily_plan_dao.g.dart';

/// DAO for the [DailyPlans] table.
///
/// Plans are snapshotted once per local day. [getPlanForDay] is the
/// hot path: returns the full plan for a profile on a given local date.
@DriftAccessor(tables: [DailyPlans])
class DailyPlanDao extends DatabaseAccessor<UserDatabase>
    with
        _$DailyPlanDaoMixin,
        BaseDao<$DailyPlansTable, DailyPlan, UserDatabase> {
  DailyPlanDao(super.db);

  @override
  TableInfo<$DailyPlansTable, DailyPlan> get table => dailyPlans;

  @override
  Expression<int> idColumn($DailyPlansTable t) => t.id;

  @override
  Expression<int> profileIdColumn($DailyPlansTable t) => t.profileId;

  Future<List<DailyPlan>> getPlanForDay({
    required int profileId,
    required DateTime planDate,
  }) {
    return (select(dailyPlans)
          ..where(
            (t) => t.profileId.equals(profileId) & t.planDate.equals(planDate),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Stream<List<DailyPlan>> watchPlanForDay({
    required int profileId,
    required DateTime planDate,
  }) {
    return (select(dailyPlans)
          ..where(
            (t) => t.profileId.equals(profileId) & t.planDate.equals(planDate),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  Future<bool> hasPlanForDay({
    required int profileId,
    required DateTime planDate,
  }) async {
    final count =
        await (selectOnly(dailyPlans)
              ..addColumns([dailyPlans.id.count()])
              ..where(
                dailyPlans.profileId.equals(profileId) &
                    dailyPlans.planDate.equals(planDate),
              ))
            .getSingle();
    return (count.read(dailyPlans.id.count()) ?? 0) > 0;
  }

  /// Whether a snapshot exists for ([trackId], [planDate]). Per-track
  /// granular check used by back-fill so a profile with several tracks
  /// doesn't skip back-fill for a track just because another track has
  /// already been snapshotted that day.
  Future<bool> hasPlanForTrackOnDay({
    required int trackId,
    required DateTime planDate,
  }) async {
    final count =
        await (selectOnly(dailyPlans)
              ..addColumns([dailyPlans.id.count()])
              ..where(
                dailyPlans.trackId.equals(trackId) &
                    dailyPlans.planDate.equals(planDate),
              ))
            .getSingle();
    return (count.read(dailyPlans.id.count()) ?? 0) > 0;
  }

  /// Distinct sefariaRefs that have appeared in **any** snapshot for
  /// [trackId] strictly before [excludeDate]. Used by the snapshot-aware
  /// new-learning path to identify items that were already shown — so
  /// uncompleted ones become "overdue" today and the new-learning batch
  /// can skip them.
  Future<Set<String>> getPriorlyShownRefsForTrack({
    required int trackId,
    required DateTime excludeDate,
  }) async {
    final rows =
        await (selectOnly(dailyPlans, distinct: true)
              ..addColumns([dailyPlans.sefariaRef])
              ..where(
                dailyPlans.trackId.equals(trackId) &
                    dailyPlans.planDate.isSmallerThanValue(excludeDate),
              ))
            .get();
    return rows.map((r) => r.read(dailyPlans.sefariaRef)!).toSet();
  }

  Future<void> insertEntries(List<DailyPlansCompanion> entries) async {
    if (entries.isEmpty) return;
    await batch((b) {
      b.insertAll(dailyPlans, entries, mode: InsertMode.insertOrIgnore);
    });
  }

  /// Delete all plan rows for a specific track (used when hard-deleting a track).
  Future<void> deletePlansByTrack(int trackId) =>
      (delete(dailyPlans)..where((t) => t.trackId.equals(trackId))).go();

  /// Remove all snapshot rows for a single local day/profile pair.
  Future<void> deletePlanForDay({
    required int profileId,
    required DateTime planDate,
  }) {
    return (delete(dailyPlans)..where(
          (t) => t.profileId.equals(profileId) & t.planDate.equals(planDate),
        ))
        .go();
  }

  /// Remove plan entries older than [olderThan]. Keeps the table bounded
  /// without requiring a background job — call opportunistically.
  Future<void> deleteOlderThan(DateTime olderThan) {
    return (delete(
      dailyPlans,
    )..where((t) => t.planDate.isSmallerThanValue(olderThan))).go();
  }
}
