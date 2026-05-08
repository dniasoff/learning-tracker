// ignore_for_file: avoid_print

/// CLI tool to build the pre-built Content DB shipped in the APK.
///
/// Usage:
///   dart run tool/seed_content_db.dart [flags]
///
/// Flags:
///   --build              Full build (default)
///   --validate-only      Open existing seed.db, verify schema + row counts
///   --text-only          Run only the text-fetch phase
///   --calendar-only      Run only the calendar-fetch phase
///   --programs-only      Run only programs + test-dates phase
///   --curriculum <name>  Restrict text-fetch phase to one curriculum
///   --resume / --no-resume  Resume from existing rows (default: on)
///   --output <path>      Output directory (default: build/)
///   --seed-version <n>   Override bundled seed version
///   --verbose            Extra logging
///   --size-report        Print per-table size breakdown after build
///
/// Produces:
///   build/seed.db           uncompressed SQLite database
///   build/seed.db.gz        gzip-compressed DB for bundling
///   build/seed_version.json sidecar (version / buildDate / contentHash)
///   assets/db/content.db.gz  copy placed in the Flutter asset bundle
///
/// Story 19.3 — "Seed Database Build Tool".
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_version.dart';

import 'lib/sequences/halakhah_yomit_seq.dart';

// ── Configuration ────────────────────────────────────────────────────────

// Learning programs and test dates are computed at runtime.
// Calendar cycles are generated locally (no APIs) and stored in the DB.

/// Date range for calendar cycles (inclusive).
final _calendarStart = DateTime.utc(2024, 1, 1);
final _calendarEnd = DateTime.utc(2032, 12, 31);

// ── CLI entry point ──────────────────────────────────────────────────────

class _Args {
  _Args({
    required this.mode,
    required this.curriculum,
    required this.resume,
    required this.output,
    required this.seedVersion,
    required this.verbose,
    required this.sizeReport,
  });

  final _Mode mode;
  final String? curriculum;
  final bool resume;
  final String output;
  final int seedVersion;
  final bool verbose;
  final bool sizeReport;
}

enum _Mode { build, validateOnly, textOnly }

_Args _parseArgs(List<String> args) {
  var mode = _Mode.build;
  String? curriculum;
  var resume = true;
  var output = 'build';
  var seedVersion = bundledSeedVersion;
  var verbose = false;
  var sizeReport = false;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    switch (a) {
      case '--build':
        mode = _Mode.build;
      case '--validate-only':
        mode = _Mode.validateOnly;
      case '--text-only':
        mode = _Mode.textOnly;
      case '--calendar-only':
        print('Warning: --calendar-only is deprecated');
      case '--programs-only':
        print('Warning: --programs-only is deprecated');
      case '--curriculum':
        curriculum = args[++i];
      case '--resume':
        resume = true;
      case '--no-resume':
        resume = false;
      case '--output':
        output = args[++i];
      case '--seed-version':
        seedVersion = int.parse(args[++i]);
      case '--verbose':
        verbose = true;
      case '--size-report':
        sizeReport = true;
      default:
        stderr.writeln('Unknown flag: $a');
        exit(2);
    }
  }
  return _Args(
    mode: mode,
    curriculum: curriculum,
    resume: resume,
    output: output,
    seedVersion: seedVersion,
    verbose: verbose,
    sizeReport: sizeReport,
  );
}

Future<void> main(List<String> rawArgs) async {
  final args = _parseArgs(rawArgs);

  print('🌱 Seed Content DB Builder');
  print('  Mode:       ${args.mode.name}');
  print('  Version:    ${args.seedVersion}');
  print('  Output:     ${args.output}');
  print('');

  final buildDir = Directory(args.output);
  if (!buildDir.existsSync()) {
    buildDir.createSync(recursive: true);
  }

  final dbPath = '${args.output}/seed.db';
  final xzPath = '${args.output}/seed.db.xz';
  final sidecarPath = '${args.output}/seed_version.json';
  const assetPath = 'assets/db/content.db.xz';

  if (args.mode == _Mode.validateOnly) {
    await _validateExisting(dbPath, args);
    return;
  }

  // Open (or create) the seed DB using the Drift schema so downstream
  // reads match the runtime ContentDatabase byte-for-byte.
  final dbFile = File(dbPath);
  if (!args.resume && dbFile.existsSync()) {
    print('  Deleting existing $dbPath (--no-resume)');
    dbFile.deleteSync();
  }

  final db = ContentDatabase(NativeDatabase(dbFile));
  await db.customStatement('SELECT 1'); // Force onCreate / schema realisation.

  try {
    // Programs, test dates, and calendar cycles are now computed at
    // runtime — see LearningProgramRepository, generateTestDateSeeds(),
    // and LocalCalendarEngine.

    // Phase 3: Populate text_cache from book_text_cache.json (Sefaria-Project +
    // local Mongo, no API). The historical API-fetch path is retired; every
    // ref now comes through tool/text_extract/extract_books.py in canonical
    // Sefaria format. Wipes text_cache first to drop any stale rows from
    // older builds (different ref formats, or refs that have since been
    // dropped from a curriculum).
    var textCacheCount = 0;
    if (args.mode == _Mode.build || args.mode == _Mode.textOnly) {
      print('Phase 3: Loading text_cache from book_text_cache.json...');
      await db.customStatement('DELETE FROM text_cache');
      textCacheCount = await _mergeBookTextCache(db);
      print('  inserted $textCacheCount text_cache rows');
    } else {
      textCacheCount = await _countRows(db, 'text_cache');
    }

    // Phase 4: Calendar cycles (local computation, no APIs)
    var calendarCycleCount = 0;
    if (args.mode == _Mode.build) {
      print('Phase 4: Generating calendar cycles locally...');
      calendarCycleCount = await _generateCalendarCycles(db);
    } else {
      calendarCycleCount = await _countRows(db, 'calendar_cycles');
    }

    // Phase 4b: Populate daily_content from extracted JSON cache.
    // Pre-resolved bilingual text per calendar ref, no API calls — built
    // from tool/text_extract/main.py (Sefaria-Project + local Mongo).
    if (args.mode == _Mode.build) {
      print('Phase 4b: Populating daily_content from extractor cache...');
      final dcCount = await _populateDailyContent(db);
      print('  daily_content rows: $dcCount');
    }

    // Phase 4c: Cross-reference validator — every calendar entry must
    // resolve to a daily_content row. Anything else means the seed would
    // ship a 'Failed to load' state for that program/day.
    if (args.mode == _Mode.build) {
      print('Phase 4c: Cross-referencing calendar_cycles → daily_content...');
      final unresolved = await db
          .customSelect(
            'SELECT c.program_key, c.date_key, c.sefaria_ref '
            'FROM calendar_cycles c '
            'LEFT JOIN daily_content d ON c.sefaria_ref = d.sefaria_ref '
            'WHERE d.sefaria_ref IS NULL '
            'LIMIT 50',
          )
          .get();
      if (unresolved.isNotEmpty) {
        print(
          '  ❌ ${unresolved.length} unresolved entries (showing up to 50):',
        );
        for (final row in unresolved) {
          print(
            '    ${row.read<String>('program_key')}  '
            '${row.read<String>('date_key')}  '
            '${row.read<String>('sefaria_ref')}',
          );
        }
        throw StateError(
          'Build aborted: calendar entries reference refs not in daily_content',
        );
      }
      print('  ✓ all calendar entries resolve');
    }

    // Phase 4d: Curriculum-completeness validator — every leaf ref in every
    // hierarchy.json must exist in text_cache. Locks in 100% curriculum
    // coverage so a future build can't silently regress.
    if (args.mode == _Mode.build) {
      print('Phase 4d: Verifying curriculum hierarchies in text_cache...');
      final hierarchyDir = Directory('assets/content/hierarchy');
      var totalLeaves = 0;
      final missingByCurriculum = <String, List<String>>{};
      for (final f in hierarchyDir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final items = raw['items'] as List<dynamic>;
        final leaves = <String>[];
        for (final it in items.cast<Map<String, dynamic>>()) {
          if (it['isLeaf'] == true && it['sefariaRef'] is String) {
            leaves.add(it['sefariaRef'] as String);
          }
        }
        totalLeaves += leaves.length;
        final name = f.uri.pathSegments.last.replaceAll('.json', '');
        final missing = <String>[];
        for (final ref in leaves) {
          final hit = await db
              .customSelect(
                'SELECT 1 FROM text_cache WHERE sefaria_ref = ? LIMIT 1',
                variables: [Variable.withString(ref)],
              )
              .getSingleOrNull();
          if (hit == null) missing.add(ref);
        }
        if (missing.isNotEmpty) missingByCurriculum[name] = missing;
      }
      if (missingByCurriculum.isNotEmpty) {
        print('  ❌ curriculum gaps:');
        for (final entry in missingByCurriculum.entries) {
          final sample = entry.value.take(5).join(', ');
          final more = entry.value.length > 5
              ? ' …and ${entry.value.length - 5} more'
              : '';
          print(
            '    ${entry.key}: ${entry.value.length} missing ($sample$more)',
          );
        }
        throw StateError(
          'Build aborted: curriculum hierarchies reference refs not in text_cache',
        );
      }
      print('  ✓ all $totalLeaves curriculum leaves resolve');
    }

    // Phase 5: Finalize
    if (args.mode == _Mode.build || args.mode == _Mode.textOnly) {
      print('Phase 5: Finalizing (content hash, SeedMetadata)...');
    }
    final contentHash = await _computeContentHash(db);
    await _writeSeedMetadata(
      db,
      version: args.seedVersion,
      contentHash: contentHash,
      textCacheCount: textCacheCount,
      calendarCycleCount: calendarCycleCount,
    );

    await db.customStatement('VACUUM');
  } finally {
    await db.close();
  }

  // Compress + write sidecar + copy to asset path.
  // xz -9 --extreme reduces the seed by ~45% over gzip, keeping the asset
  // under GitHub's 100 MB hard limit. The runtime decompresses with
  // package:archive's XZDecoder (see SeedManager).
  print('Phase 6: Compressing seed.db → seed.db.xz (xz -9 --extreme)...');
  final uncompressed = File(dbPath).readAsBytesSync();
  // Remove any stale .xz from a prior run; xz refuses to overwrite by default.
  if (File(xzPath).existsSync()) {
    File(xzPath).deleteSync();
  }
  final xzResult = Process.runSync(
    'xz',
    ['-9', '--extreme', '-k', '-f', dbPath],
    stdoutEncoding: null,
    stderrEncoding: null,
  );
  if (xzResult.exitCode != 0) {
    throw StateError('xz failed: ${xzResult.stderr}');
  }
  // xz with -k writes alongside the input as <input>.xz; the file we want
  // is at xzPath already (it's `${dbPath}.xz`).
  final compressed = File(xzPath).readAsBytesSync();

  final assetDir = Directory('assets/db');
  if (!assetDir.existsSync()) {
    assetDir.createSync(recursive: true);
  }
  // Drop any leftover gzip asset so the bundle isn't double-shipping.
  final legacyGz = File('assets/db/content.db.gz');
  if (legacyGz.existsSync()) {
    legacyGz.deleteSync();
  }
  File(xzPath).copySync(assetPath);

  final contentHashForSidecar = await _computeContentHashFromFile(dbPath);
  final buildDate = DateTime.now().toUtc().toIso8601String();
  File(sidecarPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': args.seedVersion,
      'buildDate': buildDate,
      'contentHash': contentHashForSidecar,
      'minAppVersion': '1.0.0',
    }),
  );

  final uncompressedMb = uncompressed.length / 1024 / 1024;
  final compressedMb = compressed.length / 1024 / 1024;
  print('');
  print('✅ Seed DB built successfully!');
  print('  Uncompressed: ${uncompressedMb.toStringAsFixed(2)} MB');
  print('  Compressed:   ${compressedMb.toStringAsFixed(2)} MB');
  print(
    '  Ratio:        '
    '${(compressed.length / uncompressed.length * 100).toStringAsFixed(1)}%',
  );
  print('  Sidecar:      $sidecarPath');
  print('  Asset copy:   $assetPath');

  if (args.sizeReport) {
    _printSizeReport(dbPath);
  }
}

// ── Phase 4: Calendar cycles (pure local computation) ───────────────────

int _cyclicIndex(DateTime date, DateTime anchor, int length) {
  final days = date.toUtc().difference(anchor.toUtc()).inDays;
  return (days % length + length) % length;
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// (English ref, Hebrew ref) pair for a single program-day.
class _CalRef {
  const _CalRef({required this.en, this.he = ''});
  final String en;
  final String he;
}

/// Authoritative date→program→ref mapping from
/// [tool/data/hebcal_calendar_cache.json], populated by [tool/hebcal_fetch]
/// (Node + @hebcal/learning). Hebcal is the source of truth for every
/// calendar program except those it doesn't support (currently only
/// `halakhah_yomit`).
final _hebcalCache = _loadJsonRefCache(
  'tool/data/hebcal_calendar_cache.json',
  required: true,
);

/// Sefaria cache, kept only for `halakhah_yomit` (R' Ovadia Yosef's
/// daily-halacha cycle, which hebcal doesn't include). All other programs
/// read from the hebcal cache.
final _sefariaCache = _loadJsonRefCache(
  'tool/data/sefaria_calendar_cache.json',
  required: false,
);

Map<String, Map<String, _CalRef>> _loadJsonRefCache(
  String path, {
  required bool required,
}) {
  final f = File(path);
  if (!f.existsSync()) {
    if (required) {
      throw FileSystemException(
        'cache missing — run the matching fetcher',
        path,
      );
    }
    return const {};
  }
  final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final out = <String, Map<String, _CalRef>>{};
  for (final entry in raw.entries) {
    final inner = <String, _CalRef>{};
    for (final pe in (entry.value as Map<String, dynamic>).entries) {
      final v = pe.value as Map<String, dynamic>;
      final en = v['en'] as String?;
      if (en == null || en.isEmpty) continue;
      inner[pe.key] = _CalRef(en: en, he: v['he'] as String? ?? '');
    }
    out[entry.key] = inner;
  }
  return out;
}

_CalRef? _fromHebcal(DateTime d, String programKey) =>
    _hebcalCache[_fmtDate(d.toUtc())]?[programKey];

_CalRef? _fromSefaria(DateTime d, String programKey) =>
    _sefariaCache[_fmtDate(d.toUtc())]?[programKey];

_CalRef? _en(String? en) => en == null ? null : _CalRef(en: en);

/// All calendar program generators. Each `compute` returns a [_CalRef] (en +
/// optional he) or null to skip the day. Hebcal is the source of truth for
/// every program except `halakhah_yomit` (R' Ovadia Yosef's daily-halacha
/// cycle, which hebcal doesn't include — Sefaria + local sequence cover it).
///
/// `dirshu_kinyan_torah` shares the daf_yomi cycle and `dirshu_kinyan_yerushalmi`
/// shares the yerushalmi_yomi cycle — both read those rows out of the
/// hebcal cache directly.
final _calendarGens = <(String key, _CalRef? Function(DateTime) compute)>[
  ('daf_yomi', (d) => _fromHebcal(d, 'daf_yomi')),
  ('daf_a_week', (d) => _fromHebcal(d, 'daf_a_week')),
  ('mishna_yomit', (d) => _fromHebcal(d, 'mishna_yomit')),
  ('rambam_1_chapter', (d) => _fromHebcal(d, 'rambam_1_chapter')),
  ('rambam_3_chapters', (d) => _fromHebcal(d, 'rambam_3_chapters')),
  ('arukh_hashulchan_yomi', (d) => _fromHebcal(d, 'arukh_hashulchan_yomi')),
  ('nach_yomi', (d) => _fromHebcal(d, 'nach_yomi')),
  ('yerushalmi_yomi', (d) => _fromHebcal(d, 'yerushalmi_yomi')),
  ('tanakh_yomi', (d) => _fromHebcal(d, 'tanakh_yomi')),
  ('chofetz_chaim_daily', (d) => _fromHebcal(d, 'chofetz_chaim_daily')),
  (
    'kitzur_shulchan_aruch_yomi',
    (d) => _fromHebcal(d, 'kitzur_shulchan_aruch_yomi'),
  ),
  ('dirshu_amud_hayomi', (d) => _fromHebcal(d, 'dirshu_amud_hayomi')),
  ('dirshu_kinyan_torah', (d) => _fromHebcal(d, 'daf_yomi')),
  ('dirshu_kinyan_yerushalmi', (d) => _fromHebcal(d, 'yerushalmi_yomi')),
  // New programs (hebcal exposes them; Sefaria's /api/calendars doesn't).
  ('tehillim_yomi', (d) => _fromHebcal(d, 'tehillim_yomi')),
  ('perek_yomi', (d) => _fromHebcal(d, 'perek_yomi')),
  ('sefer_hamitzvot', (d) => _fromHebcal(d, 'sefer_hamitzvot')),
  ('shemirat_halashon', (d) => _fromHebcal(d, 'shemirat_halashon')),
  ('pirkei_avot_summer', (d) => _fromHebcal(d, 'pirkei_avot_summer')),
  // Sefaria-only program: hebcal doesn't expose this cycle.
  (
    'halakhah_yomit',
    (d) =>
        _fromSefaria(d, 'halakhah_yomit') ??
        _en(
          halakhahYomitSequence[_cyclicIndex(
            d,
            DateTime.utc(2020, 11, 12),
            halakhahYomitSequence.length,
          )],
        ),
  ),
];

Future<int> _generateCalendarCycles(ContentDatabase db) async {
  // Wipe stale rows from prior builds — under --resume the table accumulates
  // entries from older calendar sources (e.g. Sefaria API days the current
  // hebcal cache doesn't include). Without this delete, the SQL validator
  // surfaces phantom rows that point at refs daily_content never resolved.
  await db.customStatement('DELETE FROM calendar_cycles');
  await db.customStatement('DELETE FROM daily_content');

  final totalDays = _calendarEnd.difference(_calendarStart).inDays + 1;
  print(
    '    Generating $totalDays days × ${_calendarGens.length} programs locally...',
  );

  var inserted = 0;
  const batchSize = 100;

  for (var i = 0; i < totalDays; i += batchSize) {
    await db.transaction(() async {
      final end = (i + batchSize).clamp(0, totalDays);
      for (var j = i; j < end; j++) {
        final d = _calendarStart.add(Duration(days: j));
        final dateKey = _fmtDate(d);
        for (final (key, compute) in _calendarGens) {
          final ref = compute(d);
          if (ref == null) continue;
          await db.customInsert(
            'INSERT OR REPLACE INTO calendar_cycles '
            '(program_key, date_key, sefaria_ref, sefaria_ref_he, '
            'display_name) '
            'VALUES (?, ?, ?, ?, ?)',
            variables: [
              Variable.withString(key),
              Variable.withString(dateKey),
              Variable.withString(ref.en),
              Variable.withString(ref.he),
              const Variable(''),
            ],
          );
          inserted++;
        }
      }
    });
    if ((i + batchSize) % 500 < batchSize || i + batchSize >= totalDays) {
      print(
        '    Calendar: ${(i + batchSize).clamp(0, totalDays)}/$totalDays days',
      );
    }
  }
  print('    Total calendar rows inserted: $inserted');
  return _countRows(db, 'calendar_cycles');
}

// ── Phase 5: Finalize ────────────────────────────────────────────────────

Future<String> _computeContentHash(ContentDatabase db) async {
  final refs = await db
      .customSelect('SELECT sefaria_ref FROM text_cache ORDER BY sefaria_ref')
      .get();
  final buffer = StringBuffer();
  for (final r in refs) {
    buffer
      ..write(r.read<String>('sefaria_ref'))
      ..write('\n');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

Future<String> _computeContentHashFromFile(String dbPath) async {
  final db = ContentDatabase(NativeDatabase(File(dbPath)));
  try {
    return await _computeContentHash(db);
  } finally {
    await db.close();
  }
}

/// Loads tool/data/book_text_cache.json (atomic curriculum text from
/// Sefaria-Project + local Mongo) and inserts any refs not already present
/// in text_cache. Returns the number of new rows added.
Future<int> _mergeBookTextCache(ContentDatabase db) async {
  final f = File('tool/data/book_text_cache.json');
  if (!f.existsSync()) {
    print('  no book_text_cache.json — skipping');
    return 0;
  }
  final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final now = DateTime.now().toUtc();
  var added = 0;
  const batchSize = 500;
  final entries = raw.entries.toList();
  for (var i = 0; i < entries.length; i += batchSize) {
    final end = (i + batchSize).clamp(0, entries.length);
    await db.transaction(() async {
      for (var j = i; j < end; j++) {
        final entry = entries[j];
        final ref = entry.key;
        final v = entry.value as Map<String, dynamic>;
        final en = (v['en'] as String?) ?? '';
        final he = (v['he'] as String?) ?? '';
        if (en.isEmpty && he.isEmpty) continue;
        await db.customInsert(
          'INSERT OR REPLACE INTO text_cache '
          '(sefaria_ref, hebrew_text, english_text, fetched_at) '
          'VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withString(ref),
            Variable.withString(he),
            Variable.withString(en),
            Variable.withDateTime(now),
          ],
        );
        added++;
      }
    });
  }
  return added;
}

/// Loads the JSON produced by tool/text_extract/main.py and writes one
/// row per (date, program) to the daily_content table, keyed by the
/// display ref hebcal/Sefaria emitted for that day. The same display ref
/// can recur across days (e.g. a stable cycle); INSERT OR REPLACE keeps
/// the latest text on file.
Future<int> _populateDailyContent(ContentDatabase db) async {
  final f = File('tool/data/daily_content_cache.json');
  if (!f.existsSync()) {
    print('  no daily_content_cache.json — skipping');
    return 0;
  }
  final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  // Build a flat ref → (en, he) map. Last write wins on duplicate refs
  // (deterministic since dates iterate sorted).
  final byRef = <String, ({String en, String he})>{};
  // Pull the ref strings from the calendar caches so we know which ref
  // each (date, program) maps to.
  final hebcal =
      jsonDecode(
            File('tool/data/hebcal_calendar_cache.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final sefaria = File('tool/data/sefaria_calendar_cache.json').existsSync()
      ? jsonDecode(
              File('tool/data/sefaria_calendar_cache.json').readAsStringSync(),
            )
            as Map<String, dynamic>
      : <String, dynamic>{};
  for (final date in raw.keys.toList()..sort()) {
    final progs = raw[date] as Map<String, dynamic>;
    final hebcalProgs = (hebcal[date] as Map<String, dynamic>?) ?? const {};
    final sefariaProgs = (sefaria[date] as Map<String, dynamic>?) ?? const {};
    for (final entry in progs.entries) {
      final program = entry.key;
      final text = entry.value as Map<String, dynamic>;
      final refMap =
          (hebcalProgs[program] as Map<String, dynamic>?) ??
          (sefariaProgs[program] as Map<String, dynamic>?);
      final refStr = refMap?['en'] as String?;
      if (refStr == null || refStr.isEmpty) continue;
      final en = (text['en'] as String?) ?? '';
      final he = (text['he'] as String?) ?? '';
      if (en.isEmpty && he.isEmpty) continue;
      byRef[refStr] = (en: en, he: he);
    }
  }
  // Bulk insert
  var inserted = 0;
  const batchSize = 500;
  final entries = byRef.entries.toList();
  for (var i = 0; i < entries.length; i += batchSize) {
    final end = (i + batchSize).clamp(0, entries.length);
    await db.transaction(() async {
      for (var j = i; j < end; j++) {
        final e = entries[j];
        await db.customInsert(
          'INSERT OR REPLACE INTO daily_content '
          '(sefaria_ref, english_text, hebrew_text) VALUES (?, ?, ?)',
          variables: [
            Variable.withString(e.key),
            Variable.withString(e.value.en),
            Variable.withString(e.value.he),
          ],
        );
        inserted++;
      }
    });
  }
  return inserted;
}

Future<void> _writeSeedMetadata(
  ContentDatabase db, {
  required int version,
  required String contentHash,
  required int textCacheCount,
  required int calendarCycleCount,
}) async {
  await db.customStatement('DELETE FROM seed_metadata');
  final buildId = 'seed-$version-${DateTime.now().millisecondsSinceEpoch}';
  await db.customInsert(
    'INSERT INTO seed_metadata '
    '(version, built_at, build_id, text_cache_count, calendar_cycle_count, '
    'content_hash, min_app_version) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    variables: [
      Variable.withInt(version),
      Variable.withString(DateTime.now().toUtc().toIso8601String()),
      Variable.withString(buildId),
      Variable.withInt(textCacheCount),
      Variable.withInt(calendarCycleCount),
      Variable.withString(contentHash),
      Variable.withString('1.0.0'),
    ],
  );
  print(
    '  SeedMetadata: v$version, hash=${contentHash.substring(0, 12)}…, '
    'text=$textCacheCount, cycles=$calendarCycleCount',
  );
}

// ── Validate-only ─────────────────────────────────────────────────────────

Future<void> _validateExisting(String dbPath, _Args args) async {
  print('Validating existing seed DB at $dbPath...');
  final file = File(dbPath);
  if (!file.existsSync()) {
    stderr.writeln('❌ File not found: $dbPath');
    exit(1);
  }

  final db = ContentDatabase(NativeDatabase(file));
  try {
    // Verify schema against the Drift class by probing each table.
    final expectedTables = ['text_cache', 'calendar_cycles', 'seed_metadata'];
    for (final t in expectedTables) {
      final info = await db.customSelect('PRAGMA table_info($t)').get();
      if (info.isEmpty) {
        stderr.writeln('❌ Missing table: $t');
        exit(1);
      }
    }

    // Verify seed_metadata has new columns.
    final metaColumns = await db
        .customSelect('PRAGMA table_info(seed_metadata)')
        .get();
    final metaColNames = metaColumns.map((r) => r.read<String>('name')).toSet();
    for (final col in ['content_hash', 'min_app_version']) {
      if (!metaColNames.contains(col)) {
        stderr.writeln('❌ Missing column seed_metadata.$col');
        exit(1);
      }
    }

    final meta = await db.seedMetadataDao.getVersion();
    if (meta == null) {
      stderr.writeln('❌ No SeedMetadata row');
      exit(1);
    }

    final textCount = await _countRows(db, 'text_cache');
    final metaCount = await _countRows(db, 'seed_metadata');

    print('  Version:         ${meta.version}');
    print('  Built:           ${meta.builtAt}');
    print('  Build ID:        ${meta.buildId}');
    print('  Content Hash:    ${meta.contentHash}');
    print('  Min App Version: ${meta.minAppVersion}');
    print('  TextCache:       $textCount');
    print('  SeedMetadata:    $metaCount');

    final failures = <String>[];
    if (metaCount != 1) {
      failures.add('SeedMetadata expected 1, got $metaCount');
    }
    if (meta.contentHash.isEmpty) {
      failures.add('SeedMetadata.contentHash is empty');
    }
    if (textCount > 0 && textCount < 50000) {
      failures.add('TextCache expected >= 50000, got $textCount');
    }

    if (failures.isNotEmpty) {
      stderr.writeln('❌ Validation failed:');
      for (final f in failures) {
        stderr.writeln('   • $f');
      }
      exit(1);
    }
    print('✅ Validation passed');
  } finally {
    await db.close();
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

Future<int> _countRows(ContentDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle();
  return row.read<int>('c');
}

void _printSizeReport(String dbPath) {
  print('');
  print('=== Size Report ===');
  final file = File(dbPath);
  print(
    'Total DB size: '
    '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
  );
}
