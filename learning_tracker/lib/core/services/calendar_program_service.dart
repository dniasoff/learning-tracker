import 'package:learning_tracker/core/services/local_calendar_engine.dart';

/// Unified calendar entry combining data from any source.
///
/// The class shape is unchanged from the pre-19.4 API-backed service
/// so all UI consumers continue to compile. After Story 19.4,
/// [apiSource] is always `'local'` — all data now comes from the
/// pre-built ContentDatabase seed.
class CalendarProgramEntry {
  const CalendarProgramEntry({
    required this.programId,
    required this.displayNameEn,
    required this.displayNameHe,
    required this.todayRef,
    required this.apiSource,
  });

  final String programId;
  final String displayNameEn;
  final String displayNameHe;
  final String todayRef;
  final String apiSource;
}

/// Calendar program service.
///
/// Historically orchestrated Sefaria + Hebcal API calls with a 24-hour
/// cache. After Story 19.4 this is a thin delegate over
/// [LocalCalendarEngine]: every call is a local-DB read, no network
/// traffic, no JSON parsing, no cache.
class CalendarProgramService {
  CalendarProgramService(this._engine);

  final LocalCalendarEngine _engine;

  /// Get today's calendar programs from local pre-computed data.
  /// Story 19.4 AC-4.
  Future<List<CalendarProgramEntry>> getTodayPrograms() =>
      _engine.getTodayPrograms();

  /// Get a specific program's entry for a specific date.
  Future<CalendarProgramEntry?> getEntry(String programId, DateTime date) =>
      _engine.getEntry(programId, date);

  /// Get entries for a program across a date range (inclusive).
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) =>
      _engine.getEntriesForRange(programId, startDate, endDate);
}
