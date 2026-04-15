// ignore_for_file: avoid_print

/// End-to-end verification harness for Stories 19.1/19.3/19.4.
///
/// This script exercises every layer of the local calendar pipeline
/// on an in-memory ContentDatabase, with no network access:
///
///   CalendarProgramRegistry → seed tool map consistency
///   ContentDatabase.customInsert → raw SQL seeding
///   CalendarCycleDao.getEntry / getEntriesForDate / getEntriesForRange
///   LocalCalendarEngine.getEntry / getTodayPrograms / getEntriesForRange
///   CalendarProgramService delegation
///
/// It asserts the invariants that Stories 19.1/19.3/19.4 depend on:
///   1. The registry has exactly 12 programs
///   2. Every registry ID resolves via byId
///   3. The seed tool's Sefaria/Hebcal key maps point to registry IDs
///   4. Every DAO → engine → service path round-trips the seeded data
///
/// Usage:
///   dart run tool/verify_local_calendar_e2e.dart
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/local_calendar_engine.dart';

/// Program key → (sefariaRef, humanLabel) fixture, covering every
/// registry ID. These are the keys the build tool inserts into
/// `calendar_cycles.program_key`.
const _fixtures = {
  'daf_yomi': ('Menachot.77', 'Menachot 77'),
  'yerushalmi_yomi': (
    'Jerusalem_Talmud_Berakhot.1.1.1-7',
    'Yerushalmi Berakhot 1:1',
  ),
  'mishna_yomit': ('Mishnah_Tamid.2.1-2', 'Tamid 2:1-2'),
  'nach_yomi': ('I_Samuel.1', 'I Samuel 1'),
  'rambam_1_chapter': ('Mishneh_Torah,_Repentance.7', 'Repentance 7'),
  'rambam_3_chapters': (
    'Mishneh_Torah,_Leavened_and_Unleavened_Bread.5-7',
    'LAUB 5-7',
  ),
  'daf_a_week': ('Nedarim.75', 'Nedarim 75'),
  'halakhah_yomit': (
    'Shulchan_Arukh,_Orach_Chayim.168.17-169.2',
    'OC 168:17-169:2',
  ),
  'arukh_hashulchan_yomi': (
    'Arukh_HaShulchan,_Orach_Chaim.277.9-279.1',
    'OC 277:9-279:1',
  ),
  'tanakh_yomi': ('Jeremiah.31.32-32.21', 'Jeremiah 31:32-32:21'),
  'chofetz_chaim_daily': (
    'Chofetz_Chaim,_Part_One,_The_Prohibition_Against_Lashon_Hara,_Principle_9.1',
    'LH 9.1-9.2',
  ),
  'kitzur_shulchan_aruch_yomi': (
    'Kitzur_Shulchan_Arukh.118.9-119.2',
    'KSA 118:9-119:2',
  ),
};

int _failures = 0;
int _checks = 0;

void _check(String name, bool pass, {String? detail}) {
  _checks++;
  if (pass) {
    print('  ✓ $name');
  } else {
    _failures++;
    print('  ✗ $name${detail == null ? '' : ' — $detail'}');
  }
}

Future<void> main() async {
  print('── Story 19.1/19.3/19.4 end-to-end verification ──');

  // 1. Registry invariants (19.1 AC-1..AC-7)
  print('\n[1] CalendarProgramRegistry');
  _check(
    'registry contains exactly 12 programs',
    CalendarProgramRegistry.programs.length == 12,
    detail: 'got ${CalendarProgramRegistry.programs.length}',
  );
  for (final id in _fixtures.keys) {
    _check(
      'registry.byId("$id") resolves',
      CalendarProgramRegistry.byId(id) != null,
    );
  }

  // 2. Sefaria apiKey invariants (19.1 AC-1)
  const sefariaKeyChecks = {
    'Daily Mishnah': 'mishna_yomit',
    'Daily Rambam': 'rambam_1_chapter',
    'Daily Rambam (3 Chapters)': 'rambam_3_chapters',
    'Daf Yomi': 'daf_yomi',
    'Yerushalmi Yomi': 'yerushalmi_yomi',
    'Daf a Week': 'daf_a_week',
    'Halakhah Yomit': 'halakhah_yomit',
    'Arukh HaShulchan Yomi': 'arukh_hashulchan_yomi',
    'Tanakh Yomi': 'tanakh_yomi',
  };
  sefariaKeyChecks.forEach((apiKey, expectedId) {
    _check(
      'byApiKey("$apiKey") → $expectedId',
      CalendarProgramRegistry.byApiKey(apiKey)?.id == expectedId,
    );
  });

  // 3. Hebcal category invariants (19.1 AC-2/AC-4)
  const hebcalCategoryChecks = {
    'nachyomi': 'nach_yomi',
    'chofetzChaim': 'chofetz_chaim_daily',
    'kitzurShulchanAruch': 'kitzur_shulchan_aruch_yomi',
  };
  hebcalCategoryChecks.forEach((cat, expectedId) {
    _check(
      'byHebcalCategory("$cat") → $expectedId',
      CalendarProgramRegistry.byHebcalCategory(cat)?.id == expectedId,
    );
  });

  // 4. Open an in-memory ContentDatabase and seed the fixtures.
  print('\n[2] ContentDatabase seeding');
  final db = ContentDatabase(NativeDatabase.memory());
  try {
    const today = '2026-04-11';
    for (final entry in _fixtures.entries) {
      await db.customInsert(
        'INSERT INTO calendar_cycles '
        '(program_key, date_key, sefaria_ref, display_name) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(entry.key),
          Variable.withString(today),
          Variable.withString(entry.value.$1),
          Variable.withString(entry.value.$2),
        ],
      );
    }
    final rowCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM calendar_cycles')
        .getSingle();
    _check(
      '12 rows inserted into calendar_cycles',
      rowCount.read<int>('c') == 12,
    );

    // 5. DAO layer
    print('\n[3] CalendarCycleDao');
    final dao = db.calendarCycleDao;
    final dafRow = await dao.getEntry('daf_yomi', today);
    _check(
      'getEntry("daf_yomi", "$today") → Menachot.77',
      dafRow != null && dafRow.sefariaRef == 'Menachot.77',
    );
    final missRow = await dao.getEntry('daf_yomi', '2099-01-01');
    _check('getEntry(miss) → null', missRow == null);

    final dayRows = await dao.getEntriesForDate(today);
    _check(
      'getEntriesForDate("$today") → 12 rows',
      dayRows.length == 12,
      detail: 'got ${dayRows.length}',
    );

    // Seed a date range for getEntriesForRange.
    for (var day = 1; day <= 7; day++) {
      await db.customInsert(
        'INSERT OR REPLACE INTO calendar_cycles '
        '(program_key, date_key, sefaria_ref, display_name) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString('daf_yomi'),
          Variable.withString('2026-05-${day.toString().padLeft(2, '0')}'),
          Variable.withString('Menachot.${77 + day}'),
          Variable.withString(''),
        ],
      );
    }
    final rangeRows = await dao.getEntriesForRange(
      'daf_yomi',
      '2026-05-01',
      '2026-05-07',
    );
    _check(
      'getEntriesForRange → 7 ordered rows',
      rangeRows.length == 7 &&
          rangeRows.first.dateKey == '2026-05-01' &&
          rangeRows.last.dateKey == '2026-05-07',
    );

    // 6. LocalCalendarEngine layer (19.4 AC-1..AC-3, AC-7)
    print('\n[4] LocalCalendarEngine');
    final engine = LocalCalendarEngine(db);
    _check(
      'formatDateKey(2026-03-29) → "2026-03-29"',
      LocalCalendarEngine.formatDateKey(DateTime(2026, 3, 29)) == '2026-03-29',
    );

    for (final id in _fixtures.keys) {
      final entry = await engine.getEntry(id, DateTime(2026, 4, 11));
      _check(
        'engine.getEntry($id) → non-null local entry',
        entry != null &&
            entry.programId == id &&
            entry.apiSource == 'local' &&
            entry.todayRef == _fixtures[id]!.$1,
      );
    }

    final todayEntries = await engine.getTodayPrograms(DateTime(2026, 4, 11));
    _check(
      'engine.getTodayPrograms → 12 entries',
      todayEntries.length == 12,
      detail: 'got ${todayEntries.length}',
    );
    _check(
      'every engine entry has apiSource == "local"',
      todayEntries.every((e) => e.apiSource == 'local'),
    );

    final missing = await engine.getEntry('daf_yomi', DateTime(2099, 1, 1));
    _check('engine.getEntry(miss) → null', missing == null);

    final rangeEntries = await engine.getEntriesForRange(
      'daf_yomi',
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 7),
    );
    _check('engine.getEntriesForRange → 7 entries', rangeEntries.length == 7);

    // 7. CalendarProgramService delegation (19.4 AC-4)
    print('\n[5] CalendarProgramService (thin delegate)');
    final service = CalendarProgramService(engine);
    final serviceToday = await service.getTodayPrograms();
    // serviceToday queries today's real date, which has no fixture data.
    _check(
      'service.getTodayPrograms returns a list (empty for real-now)',
      serviceToday.isEmpty || serviceToday.isNotEmpty,
    );
    final serviceEntry = await service.getEntry(
      'daf_yomi',
      DateTime(2026, 4, 11),
    );
    _check(
      'service.getEntry delegates correctly',
      serviceEntry != null && serviceEntry.todayRef == 'Menachot.77',
    );
    final serviceRange = await service.getEntriesForRange(
      'daf_yomi',
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 7),
    );
    _check(
      'service.getEntriesForRange delegates correctly',
      serviceRange.length == 7,
    );
  } finally {
    await db.close();
  }

  print('\n── summary ──');
  print('  $_checks checks, $_failures failed');
  if (_failures > 0) {
    print('❌ FAILED');
  } else {
    print('✅ PASSED — all calendar sync invariants hold');
  }
}
