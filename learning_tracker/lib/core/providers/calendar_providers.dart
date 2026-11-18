import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

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

/// Today's bundled calendar programs plus the current weekly Torah and
/// Haftarah readings when Sefaria's public calendar is reachable.
final todayCalendarProvider = FutureProvider<List<CalendarProgramEntry>>((
  ref,
) async {
  final service = await ref.watch(calendarProgramServiceProvider.future);
  final localEntries = await service.getTodayPrograms();
  return _withWeeklyReadings(localEntries);
});

/// Adds the weekly Torah portion and Haftarah, which are not part of the
/// bundled daily-cycle calendar table. Their text is still opened from the
/// local content index by the Learn screen.
Future<List<CalendarProgramEntry>> _withWeeklyReadings(
  List<CalendarProgramEntry> localEntries,
) async {
  final now = DateTime.now();
  final uri = Uri.https('www.sefaria.org', '/api/calendars', {
    'diaspora': '1',
    'custom': 'ashkenazi',
    'year': '${now.year}',
    'month': '${now.month}',
    'day': '${now.day}',
  });

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return localEntries;
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['calendar_items'] as List<dynamic>? ?? const [];
    final weeklyEntries = <CalendarProgramEntry>[];
    for (final value in items) {
      if (value is! Map<String, dynamic>) continue;
      final title = value['title'] as Map<String, dynamic>?;
      final program = switch (title?['en']) {
        'Parashat Hashavua' => CalendarProgramRegistry.byId('weekly_parsha'),
        'Haftarah' => CalendarProgramRegistry.byId('haftarah'),
        _ => null,
      };
      if (program == null) continue;

      final ref = _calendarRef(value['ref'] as String?) ??
          _calendarRef(value['url'] as String?);
      if (ref == null || ref.isEmpty) continue;
      final display = value['displayValue'] as Map<String, dynamic>?;
      weeklyEntries.add(
        CalendarProgramEntry(
          programId: program.id,
          displayNameEn: program.displayNameEn,
          displayNameHe: program.displayNameHe,
          todayRef: ref,
          todayRefHe:
              (value['heRef'] as String?) ?? (display?['he'] as String?) ?? '',
          apiSource: 'sefaria',
          date: DateTime.utc(now.year, now.month, now.day),
        ),
      );
    }

    if (weeklyEntries.isEmpty) return localEntries;
    final entriesById = {
      for (final entry in localEntries) entry.programId: entry,
    };
    for (final entry in weeklyEntries) {
      entriesById[entry.programId] = entry;
    }
    return entriesById.values.toList(growable: false);
  } catch (_) {
    // Calendar lookup is supplemental: retain the bundled daily schedule
    // when the device is offline or the public calendar service is unavailable.
    return localEntries;
  }
}

String? _calendarRef(String? value) {
  if (value == null || value.isEmpty) return null;
  final path = Uri.decodeComponent(value).split('?').first.replaceFirst(
    RegExp(r'^/'),
    '',
  );
  if (!path.contains('.')) return path;
  final firstSeparator = path.indexOf('.');
  return '${path.substring(0, firstSeparator)} '
      '${path.substring(firstSeparator + 1).replaceAll('.', ':')}';
}
