import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/local_calendar_engine.dart';

/// Provider for the offline-first [LocalCalendarEngine].
///
/// Wraps the [ContentDatabase] from [contentDatabaseProvider]. Story 19.4
/// eliminates the Sefaria / Hebcal calendar clients entirely — every
/// calendar lookup is a local DB read.
///
/// Async because [contentDatabaseProvider] is a [FutureProvider] (the content
/// DB is decompressed lazily on first access after cold start).
final localCalendarEngineProvider = FutureProvider<LocalCalendarEngine>((
  ref,
) async {
  final contentDb = await ref.watch(contentDatabaseProvider.future);
  return LocalCalendarEngine(contentDb);
});

/// Backward-compatible provider for the calendar program service.
///
/// Now a thin delegate over [LocalCalendarEngine] (Story 19.4 AC-4/AC-5).
///
/// Async because [localCalendarEngineProvider] is a [FutureProvider].
final calendarProgramServiceProvider = FutureProvider<CalendarProgramService>((
  ref,
) async {
  final engine = await ref.watch(localCalendarEngineProvider.future);
  return CalendarProgramService(engine);
});

/// Today's available calendar programs — resolved entirely from the
/// local [ContentDatabase].
final todayCalendarProvider = FutureProvider<List<CalendarProgramEntry>>((
  ref,
) async {
  final service = await ref.watch(calendarProgramServiceProvider.future);
  return service.getTodayPrograms();
});
