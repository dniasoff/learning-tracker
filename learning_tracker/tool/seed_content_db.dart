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

// Calendar cycles, learning programs, and test dates are computed at runtime.
// The seed tool only builds text_cache + seed_metadata.

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

    const calendarCycleCount = 0;

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
  if (errorRate > _textErrorRateThreshold) {
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
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v3/texts/$encodedRef',
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
    final expectedTables = [
      'text_cache',
      'seed_metadata',
    ];
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
