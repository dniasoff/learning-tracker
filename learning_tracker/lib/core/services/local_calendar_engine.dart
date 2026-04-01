import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';

/// Local-first calendar engine that reads from the pre-built Content DB.
///
/// Replaces API-dependent calendar lookups. All 12 programs work
/// identically offline — no network required.
class LocalCalendarEngine {
  LocalCalendarEngine(this._contentDb);

  final ContentDatabase _contentDb;

  /// Get today's calendar programs from local Content DB.
  ///
  /// Returns entries for all programs that have data for [date].
  /// Falls back to empty list if no data available (seed not populated yet).
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async {
    final now = date ?? DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final cycles =
        await _contentDb.calendarCycleDao.getCyclesForDate(dateKey);

    return cycles
        .map((cycle) {
          final def =
              CalendarProgramRegistry.byApiKey(cycle.programKey) ??
              CalendarProgramRegistry.byHebcalCategory(cycle.programKey) ??
              CalendarProgramRegistry.byId(cycle.programKey);
          if (def == null) return null;

          return CalendarProgramEntry(
            programId: def.id,
            displayNameEn: def.displayNameEn,
            displayNameHe: def.displayNameHe,
            todayRef: cycle.sefariaRef,
            apiSource: 'local',
          );
        })
        .whereType<CalendarProgramEntry>()
        .toList();
  }

  /// Get a specific program's assignment for a date.
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) async {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final cycle = await _contentDb.calendarCycleDao
        .getCycleForProgramAndDate(programKey, dateKey);

    if (cycle == null) return null;

    final def =
        CalendarProgramRegistry.byApiKey(programKey) ??
        CalendarProgramRegistry.byHebcalCategory(programKey) ??
        CalendarProgramRegistry.byId(programKey);
    if (def == null) return null;

    return CalendarProgramEntry(
      programId: def.id,
      displayNameEn: def.displayNameEn,
      displayNameHe: def.displayNameHe,
      todayRef: cycle.sefariaRef,
      apiSource: 'local',
    );
  }
}
