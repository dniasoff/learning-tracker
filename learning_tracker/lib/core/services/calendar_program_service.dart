import 'dart:convert';

import 'package:learning_tracker/core/database/app_database.dart';
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
/// Handles caching, merging Sefaria + Hebcal results, and mapping
/// API responses to internal program identifiers.
class CalendarProgramService {
  final SefariaCalendarClient _sefariaClient;
  final HebcalApiClient _hebcalClient;
  final AppDatabase _database;

  CalendarProgramService(
    this._sefariaClient,
    this._hebcalClient,
    this._database,
  );

  /// Get today's calendar programs, using cache when available.
  Future<List<CalendarProgramEntry>> getTodayPrograms() async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final entries = <CalendarProgramEntry>[];

    // Fetch from Sefaria (with caching)
    final sefariaEntries = await _fetchSefariaWithCache(now, dateKey);
    entries.addAll(sefariaEntries);

    // Fetch from Hebcal (with caching)
    final hebcalEntries = await _fetchHebcalWithCache(now, dateKey);
    entries.addAll(hebcalEntries);

    return entries;
  }

  Future<List<CalendarProgramEntry>> _fetchSefariaWithCache(
    DateTime date,
    String dateKey,
  ) async {
    // Check cache
    final cached = await _database.calendarCacheDao.getCached(
      'sefaria',
      dateKey,
    );

    SefariaCalendarResponse response;
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inHours < 24) {
      // Use cached response
      response = SefariaCalendarResponse.fromJson(
        jsonDecode(cached.responseJson) as Map<String, dynamic>,
      );
    } else {
      // Fetch fresh
      response = await _sefariaClient.fetchCalendar(
        year: date.year,
        month: date.month,
        day: date.day,
      );
      // Cache it
      await _database.calendarCacheDao.upsertCache(
        source: 'sefaria',
        dateKey: dateKey,
        responseJson: jsonEncode(_sefariaResponseToJson(response)),
        fetchedAt: DateTime.now().toUtc(),
      );
    }

    // Map API entries to our unified model
    return _mapSefariaEntries(response.calendarItems);
  }

  Future<List<CalendarProgramEntry>> _fetchHebcalWithCache(
    DateTime date,
    String dateKey,
  ) async {
    final cached = await _database.calendarCacheDao.getCached(
      'hebcal',
      dateKey,
    );

    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inHours < 24) {
      // For Hebcal, we store the mapped entries directly
      final items = (jsonDecode(cached.responseJson) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      return items
          .map(
            (e) => CalendarProgramEntry(
              programId: e['programId'] as String,
              displayNameEn: e['displayNameEn'] as String,
              displayNameHe: e['displayNameHe'] as String,
              todayRef: e['todayRef'] as String,
              apiSource: 'hebcal',
            ),
          )
          .toList();
    }

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

      // Cache
      await _database.calendarCacheDao.upsertCache(
        source: 'hebcal',
        dateKey: dateKey,
        responseJson: jsonEncode(
          entries
              .map(
                (e) => {
                  'programId': e.programId,
                  'displayNameEn': e.displayNameEn,
                  'displayNameHe': e.displayNameHe,
                  'todayRef': e.todayRef,
                },
              )
              .toList(),
        ),
        fetchedAt: DateTime.now().toUtc(),
      );

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
      return path.startsWith('/') ? Uri.decodeComponent(path.substring(1)) : Uri.decodeComponent(path);
    } catch (_) {
      return fallback;
    }
  }

  Map<String, dynamic> _sefariaResponseToJson(
    SefariaCalendarResponse response,
  ) {
    return {
      'calendar_items': response.calendarItems
          .map(
            (e) => {
              'title': {'en': e.title.en, 'he': e.title.he},
              'url': e.url,
              'ref': e.sefariaRef,
              'category': e.category,
              'order': e.order,
            },
          )
          .toList(),
      'date': response.date,
      'timezone': response.timezone,
    };
  }
}
