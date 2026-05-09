// Comprehensive validator for the bundled content.db seed.
//
// Validates two invariants against every (program, date) pair from
// 2024-01-01 through 2032-12-31:
//
//   1. Coverage — every entry the source-of-truth cache contains
//      (`tool/data/hebcal_calendar_cache.json` for hebcal-sourced programs;
//      `tool/data/sefaria_calendar_cache.json` for `halakhah_yomit`) must
//      appear in the seed DB's `calendar_cycles` table. Mirrors the rules in
//      `tool/seed_content_db.dart` so we catch any drift between source and
//      seed without re-implementing schedule semantics (Yom Tov, Shabbos,
//      cycle-end gaps, etc.).
//
//   2. Ref resolution — every `sefaria_ref` written into `calendar_cycles`
//      must resolve to a row in `text_cache` or `daily_content`, so the
//      in-app text viewer can render bundled text without a network call.
//
// Exits 0 when both invariants hold. Exits 1 with a punch list of the first
// `--max-issues` problems otherwise.
//
// Run from learning_tracker/:
//   dart run tool/validate_seed_coverage.dart
//   dart run tool/validate_seed_coverage.dart --db=path/to/content.db
//   dart run tool/validate_seed_coverage.dart --max-issues=50
//
// Wired into `make ci` via `make validate-calendar`.

import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const String _gzAsset = 'assets/db/content.db.gz';
const String _xzAsset = 'assets/db/content.db.xz';
const String _hebcalCachePath = 'tool/data/hebcal_calendar_cache.json';
const String _sefariaCachePath = 'tool/data/sefaria_calendar_cache.json';

const String _coverageStart = '2024-01-01';
const String _coverageEnd = '2032-12-31';

/// Mirrors `tool/seed_content_db.dart`'s `_calendarGens` list. Each entry
/// names a program in the seed DB and the cache key its source data lives
/// under. Dirshu Kinyan programs shadow daf_yomi / yerushalmi_yomi cycles.
const Map<String, _Source> _programSources = {
  'daf_yomi': _Source(_SrcKind.hebcal, 'daf_yomi'),
  'daf_a_week': _Source(_SrcKind.hebcal, 'daf_a_week'),
  'mishna_yomit': _Source(_SrcKind.hebcal, 'mishna_yomit'),
  'rambam_1_chapter': _Source(_SrcKind.hebcal, 'rambam_1_chapter'),
  'rambam_3_chapters': _Source(_SrcKind.hebcal, 'rambam_3_chapters'),
  'arukh_hashulchan_yomi': _Source(_SrcKind.hebcal, 'arukh_hashulchan_yomi'),
  'nach_yomi': _Source(_SrcKind.hebcal, 'nach_yomi'),
  'yerushalmi_yomi': _Source(_SrcKind.hebcal, 'yerushalmi_yomi'),
  'tanakh_yomi': _Source(_SrcKind.hebcal, 'tanakh_yomi'),
  'chofetz_chaim_daily': _Source(_SrcKind.hebcal, 'chofetz_chaim_daily'),
  'kitzur_shulchan_aruch_yomi': _Source(
    _SrcKind.hebcal,
    'kitzur_shulchan_aruch_yomi',
  ),
  'dirshu_amud_hayomi': _Source(_SrcKind.hebcal, 'dirshu_amud_hayomi'),
  'dirshu_kinyan_torah': _Source(_SrcKind.hebcal, 'daf_yomi'),
  'dirshu_kinyan_yerushalmi': _Source(_SrcKind.hebcal, 'yerushalmi_yomi'),
  'tehillim_yomi': _Source(_SrcKind.hebcal, 'tehillim_yomi'),
  'perek_yomi': _Source(_SrcKind.hebcal, 'perek_yomi'),
  'sefer_hamitzvot': _Source(_SrcKind.hebcal, 'sefer_hamitzvot'),
  'shemirat_halashon': _Source(_SrcKind.hebcal, 'shemirat_halashon'),
  'pirkei_avot_summer': _Source(_SrcKind.hebcal, 'pirkei_avot_summer'),
  // Sefaria-only program. Note: seed_content_db falls back to a local
  // halakhahYomitSequence when sefaria cache misses a date — we leave
  // those days unvalidated rather than re-implement the fallback here.
  'halakhah_yomit': _Source(_SrcKind.sefaria, 'halakhah_yomit'),
};

enum _SrcKind { hebcal, sefaria }

class _Source {
  const _Source(this.kind, this.cacheKey);
  final _SrcKind kind;
  final String cacheKey;
}

class _MissingRow {
  _MissingRow(this.programKey, this.dateKey, this.expectedRef);
  final String programKey;
  final String dateKey;
  final String expectedRef;
}

class _MismatchRow {
  _MismatchRow(this.programKey, this.dateKey, this.expectedRef, this.actualRef);
  final String programKey;
  final String dateKey;
  final String expectedRef;
  final String actualRef;
}

class _ExtraRow {
  _ExtraRow(this.programKey, this.dateKey, this.actualRef);
  final String programKey;
  final String dateKey;
  final String actualRef;
}

class _BrokenRefRow {
  _BrokenRefRow(this.programKey, this.dateKey, this.sefariaRef);
  final String programKey;
  final String dateKey;
  final String sefariaRef;
}

Future<int> main(List<String> args) async {
  String? dbOverride;
  var maxIssues = 25;
  for (final a in args) {
    if (a.startsWith('--db=')) {
      dbOverride = a.substring(5);
    } else if (a.startsWith('--max-issues=')) {
      maxIssues = int.parse(a.substring(13));
    } else {
      stderr.writeln('Unknown flag: $a');
      return 2;
    }
  }

  final hebcal = _loadCache(_hebcalCachePath);
  final sefaria = _loadCache(_sefariaCachePath);
  stdout.writeln(
    'Loaded source-of-truth caches: '
    'hebcal=${hebcal.length} dates, sefaria=${sefaria.length} dates',
  );

  final dbPath = dbOverride ?? await _ensureDecompressedSeed();
  stdout.writeln('Validating: $dbPath');

  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  try {
    _summary(db);

    // Build expected-set per program from the cache files, mirroring
    // `_calendarGens` in tool/seed_content_db.dart.
    final expected = <String, Map<String, String>>{};
    var cursor = DateTime.parse(_coverageStart);
    final end = DateTime.parse(_coverageEnd);
    while (!cursor.isAfter(end)) {
      final dk = _dateKey(cursor);
      for (final entry in _programSources.entries) {
        final src = entry.value;
        final cache = src.kind == _SrcKind.hebcal ? hebcal : sefaria;
        final ref = cache[dk]?[src.cacheKey];
        if (ref == null) continue;
        expected.putIfAbsent(entry.key, () => <String, String>{})[dk] = ref;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    // Pull every actual seed row in one query.
    final actual = <String, Map<String, String>>{};
    final rows = db.select(
      'SELECT program_key, date_key, sefaria_ref FROM calendar_cycles '
      'WHERE date_key BETWEEN ? AND ?',
      [_coverageStart, _coverageEnd],
    );
    for (final row in rows) {
      final pk = row['program_key'] as String;
      final dk = row['date_key'] as String;
      final ref = row['sefaria_ref'] as String;
      actual.putIfAbsent(pk, () => <String, String>{})[dk] = ref;
    }

    // Diff against expected.
    final missing = <_MissingRow>[];
    final mismatched = <_MismatchRow>[];
    final extras = <_ExtraRow>[];

    for (final pk in expected.keys) {
      final expRows = expected[pk]!;
      final actRows = actual[pk] ?? const <String, String>{};
      for (final mapEntry in expRows.entries) {
        final dk = mapEntry.key;
        final expRef = mapEntry.value;
        final actRef = actRows[dk];
        if (actRef == null) {
          missing.add(_MissingRow(pk, dk, expRef));
        } else if (actRef != expRef) {
          mismatched.add(_MismatchRow(pk, dk, expRef, actRef));
        }
      }
    }
    for (final pk in actual.keys) {
      final actRows = actual[pk]!;
      final expRows = expected[pk] ?? const <String, String>{};
      for (final mapEntry in actRows.entries) {
        final dk = mapEntry.key;
        // halakhah_yomit may have rows the sefaria cache doesn't cover
        // (local-sequence fallback in seed_content_db). Skip extras for it.
        if (pk == 'halakhah_yomit') continue;
        // Programs not in our source map are unexpected — flag them so we
        // notice if a new program was seeded without being added here.
        if (!_programSources.containsKey(pk)) {
          extras.add(_ExtraRow(pk, dk, mapEntry.value));
          continue;
        }
        if (!expRows.containsKey(dk)) {
          extras.add(_ExtraRow(pk, dk, mapEntry.value));
        }
      }
    }

    // Validate ref resolution for every actual row.
    final brokenRefs = _findBrokenRefs(db);

    // Today-must-be-present sanity for daily programs.
    final today = _dateKey(DateTime.now());
    final todayMissing = <String>[];
    if (today.compareTo(_coverageStart) >= 0 &&
        today.compareTo(_coverageEnd) <= 0) {
      for (final pk in _programSources.keys) {
        final exp = expected[pk]?[today];
        if (exp == null) continue; // legitimate gap (e.g. Shabbos)
        if ((actual[pk] ?? const {})[today] == null) {
          todayMissing.add(pk);
        }
      }
    }

    final issues =
        missing.length +
        mismatched.length +
        extras.length +
        brokenRefs.length +
        todayMissing.length;
    if (issues == 0) {
      stdout.writeln(
        '\nOK: ${expected.values.fold<int>(0, (a, m) => a + m.length)} '
        'expected (program, date) pairs all present, every ref resolves, '
        'today ($today) covered for every active program.',
      );
      return 0;
    }

    stdout.writeln('\n$issues issues found.');
    if (todayMissing.isNotEmpty) {
      stdout.writeln(
        '\nToday ($today) missing for ${todayMissing.length} program(s):',
      );
      for (final pk in todayMissing) {
        stdout.writeln('  $pk');
      }
    }
    if (missing.isNotEmpty) {
      stdout.writeln('\nMissing entries (${missing.length}):');
      for (final r in missing.take(maxIssues)) {
        stdout.writeln(
          '  ${r.programKey.padRight(28)} ${r.dateKey}  '
          'expected ref="${r.expectedRef}"',
        );
      }
      if (missing.length > maxIssues) {
        stdout.writeln('  … ${missing.length - maxIssues} more');
      }
    }
    if (mismatched.isNotEmpty) {
      stdout.writeln('\nMismatched refs (${mismatched.length}):');
      for (final r in mismatched.take(maxIssues)) {
        stdout.writeln(
          '  ${r.programKey.padRight(28)} ${r.dateKey}\n'
          '    expected: ${r.expectedRef}\n'
          '    actual:   ${r.actualRef}',
        );
      }
      if (mismatched.length > maxIssues) {
        stdout.writeln('  … ${mismatched.length - maxIssues} more');
      }
    }
    if (extras.isNotEmpty) {
      stdout.writeln('\nUnexpected extras (${extras.length}):');
      for (final r in extras.take(maxIssues)) {
        stdout.writeln(
          '  ${r.programKey.padRight(28)} ${r.dateKey}  '
          'ref="${r.actualRef}"',
        );
      }
      if (extras.length > maxIssues) {
        stdout.writeln('  … ${extras.length - maxIssues} more');
      }
    }
    if (brokenRefs.isNotEmpty) {
      stdout.writeln('\nUnresolved refs (${brokenRefs.length}):');
      for (final r in brokenRefs.take(maxIssues)) {
        stdout.writeln(
          '  ${r.programKey.padRight(28)} ${r.dateKey}  '
          'sefaria_ref="${r.sefariaRef}"',
        );
      }
      if (brokenRefs.length > maxIssues) {
        stdout.writeln('  … ${brokenRefs.length - maxIssues} more');
      }
    }
    return 1;
  } finally {
    db.dispose();
  }
}

Map<String, Map<String, String>> _loadCache(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Cache missing: $path');
    exit(2);
  }
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  // Cache shape: { 'YYYY-MM-DD': { programKey: {'en': 'Berakhot 2a', 'he': '...'} } }
  final out = <String, Map<String, String>>{};
  for (final dateEntry in raw.entries) {
    final inner = dateEntry.value as Map<String, dynamic>;
    final perProgram = <String, String>{};
    for (final progEntry in inner.entries) {
      final m = progEntry.value as Map<String, dynamic>;
      final en = m['en'] as String?;
      if (en == null) continue;
      perProgram[progEntry.key] = en;
    }
    out[dateEntry.key] = perProgram;
  }
  return out;
}

List<_BrokenRefRow> _findBrokenRefs(Database db) {
  final rows = db.select('''
    SELECT cc.program_key, cc.date_key, cc.sefaria_ref
    FROM calendar_cycles cc
    LEFT JOIN text_cache tc ON tc.sefaria_ref = cc.sefaria_ref
    LEFT JOIN daily_content dc ON dc.sefaria_ref = cc.sefaria_ref
    WHERE tc.sefaria_ref IS NULL AND dc.sefaria_ref IS NULL
    ORDER BY cc.program_key, cc.date_key
  ''');
  return [
    for (final row in rows)
      _BrokenRefRow(
        row['program_key'] as String,
        row['date_key'] as String,
        row['sefaria_ref'] as String,
      ),
  ];
}

void _summary(Database db) {
  final cyc =
      db.select('SELECT COUNT(*) AS c FROM calendar_cycles').first['c'] as int;
  final tc =
      db.select('SELECT COUNT(*) AS c FROM text_cache').first['c'] as int;
  final dc =
      db.select('SELECT COUNT(*) AS c FROM daily_content').first['c'] as int;
  final perProgram = db.select('''
    SELECT program_key, COUNT(*) AS c, MIN(date_key) AS lo, MAX(date_key) AS hi
    FROM calendar_cycles
    GROUP BY program_key
    ORDER BY program_key
  ''');
  stdout.writeln('Seed inventory:');
  stdout.writeln('  calendar_cycles: $cyc');
  stdout.writeln('  text_cache:      $tc');
  stdout.writeln('  daily_content:   $dc');
  stdout.writeln('Coverage per program (program × range × rows):');
  for (final r in perProgram) {
    stdout.writeln(
      '  ${(r['program_key'] as String).padRight(28)} '
      '${r['lo']} → ${r['hi']}  ${r['c']} rows',
    );
  }
}

Future<String> _ensureDecompressedSeed() async {
  final tmpDir = Directory.systemTemp.createTempSync('lt_seed_validate_');
  final dbPath = '${tmpDir.path}/content.db';

  if (File(_xzAsset).existsSync()) {
    final p = Process.runSync('xz', ['-dc', _xzAsset], stdoutEncoding: null);
    if (p.exitCode != 0) {
      stderr.writeln('xz failed: ${p.stderr}');
      exit(2);
    }
    await File(dbPath).writeAsBytes(p.stdout as List<int>);
    return dbPath;
  }
  if (File(_gzAsset).existsSync()) {
    final p = Process.runSync('gunzip', ['-c', _gzAsset], stdoutEncoding: null);
    if (p.exitCode != 0) {
      stderr.writeln('gunzip failed: ${p.stderr}');
      exit(2);
    }
    await File(dbPath).writeAsBytes(p.stdout as List<int>);
    return dbPath;
  }
  stderr.writeln('No seed asset found ($_xzAsset or $_gzAsset).');
  exit(2);
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
