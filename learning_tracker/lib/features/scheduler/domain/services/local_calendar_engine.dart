import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';

/// Offline-first calendar engine that reads pre-computed cycle data from
/// the [ContentDatabase].
///
/// Story 19.4 replaces the API-dependent [CalendarProgramService] with
/// this single query-based engine. Every call is a local DB read — zero
/// network traffic, zero parsing, instant results.
///
/// Dependency chain:
///
///     ContentDatabase
///       └─ CalendarCycles table (pre-populated, read-only)
///            ↓
///       CalendarCycleDao
///            ↓
///       LocalCalendarEngine
///            ↓
///       CalendarProgramService (thin delegate)
class LocalCalendarEngine {
  LocalCalendarEngine(this._contentDb);

  final ContentDatabase _contentDb;

  /// Format a [DateTime] as a `YYYY-MM-DD` string for database lookup.
  ///
  /// Always uses the local date components — callers that need UTC should
  /// convert before passing the value in.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Get the calendar entry for a specific program on a specific date.
  ///
  /// Returns null when:
  /// - no row exists for the given (programId, date) pair
  /// - the `programId` is not known to [CalendarProgramRegistry]
  ///
  /// Story 19.4 AC-1 / AC-3.
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async {
    final dateKey = formatDateKey(date);
    final row = await _contentDb.calendarCycleDao.getEntry(programId, dateKey);
    if (row == null) return null;

    final def = _resolveDefinition(programId);
    if (def == null) return null;

    return CalendarProgramEntry(
      programId: def.id,
      displayNameEn: def.displayNameEn,
      displayNameHe: def.displayNameHe,
      // sefariaRef is non-nullable; sefariaRefHe is nullable — coalesce to ''.
      todayRef: row.sefariaRef,
      todayRefHe: row.sefariaRefHe ?? '',
      apiSource: 'local',
      date: _parseDateKey(row.dateKey),
    );
  }

  /// Get today's calendar entries for every program that has data for
  /// [date] (defaults to `DateTimeFactory.nowLocal()`).
  ///
  /// Programs without data for the given date are silently omitted.
  /// Unknown program IDs stored in the DB are also skipped.
  ///
  /// Story 19.4 AC-2 / AC-3.
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async {
    final effective = date ?? DateTimeFactory.nowLocal();
    final dateKey = formatDateKey(effective);
    final rows = await _contentDb.calendarCycleDao.getEntriesForDate(dateKey);

    final entries = <CalendarProgramEntry>[];
    for (final row in rows) {
      final def = _resolveDefinition(row.programKey);
      if (def == null) continue;
      entries.add(
        CalendarProgramEntry(
          programId: def.id,
          displayNameEn: def.displayNameEn,
          displayNameHe: def.displayNameHe,
          todayRef: row.sefariaRef,
          todayRefHe: row.sefariaRefHe ?? '',
          apiSource: 'local',
          date: _parseDateKey(row.dateKey),
        ),
      );
    }
    return entries;
  }

  /// Get entries for a program across a date range (inclusive), ordered
  /// by date ascending. Powers "upcoming schedule" UI (Story 19.4 AC-7).
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final def = _resolveDefinition(programId);
    if (def == null) return const [];

    final rows = await _contentDb.calendarCycleDao.getEntriesForRange(
      programId,
      formatDateKey(startDate),
      formatDateKey(endDate),
    );
    return rows
        .map(
          (row) => CalendarProgramEntry(
            programId: def.id,
            displayNameEn: def.displayNameEn,
            displayNameHe: def.displayNameHe,
            todayRef: row.sefariaRef,
            apiSource: 'local',
            date: _parseDateKey(row.dateKey),
          ),
        )
        .toList();
  }

  /// Parse a `YYYY-MM-DD` string (as stored in the DB `date_key` column)
  /// back to a local-midnight [DateTime].  Returns null on malformed input
  /// so callers can safely skip corrupt rows.
  static DateTime? _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  /// Legacy alias retained from the pre-19.4 engine — kept so existing
  /// callers (notably [Story 19.1]'s calendar UI) continue to compile.
  /// Prefer [getEntry] for new code.
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) => getEntry(programKey, date);

  /// Resolve a stored program key to a [CalendarProgramDefinition].
  ///
  /// Strict path: look up by registry ID (Story 19.4 T6 mandates the
  /// seed tool use registry IDs). Two legacy fallbacks are kept so
  /// read-side compatibility is preserved if an older seed DB still
  /// uses the Sefaria apiKey or the Hebcal category as the stored
  /// program key.
  CalendarProgramDefinition? _resolveDefinition(String programKey) {
    return CalendarProgramRegistry.byId(programKey) ??
        CalendarProgramRegistry.byApiKey(programKey) ??
        CalendarProgramRegistry.byHebcalCategory(programKey);
  }
}
