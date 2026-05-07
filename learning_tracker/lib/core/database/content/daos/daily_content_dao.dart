import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/tables/daily_content.dart';

part 'daily_content_dao.g.dart';

/// Read-only DAO for the calendar-driven pre-resolved text table.
@DriftAccessor(tables: [DailyContent])
class DailyContentDao extends DatabaseAccessor<ContentDatabase>
    with _$DailyContentDaoMixin {
  DailyContentDao(super.db);

  Future<DailyContentData?> getByRef(String sefariaRef) => (select(
    dailyContent,
  )..where((t) => t.sefariaRef.equals(sefariaRef))).getSingleOrNull();

  Stream<DailyContentData?> watchByRef(String sefariaRef) => (select(
    dailyContent,
  )..where((t) => t.sefariaRef.equals(sefariaRef))).watchSingleOrNull();
}
