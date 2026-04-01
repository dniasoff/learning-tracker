import 'package:learning_tracker/core/network/hebcal/hebcal_api_client.dart';
import 'package:learning_tracker/core/network/sefaria/models/sefaria_calendar_response.dart';
import 'package:learning_tracker/core/network/sefaria/sefaria_calendar_client.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';

/// Unified calendar entry combining data from any API source.
class CalendarProgramEntry {
  final String programId;
  final String displayNameEn;
  final String displayNameHe;
  final String todayRef;
  final String apiSource;

  const CalendarProgramEntry({
    required this.programId,
    required this.displayNameEn,
    required this.displayNameHe,
    required this.todayRef,
    required this.apiSource,
  });
}

/// Service that orchestrates calendar program data from multiple APIs.
///
/// Fetches fresh data from Sefaria + Hebcal on each call.
/// Story 19.4 will replace API calls with local CalendarCycles lookups.
class CalendarProgramService {
  final SefariaCalendarClient _sefariaClient;
  final HebcalApiClient _hebcalClient;

  CalendarProgramService(
    this._sefariaClient,
    this._hebcalClient,
  );

  /// Get today's calendar programs, fetching fresh from APIs.
  Future<List<CalendarProgramEntry>> getTodayPrograms() async {
    final now = DateTime.now();

    final entries = <CalendarProgramEntry>[];

    // Fetch from Sefaria
    final sefariaEntries = await _fetchSefaria(now);
    entries.addAll(sefariaEntries);

    // Fetch from Hebcal
    final hebcalEntries = await _fetchHebcal(now);
    entries.addAll(hebcalEntries);

    return entries;
  }

  Future<List<CalendarProgramEntry>> _fetchSefaria(DateTime date) async {
    final response = await _sefariaClient.fetchCalendar(
      year: date.year,
      month: date.month,
      day: date.day,
    );

    // Map API entries to our unified model
    return _mapSefariaEntries(response.calendarItems);
  }

  Future<List<CalendarProgramEntry>> _fetchHebcal(DateTime date) async {
    try {
      final response = await _hebcalClient.fetchDailyLearning(date: date);
      final entries = <CalendarProgramEntry>[];

      for (final item in response.items) {
        final def = item.category != null
            ? CalendarProgramRegistry.byHebcalCategory(item.category!)
            : null;
        if (def != null) {
          entries.add(
            CalendarProgramEntry(
              programId: def.id,
              displayNameEn: def.displayNameEn,
              displayNameHe: def.displayNameHe,
              todayRef: _extractSefariaRefFromLink(
                item.link,
                item.memo ?? item.title,
              ),
              apiSource: 'hebcal',
            ),
          );
        }
      }

      return entries;
    } catch (_) {
      // Hebcal is secondary — don't fail if it's down
      return [];
    }
  }

  List<CalendarProgramEntry> _mapSefariaEntries(List<CalendarEntry> items) {
    final entries = <CalendarProgramEntry>[];
    for (final item in items) {
      final def = CalendarProgramRegistry.byApiKey(item.title.en);
      if (def != null) {
        entries.add(
          CalendarProgramEntry(
            programId: def.id,
            displayNameEn: def.displayNameEn,
            displayNameHe: def.displayNameHe,
            todayRef: item.sefariaRef,
            apiSource: 'sefaria',
          ),
        );
      }
    }
    return entries;
  }

  /// Extract a Sefaria ref from a Hebcal link URL.
  ///
  /// Hebcal items include a `link` field like:
  /// `https://www.sefaria.org/Chofetz_Chaim%2C_Part_One...?lang=bi&utm_source=hebcal.com`
  /// The Sefaria ref is the URL-decoded path component.
  String _extractSefariaRefFromLink(String? link, String fallback) {
    if (link == null || !link.contains('sefaria.org/')) return fallback;
    try {
      final uri = Uri.parse(link);
      final path = uri.path;
      // Remove leading '/' to get the ref
      final rawRef = path.startsWith('/') ? path.substring(1) : path;
      return Uri.decodeComponent(rawRef);
    } catch (_) {
      return fallback;
    }
  }
}
