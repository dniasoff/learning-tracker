import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';

/// Provider for the offline-first [LocalCalendarEngine].
///
/// Wraps the [ContentDatabase] from [contentDatabaseProvider]. Story 19.4
/// eliminates the Sefaria / Hebcal calendar clients entirely — every
/// calendar lookup is a local DB read.
final localCalendarEngineProvider = Provider<LocalCalendarEngine>((ref) {
  final contentDb = ref.watch(contentDatabaseProvider);
  return LocalCalendarEngine(contentDb);
});

/// Backward-compatible provider for the calendar program service.
///
/// Now a thin delegate over [LocalCalendarEngine] (Story 19.4 AC-4/AC-5).
final calendarProgramServiceProvider = Provider<CalendarProgramService>((ref) {
  final engine = ref.watch(localCalendarEngineProvider);
  return CalendarProgramService(engine);
});

/// Today's available calendar programs — resolved entirely from the
/// local [ContentDatabase].
final todayCalendarProvider =
    FutureProvider<List<CalendarProgramEntry>>((ref) async {
  final service = ref.watch(calendarProgramServiceProvider);
  return service.getTodayPrograms();
});
