import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';

/// Provider for the [LocalCalendarEngine].
///
/// Pure computation — no database, no network. Calendar entries are derived
/// from hardcoded sequences + date arithmetic at call time.
final localCalendarEngineProvider = Provider<LocalCalendarEngine>((ref) {
  return LocalCalendarEngine();
});

/// Backward-compatible provider for the calendar program service.
final calendarProgramServiceProvider = Provider<CalendarProgramService>((ref) {
  final engine = ref.watch(localCalendarEngineProvider);
  return CalendarProgramService(engine);
});

/// Today's available calendar programs — computed at call time.
final todayCalendarProvider = FutureProvider<List<CalendarProgramEntry>>((
  ref,
) async {
  final service = ref.watch(calendarProgramServiceProvider);
  return service.getTodayPrograms();
});
