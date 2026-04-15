import 'package:learning_tracker/core/data/calendar_sequences/arukh_hashulchan_seq.dart';
import 'package:learning_tracker/core/data/calendar_sequences/chofetz_chaim_tables.dart';
import 'package:learning_tracker/core/data/calendar_sequences/daf_yomi_seq.dart';
import 'package:learning_tracker/core/data/calendar_sequences/halakhah_yomit_seq.dart';
import 'package:learning_tracker/core/data/calendar_sequences/kitzur_sa_table.dart';
import 'package:learning_tracker/core/data/calendar_sequences/mishnah_yomit_seq.dart';
import 'package:learning_tracker/core/data/calendar_sequences/nach_yomi_seq.dart';
import 'package:learning_tracker/core/data/calendar_sequences/rambam_1c_seq.dart';
import 'package:learning_tracker/core/data/calendar_sequences/rambam_3c_seq.dart';
import 'package:learning_tracker/core/data/calendar_sequences/tanakh_yomi_data.dart';
import 'package:learning_tracker/core/data/calendar_sequences/yerushalmi_yomi_seq.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';

/// Offline-first calendar engine that computes cycle data from hardcoded
/// sequences — zero network traffic, zero database reads, instant results.
///
/// Every program is a deterministic cycle: `sequence[daysSinceAnchor % len]`.
/// Four special programs use Hebrew-calendar-aware or pre-computed lookups.
class LocalCalendarEngine {
  /// Format a [DateTime] as a `YYYY-MM-DD` string.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Get the calendar entry for a specific program on a specific date.
  Future<CalendarProgramEntry?> getEntry(
    String programId,
    DateTime date,
  ) async {
    final ref = _computeRef(programId, date);
    if (ref == null) return null;
    final def = _resolveDefinition(programId);
    if (def == null) return null;
    return CalendarProgramEntry(
      programId: def.id,
      displayNameEn: def.displayNameEn,
      displayNameHe: def.displayNameHe,
      todayRef: ref,
      apiSource: 'computed',
    );
  }

  /// Get today's calendar entries for every registered program.
  Future<List<CalendarProgramEntry>> getTodayPrograms([DateTime? date]) async {
    final effective = date ?? DateTime.now();
    final entries = <CalendarProgramEntry>[];
    for (final gen in _generators) {
      final ref = gen.compute(effective);
      if (ref == null) continue;
      final def = CalendarProgramRegistry.byId(gen.programId);
      if (def == null) continue;
      entries.add(
        CalendarProgramEntry(
          programId: def.id,
          displayNameEn: def.displayNameEn,
          displayNameHe: def.displayNameHe,
          todayRef: ref,
          apiSource: 'computed',
        ),
      );
    }
    return entries;
  }

  /// Get entries for a program across a date range (inclusive), ordered
  /// by date ascending.
  Future<List<CalendarProgramEntry>> getEntriesForRange(
    String programId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final def = _resolveDefinition(programId);
    if (def == null) return const [];
    final results = <CalendarProgramEntry>[];
    for (var d = startDate;
        !d.isAfter(endDate);
        d = d.add(const Duration(days: 1))) {
      final ref = _computeRef(programId, d);
      if (ref == null) continue;
      results.add(
        CalendarProgramEntry(
          programId: def.id,
          displayNameEn: def.displayNameEn,
          displayNameHe: def.displayNameHe,
          todayRef: ref,
          apiSource: 'computed',
        ),
      );
    }
    return results;
  }

  /// Legacy alias — prefer [getEntry] for new code.
  Future<CalendarProgramEntry?> getProgramForDate(
    String programKey,
    DateTime date,
  ) =>
      getEntry(programKey, date);

  // ── Private ─────────────────────────────────────────────────────────

  String? _computeRef(String programId, DateTime date) {
    for (final gen in _generators) {
      if (gen.programId == programId) return gen.compute(date);
    }
    return null;
  }

  CalendarProgramDefinition? _resolveDefinition(String programKey) {
    return CalendarProgramRegistry.byId(programKey) ??
        CalendarProgramRegistry.byApiKey(programKey) ??
        CalendarProgramRegistry.byHebcalCategory(programKey);
  }
}

// ── Modular-arithmetic helper ──────────────────────────────────────────

int _cyclicIndex(DateTime date, DateTime anchor, int length) {
  final days = date.toUtc().difference(anchor.toUtc()).inDays;
  return (days % length + length) % length;
}

// ── Per-program generators ─────────────────────────────────────────────

class _ProgramGenerator {
  const _ProgramGenerator({required this.programId, required this.compute});
  final String programId;
  final String? Function(DateTime date) compute;
}

final _generators = <_ProgramGenerator>[
  // 1. Daf Yomi — 2,711 days, anchor 2020-01-05.
  _ProgramGenerator(
    programId: 'daf_yomi',
    compute: (d) {
      final idx = _cyclicIndex(d, DateTime.utc(2020, 1, 5), dafYomiSequence.length);
      return dafYomiSequence[idx];
    },
  ),
  // 2. Daf a Week — same sequence, weekly.
  _ProgramGenerator(
    programId: 'daf_a_week',
    compute: (d) {
      final anchor = DateTime.utc(2005, 3, 6);
      final weeks = d.toUtc().difference(anchor).inDays ~/ 7;
      final idx = (weeks % dafYomiSequence.length + dafYomiSequence.length) %
          dafYomiSequence.length;
      return dafYomiSequence[idx];
    },
  ),
  // 3. Mishnah Yomit — 2,097 days, anchor 2027-09-21.
  _ProgramGenerator(
    programId: 'mishna_yomit',
    compute: (d) {
      final idx =
          _cyclicIndex(d, DateTime.utc(2027, 9, 21), mishnahYomitSequence.length);
      return mishnahYomitSequence[idx];
    },
  ),
  // 4. Rambam 1 Chapter — 979 days, anchor 2024-06-22.
  _ProgramGenerator(
    programId: 'rambam_1_chapter',
    compute: (d) {
      final idx =
          _cyclicIndex(d, DateTime.utc(2024, 6, 22), rambam1ChapterSequence.length);
      return rambam1ChapterSequence[idx];
    },
  ),
  // 5. Rambam 3 Chapters — 339 days, anchor 2025-03-05.
  _ProgramGenerator(
    programId: 'rambam_3_chapters',
    compute: (d) {
      final idx =
          _cyclicIndex(d, DateTime.utc(2025, 3, 5), rambam3ChaptersSequence.length);
      return rambam3ChaptersSequence[idx];
    },
  ),
  // 6. Halakhah Yomit — 1,613 days, anchor 2020-11-12.
  _ProgramGenerator(
    programId: 'halakhah_yomit',
    compute: (d) {
      final idx =
          _cyclicIndex(d, DateTime.utc(2020, 11, 12), halakhahYomitSequence.length);
      return halakhahYomitSequence[idx];
    },
  ),
  // 7. Arukh HaShulchan Yomi — 1,719 days, anchor 2020-05-29.
  _ProgramGenerator(
    programId: 'arukh_hashulchan_yomi',
    compute: (d) {
      final idx =
          _cyclicIndex(d, DateTime.utc(2020, 5, 29), arukhHaShulchanSequence.length);
      return arukhHaShulchanSequence[idx];
    },
  ),
  // 8. Nach Yomi — 742 days, anchor 2007-11-01.
  _ProgramGenerator(
    programId: 'nach_yomi',
    compute: (d) {
      final idx =
          _cyclicIndex(d, DateTime.utc(2007, 11, 1), nachYomiSequence.length);
      return nachYomiSequence[idx];
    },
  ),
  // 9. Yerushalmi Yomi — 1,563 days, anchor 2022-11-14.
  _ProgramGenerator(
    programId: 'yerushalmi_yomi',
    compute: (d) {
      final idx =
          _cyclicIndex(d, DateTime.utc(2022, 11, 14), yerushalmiyomiSequence.length);
      return yerushalmiyomiSequence[idx];
    },
  ),
  // 10. Tanakh Yomi — pre-computed lookup (2021–2099).
  _ProgramGenerator(
    programId: 'tanakh_yomi',
    compute: (d) {
      final key = LocalCalendarEngine.formatDateKey(d);
      final entry = tanakhYomiData[key];
      if (entry == null || entry.length < 2) return null;
      return entry[1]; // [sederName, ref]
    },
  ),
  // 11. Chofetz Chaim — approximate using regular-year table.
  //     Entry format: [dates_list, section, begin, end, textBegin?, textEnd?]
  _ProgramGenerator(
    programId: 'chofetz_chaim_daily',
    compute: (d) {
      const table = chofetzChaimSimple;
      final dayOfYear = d.difference(DateTime.utc(d.year, 1, 1)).inDays;
      final idx = dayOfYear % table.length;
      final entry = table[idx];
      if (entry.length < 4) return null;
      final section = entry[1] as String;
      final begin = entry[2] as String;
      final end = entry[3] as String;
      final name = chofetzChaimSections[section] ?? section;
      if (begin == end) return 'Chofetz Chaim, $name $begin';
      return 'Chofetz Chaim, $name $begin-$end';
    },
  ),
  // 12. Kitzur Shulchan Aruch Yomi — cyclic approximation.
  _ProgramGenerator(
    programId: 'kitzur_shulchan_aruch_yomi',
    compute: (d) {
      final allEntries = <String>[];
      for (final month in [
        'Tishrei', 'Cheshvan', 'Kislev', 'Tevet', 'Shvat', 'Adar',
        'Nisan', 'Iyyar', 'Sivan', 'Tamuz', 'Av', 'Elul',
      ]) {
        allEntries.addAll(kitzurShulchanAruchTable[month] ?? []);
      }
      if (allEntries.isEmpty) return null;
      final tishrei1 =
          DateTime.utc(d.year - (d.month < 9 ? 1 : 0), 9, 16);
      final idx = (d.toUtc().difference(tishrei1).inDays % allEntries.length +
              allEntries.length) %
          allEntries.length;
      final reading = allEntries[idx];
      if (reading.isEmpty) return null;
      return 'Kitzur Shulchan Aruch $reading';
    },
  ),
];
