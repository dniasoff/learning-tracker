import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/calendar_cache.dart';

part 'calendar_cache_dao.g.dart';

/// DAO for calendar API response caching.
@DriftAccessor(tables: [CalendarCache])
class CalendarCacheDao extends DatabaseAccessor<AppDatabase>
    with _$CalendarCacheDaoMixin {
  CalendarCacheDao(super.db);

  /// Get cached response for a source and date.
  Future<CalendarCacheData?> getCached(String source, String dateKey) =>
      (select(calendarCache)
            ..where((t) => t.source.equals(source) & t.dateKey.equals(dateKey)))
          .getSingleOrNull();

  /// Insert or update a cached response.
  Future<void> upsertCache({
    required String source,
    required String dateKey,
    required String responseJson,
    required DateTime fetchedAt,
  }) async {
    final existing = await getCached(source, dateKey);
    if (existing != null) {
      await (update(
        calendarCache,
      )..where((t) => t.id.equals(existing.id))).write(
        CalendarCacheCompanion(
          responseJson: Value(responseJson),
          fetchedAt: Value(fetchedAt),
        ),
      );
    } else {
      await into(calendarCache).insert(
        CalendarCacheCompanion.insert(
          source: source,
          dateKey: dateKey,
          responseJson: responseJson,
          fetchedAt: fetchedAt,
        ),
      );
    }
  }
}
