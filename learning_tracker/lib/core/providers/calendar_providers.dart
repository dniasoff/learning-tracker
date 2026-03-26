import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/network/dio_provider.dart';
import 'package:learning_tracker/core/network/hebcal/dio_hebcal_provider.dart';
import 'package:learning_tracker/core/network/hebcal/hebcal_api_client.dart';
import 'package:learning_tracker/core/network/sefaria/sefaria_calendar_client.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';

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

/// Provider for the calendar program service.
final calendarProgramServiceProvider = Provider<CalendarProgramService>((ref) {
  final sefariaClient = ref.watch(sefariaCalendarClientProvider);
  final hebcalClient = ref.watch(hebcalClientProvider);
  final database = ref.watch(appDatabaseProvider);
  return CalendarProgramService(sefariaClient, hebcalClient, database);
});

/// Today's available calendar programs.
final todayCalendarProvider = FutureProvider<List<CalendarProgramEntry>>((
  ref,
) async {
  final service = ref.watch(calendarProgramServiceProvider);
  return service.getTodayPrograms();
});
