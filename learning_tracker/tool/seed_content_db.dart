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
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_version.dart';

import 'lib/sequences/halakhah_yomit_seq.dart';

// ── Configuration ────────────────────────────────────────────────────────

const _curricula = {
  'mishnayos': 'mishnayos.json',
  'bavli': 'bavli.json',
  'yerushalmi': 'yerushalmi.json',
  'chumash': 'chumash.json',
  'mishna_berurah': 'mishna_berurah.json',
  'nach': 'nach.json',
  'mussar': 'mussar.json',
};

const _maxConcurrentFetches = 20;
const _batchFlushSize = 200;
const _textErrorRateThreshold = 0.01; // 1%
const _batchDelayMs = 50;
const _backoffBaseMs = 2000;
const _maxRetries = 3;

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
  print('  Concurrency: $_maxConcurrentFetches');
  print('');

  final buildDir = Directory(args.output);
  if (!buildDir.existsSync()) {
    buildDir.createSync(recursive: true);
  }

  final dbPath = '${args.output}/seed.db';
  final gzPath = '${args.output}/seed.db.gz';
  final sidecarPath = '${args.output}/seed_version.json';
  const assetPath = 'assets/db/content.db.gz';

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

    // Phase 3: Text content (he + en)
    var textCacheCount = 0;
    if (args.mode == _Mode.build || args.mode == _Mode.textOnly) {
      print('Phase 3: Fetching text content from Sefaria (he, en)...');
      textCacheCount = await _fetchAndInsertTextContent(db, args);
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
  print('Phase 6: Compressing seed.db → seed.db.gz...');
  final uncompressed = File(dbPath).readAsBytesSync();
  final compressed = gzip.encode(uncompressed);
  File(gzPath).writeAsBytesSync(compressed);

  final assetDir = Directory('assets/db');
  if (!assetDir.existsSync()) {
    assetDir.createSync(recursive: true);
  }
  File(gzPath).copySync(assetPath);

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

// ── Phase 3: Text content ────────────────────────────────────────────────

/// Record for a single fetched text (Hebrew + English).
typedef _TextResult = ({
  String ref,
  String he,
  String en,
  bool error,
  bool rateLimited,
});

Future<int> _fetchAndInsertTextContent(ContentDatabase db, _Args args) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.sefaria.org',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Resume support: find already-inserted refs so we don't re-fetch them.
  final alreadyFetched = <String>{};
  if (args.resume) {
    final existing = await db.contentTextCacheDao.getAllCachedRefs();
    alreadyFetched.addAll(existing);
    if (alreadyFetched.isNotEmpty) {
      print('  Resume: ${alreadyFetched.length} refs already in DB');
    }
  }

  // Collect all leaf refs from hierarchy JSONs.
  final allLeaves = <({String curriculum, String ref})>[];
  for (final entry in _curricula.entries) {
    if (args.curriculum != null && entry.key != args.curriculum) continue;
    final hierarchyPath = 'assets/content/hierarchy/${entry.value}';
    final file = File(hierarchyPath);
    if (!file.existsSync()) {
      print('  ⚠️  Missing hierarchy: $hierarchyPath — skipping');
      continue;
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final items = (json['items'] as List<dynamic>?) ?? const [];
    for (final item in items.cast<Map<String, dynamic>>()) {
      if (item['isLeaf'] != true) continue;
      final ref = item['sefariaRef'] as String?;
      if (ref == null || ref.isEmpty) continue;
      allLeaves.add((curriculum: entry.key, ref: ref));
    }
  }
  print('  Total leaf items: ${allLeaves.length}');

  final toFetch = allLeaves
      .where((l) => !alreadyFetched.contains(l.ref))
      .toList();
  print('  Remaining to fetch: ${toFetch.length}');

  final errorsLog = File('${args.output}/seed_errors.log');
  var fetched = 0;
  var errors = 0;
  final bufferedInserts = <({String ref, String he, String en})>[];

  // Adaptive concurrency: start at max, reduce on 429s, recover over time.
  var activeConcurrency = _maxConcurrentFetches;
  var consecutiveSuccess = 0;
  final sw = Stopwatch()..start();

  for (var i = 0; i < toFetch.length; i += activeConcurrency) {
    final batch = toFetch.skip(i).take(activeConcurrency).toList();

    final futures = batch.map((leaf) => _fetchWithRetry(dio, leaf.ref, args));
    final results = await Future.wait(futures);

    for (final r in results) {
      if (r.error) {
        errors++;
        errorsLog.writeAsStringSync('${r.ref}\n', mode: FileMode.append);
      } else {
        bufferedInserts.add((ref: r.ref, he: r.he, en: r.en));
        fetched++;
      }
    }

    // Adaptive throttling — only trigger on actual rate limits, not 404s.
    final batchHadRateLimit = results.any((r) => r.rateLimited);
    if (batchHadRateLimit && activeConcurrency > 5) {
      activeConcurrency = (activeConcurrency * 0.6).round();
      consecutiveSuccess = 0;
      if (args.verbose) {
        print('    ⚡ Throttled to $activeConcurrency concurrent');
      }
    } else {
      consecutiveSuccess++;
      if (consecutiveSuccess > 20 &&
          activeConcurrency < _maxConcurrentFetches) {
        activeConcurrency = (activeConcurrency + 2).clamp(
          1,
          _maxConcurrentFetches,
        );
        consecutiveSuccess = 0;
        if (args.verbose) {
          print('    ⚡ Recovered to $activeConcurrency concurrent');
        }
      }
    }

    if (bufferedInserts.length >= _batchFlushSize) {
      await _flushTextBatch(db, bufferedInserts);
      bufferedInserts.clear();
    }

    final progress = fetched + errors;
    if (progress % 500 == 0 || progress == toFetch.length) {
      final elapsed = sw.elapsed;
      final rate = progress > 0 ? elapsed.inSeconds / progress : 0;
      final remaining = (toFetch.length - progress) * rate;
      print(
        '    Progress: $progress/${toFetch.length} '
        '(fetched $fetched, errors $errors, '
        '~${(remaining / 60).toStringAsFixed(0)}m remaining)',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: _batchDelayMs));
  }

  if (bufferedInserts.isNotEmpty) {
    await _flushTextBatch(db, bufferedInserts);
  }
  dio.close();

  final total = fetched + errors;
  final errorRate = total == 0 ? 0 : errors / total;
  print(
    '  Text fetch complete: $fetched ok, $errors errors '
    '(${(errorRate * 100).toStringAsFixed(2)}%)',
  );
  // Only enforce threshold when fetching a meaningful batch (not just retrying
  // persistent failures on resume).
  if (errorRate > _textErrorRateThreshold && total > 500) {
    stderr.writeln(
      '❌ Text fetch error rate ${(errorRate * 100).toStringAsFixed(2)}% '
      'exceeds ${(_textErrorRateThreshold * 100).toStringAsFixed(1)}% '
      'threshold (see ${errorsLog.path})',
    );
    exit(3);
  }

  return _countRows(db, 'text_cache');
}

/// Fetch a single ref with exponential backoff on 429 / transient errors.
Future<_TextResult> _fetchWithRetry(Dio dio, String ref, _Args args) async {
  for (var attempt = 0; attempt < _maxRetries; attempt++) {
    try {
      final texts = await _fetchBothLanguages(dio, ref);
      return (
        ref: ref,
        he: texts.he,
        en: texts.en,
        error: false,
        rateLimited: false,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429 ||
          e.type == DioExceptionType.connectionTimeout) {
        final delay = _backoffBaseMs * (1 << attempt); // 2s, 4s, 8s
        if (args.verbose) {
          print('    ⏳ 429 on $ref — backoff ${delay}ms (attempt $attempt)');
        }
        await Future<void>.delayed(Duration(milliseconds: delay));
        continue;
      }
      // Non-retryable HTTP error (404, 500, etc.) — don't throttle.
      if (args.verbose) {
        print('    ❌ ${e.response?.statusCode ?? e.type} on $ref');
      }
      return (ref: ref, he: '', en: '', error: true, rateLimited: false);
    } catch (e) {
      if (args.verbose) {
        print('    ❌ $e on $ref');
      }
      return (ref: ref, he: '', en: '', error: true, rateLimited: false);
    }
  }
  // All retries exhausted — was rate limited.
  return (ref: ref, he: '', en: '', error: true, rateLimited: true);
}

Future<void> _flushTextBatch(
  ContentDatabase db,
  List<({String ref, String he, String en})> batch,
) async {
  await db.transaction(() async {
    final now = DateTime.now().toUtc();
    for (final item in batch) {
      await db.customInsert(
        'INSERT OR REPLACE INTO text_cache '
        '(sefaria_ref, hebrew_text, english_text, fetched_at) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(item.ref),
          Variable.withString(item.he),
          Variable.withString(item.en),
          Variable.withDateTime(now),
        ],
      );
    }
  });
}

/// Fetch Hebrew + English text for a single Sefaria ref.
///
/// The /api/v3/texts endpoint returns all available versions in one call.
/// We pick the first version for each of he and en.
Future<({String he, String en})> _fetchBothLanguages(
  Dio dio,
  String sefariaRef,
) async {
  final encodedRef = Uri.encodeComponent(sefariaRef);
  // Shulchan Arukh default is non-nikkud; request Torat Emet for nikkud.
  final heVersion = sefariaRef.startsWith('Shulchan Arukh')
      ? 'hebrew|Torat Emet 363'
      : 'hebrew';
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v3/texts/$encodedRef',
    queryParameters: {
      'version': ['english', heVersion],
    },
  );
  final data = response.data;
  if (data == null) return (he: '', en: '');
  final versions = data['versions'] as List<dynamic>? ?? const [];
  String? he;
  String? en;
  for (final version in versions) {
    if (version is! Map<String, dynamic>) continue;
    final lang =
        (version['actualLanguage'] as String?) ??
        (version['language'] as String?) ??
        '';
    final text = version['text'];
    if (lang == 'he' && he == null) {
      he = _extractText(text);
    } else if (lang == 'en' && en == null) {
      en = _extractText(text);
    }
  }
  return (he: he ?? '', en: en ?? '');
}

String _extractText(dynamic text) {
  if (text == null) return '';
  if (text is String) return _stripHtml(text);
  if (text is List) {
    return text.map(_extractText).where((s) => s.isNotEmpty).join('\n');
  }
  return '';
}

String _stripHtml(String html) => html.replaceAll(RegExp('<[^>]*>'), '').trim();

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
