import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/tables/calendar_cycles.dart';

part 'calendar_cycle_dao.g.dart';

/// Read-only DAO for pre-computed calendar cycle lookups.
///
/// Queries the [CalendarCycles] table in [ContentDatabase]. This table is
/// populated by the seed build tool and never written to at runtime
/// (Story 19.3 + 19.4).
@DriftAccessor(tables: [CalendarCycles])
class CalendarCycleDao extends DatabaseAccessor<ContentDatabase>
    with _$CalendarCycleDaoMixin {
  CalendarCycleDao(super.db);

  /// Get the calendar entry for a specific program on a specific date.
  ///
  /// Returns null if no data exists for this (program, date) pair.
  /// Primary query used by [LocalCalendarEngine.getEntry] (Story 19.4 AC-1).
  Future<CalendarCycle?> getEntry(String programId, String dateKey) =>
      (select(calendarCycles)
            ..where(
              (t) =>
                  t.programKey.equals(programId) &
                  t.dateKey.equals(dateKey),
            ))
          .getSingleOrNull();

  /// Get all program entries for a specific date.
  ///
  /// Returns one row per program that has data for [dateKey]. Used by
  /// [LocalCalendarEngine.getTodayPrograms] to fetch all registered
  /// programs in a single query (Story 19.4 AC-2).
  Future<List<CalendarCycle>> getEntriesForDate(String dateKey) =>
      (select(calendarCycles)..where((t) => t.dateKey.equals(dateKey))).get();

  /// Get entries for a program across a date range (inclusive), ordered
  /// by date ascending. Powers "upcoming schedule" UI (Story 19.4 AC-7).
  Future<List<CalendarCycle>> getEntriesForRange(
    String programId,
    String startDate,
    String endDate,
  ) =>
      (select(calendarCycles)
            ..where(
              (t) =>
                  t.programKey.equals(programId) &
                  t.dateKey.isBiggerOrEqualValue(startDate) &
                  t.dateKey.isSmallerOrEqualValue(endDate),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.dateKey)]))
          .get();

  // ── Legacy method names kept for backward compatibility ──────────────

  /// Deprecated: use [getEntry] instead.
  Future<CalendarCycle?> getCycleForProgramAndDate(
    String programKey,
    String dateKey,
  ) =>
      getEntry(programKey, dateKey);

  /// Deprecated: use [getEntriesForDate] instead.
  Future<List<CalendarCycle>> getCyclesForDate(String dateKey) =>
      getEntriesForDate(dateKey);

  /// Deprecated: use [getEntriesForRange] instead.
  Future<List<CalendarCycle>> getCyclesForDateRange(
    String programKey,
    String startDate,
    String endDate,
  ) =>
      getEntriesForRange(programKey, startDate, endDate);
}
