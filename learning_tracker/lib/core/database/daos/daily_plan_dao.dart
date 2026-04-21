import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/daily_plans.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'daily_plan_dao.g.dart';

/// DAO for the [DailyPlans] table.
///
/// Plans are snapshotted once per local day. [getPlanForDay] is the
/// hot path: returns the full plan for a profile on a given local date.
@DriftAccessor(tables: [DailyPlans])
class DailyPlanDao extends DatabaseAccessor<UserDatabase>
    with _$DailyPlanDaoMixin {
  DailyPlanDao(super.db);

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

  Future<void> insertEntries(List<DailyPlansCompanion> entries) async {
    if (entries.isEmpty) return;
    await batch((b) {
      b.insertAll(dailyPlans, entries, mode: InsertMode.insertOrIgnore);
    });
  }

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
