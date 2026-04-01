import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/network/dio_provider.dart';
import 'package:learning_tracker/core/network/hebcal/dio_hebcal_provider.dart';
import 'package:learning_tracker/core/network/hebcal/hebcal_api_client.dart';
import 'package:learning_tracker/core/network/sefaria/sefaria_calendar_client.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';

/// Provider for the Sefaria Calendar API client.
final sefariaCalendarClientProvider = Provider<SefariaCalendarClient>((ref) {
  final dio = ref.watch(dioProvider);
  return SefariaCalendarClient(dio);
});

/// Provider for the Hebcal API client.
final hebcalClientProvider = Provider<HebcalApiClient>((ref) {
  final dio = ref.watch(hebcalDioProvider);
  return HebcalApiClient(dio);
});

/// Provider for the local calendar engine (offline-first).
final localCalendarEngineProvider = Provider<LocalCalendarEngine>((ref) {
  final contentDb = ref.watch(contentDatabaseProvider);
  return LocalCalendarEngine(contentDb);
});

/// Provider for the calendar program service (API fallback).
final calendarProgramServiceProvider = Provider<CalendarProgramService>((ref) {
  final sefariaClient = ref.watch(sefariaCalendarClientProvider);
  final hebcalClient = ref.watch(hebcalClientProvider);
  return CalendarProgramService(sefariaClient, hebcalClient);
});

/// Today's available calendar programs.
///
/// Uses local engine as primary source. Falls back to API if local
/// data is empty (seed DB not yet populated with calendar cycles).
final todayCalendarProvider = FutureProvider<List<CalendarProgramEntry>>((
  ref,
) async {
  // Try local first (offline-first)
  final localEngine = ref.watch(localCalendarEngineProvider);
  final localResults = await localEngine.getTodayPrograms();

  if (localResults.isNotEmpty) {
    return localResults;
  }

  // Fallback to API if local data is empty
  final service = ref.watch(calendarProgramServiceProvider);
  return service.getTodayPrograms();
});
