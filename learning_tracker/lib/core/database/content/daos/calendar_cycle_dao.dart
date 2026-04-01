import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/tables/calendar_cycles.dart';

part 'calendar_cycle_dao.g.dart';

/// Read-only DAO for calendar cycle data in the ContentDatabase.
@DriftAccessor(tables: [CalendarCycles])
class CalendarCycleDao extends DatabaseAccessor<ContentDatabase>
    with _$CalendarCycleDaoMixin {
  CalendarCycleDao(super.db);

  /// Get the cycle entry for a specific program and date.
  Future<CalendarCycle?> getCycleForProgramAndDate(
    String programKey,
    String dateKey,
  ) => (select(calendarCycles)
        ..where(
          (t) => t.programKey.equals(programKey) & t.dateKey.equals(dateKey),
        ))
      .getSingleOrNull();

  /// Get all cycles for a specific date (all programs).
  Future<List<CalendarCycle>> getCyclesForDate(String dateKey) =>
      (select(calendarCycles)..where((t) => t.dateKey.equals(dateKey))).get();

  /// Get cycles for a date range for a specific program.
  Future<List<CalendarCycle>> getCyclesForDateRange(
    String programKey,
    String startDate,
    String endDate,
  ) => (select(calendarCycles)
        ..where(
          (t) =>
              t.programKey.equals(programKey) &
              t.dateKey.isBiggerOrEqualValue(startDate) &
              t.dateKey.isSmallerOrEqualValue(endDate),
        ))
      .get();
}
