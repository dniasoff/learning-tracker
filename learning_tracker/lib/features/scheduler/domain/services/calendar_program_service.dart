import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/scheduler/domain/labels/program_label_resolver.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';

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
    this.todayRefHe = '',
    this.date,
  });

  final String programId;
  final String displayNameEn;
  final String displayNameHe;

  /// English Sefaria ref (e.g. `Hullin 7`).
  final String todayRef;

  /// Hebrew form of the same ref (`heRef` from /api/calendars), or the
  /// empty string when the API didn't supply one. UI consumers should
  /// fall back to [todayRef] when this is empty.
  final String todayRefHe;
  final String apiSource;

  /// The calendar date this entry represents (UTC midnight, `.isUtc == true`).
  ///
  /// Populated by [LocalCalendarEngine] from the DB's `date_key` column so
  /// that projection code can use the true calendar date rather than
  /// inferring it from a sequential cursor walk.  UTC midnight is required by
  /// the projection helpers (`_dayOnly` in `overdue_schedule.dart`) which
  /// re-create `DateTime.utc` from the year/month/day components — a local
  /// midnight would shift the date by the device's UTC offset (R4-1).
  /// Null only in legacy construction paths that pre-date this field; the
  /// scheduler projection asserts non-null before using it.
  final DateTime? date;
}

/// Pure-string label for a [CalendarProgramEntry] respecting the Hebrew
/// Terms toggle. Routes through [ProgramLabelResolver] (the scheduler-side
/// shim that reads the toggle source-of-truth in `lib/core/labels/`) so
/// this scheduler service does not read `useHebrewTermsProvider` directly
/// — see audit rule 7/15 — and so `lib/core/` does not import scheduler
/// types (Rule 1).
String calendarEntryLabelText(
  WidgetRef ref, {
  required CalendarProgramEntry entry,
}) => ProgramLabelResolver.of(ref).calendarEntryLabel(entry);

/// Today's-ref label for a [CalendarProgramEntry] respecting the Hebrew
/// Terms toggle. Falls back to the English [CalendarProgramEntry.todayRef]
/// when the Hebrew form is unavailable.
String calendarEntryTodayRefText(
  WidgetRef ref, {
  required CalendarProgramEntry entry,
}) => ProgramLabelResolver.of(ref).calendarEntryTodayRef(entry);

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
  ) => _engine.getEntriesForRange(programId, startDate, endDate);
}
