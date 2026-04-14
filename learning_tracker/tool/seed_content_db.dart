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
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/database/seed/test_date_seeds.dart';
import 'package:learning_tracker/core/database/seed_version.dart';

import 'lib/daf_yomi_sequence.dart';

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

const _maxConcurrentFetches = 5;
const _batchFlushSize = 100;
const _textErrorRateThreshold = 0.01; // 1%

/// Date range for calendar cycles (inclusive).
final _calendarStart = DateTime.utc(2024, 1, 1);
final _calendarEnd = DateTime.utc(2030, 12, 31);

/// Sefaria calendar_items title.en → CalendarProgramRegistry.id.
///
/// Keys MUST match the registry IDs in [CalendarProgramRegistry] so
/// LocalCalendarEngine.getEntry() can resolve display names via
/// `CalendarProgramRegistry.byId()` (Story 19.4 T6).
const _sefariaCalendarMap = {
  'Daf Yomi': 'daf_yomi',
  'Daily Mishnah': 'mishna_yomit',
  'Daily Rambam': 'rambam_1_chapter',
  'Daily Rambam (3 Chapters)': 'rambam_3_chapters',
  'Yerushalmi Yomi': 'yerushalmi_yomi',
  'Daf a Week': 'daf_a_week',
  'Halakhah Yomit': 'halakhah_yomit',
  'Arukh HaShulchan Yomi': 'arukh_hashulchan_yomi',
  'Tanakh Yomi': 'tanakh_yomi',
};

/// Hebcal category → internal program key.
const _hebcalCategoryMap = {
  'nachyomi': 'nach_yomi',
  'chofetzChaim': 'chofetz_chaim_daily',
  'kitzurShulchanAruch': 'kitzur_shulchan_aruch_yomi',
};

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

enum _Mode { build, validateOnly, textOnly, calendarOnly, programsOnly }

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
        mode = _Mode.calendarOnly;
      case '--programs-only':
        mode = _Mode.programsOnly;
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
  print('  Mode:    ${args.mode.name}');
  print('  Version: ${args.seedVersion}');
  print('  Output:  ${args.output}');
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
    // Phase 2: Programs + TestDates
    if (args.mode == _Mode.build || args.mode == _Mode.programsOnly) {
      print('Phase 2: Seeding LearningPrograms + TestDates...');
      await _seedProgramsAndTestDates(db, args.verbose);
    }

    // Phase 3: Text content
    var textCacheCount = 0;
    if (args.mode == _Mode.build || args.mode == _Mode.textOnly) {
      print('Phase 3: Fetching text content from Sefaria...');
      textCacheCount = await _fetchAndInsertTextContent(db, args);
    } else {
      textCacheCount = await _countRows(db, 'text_cache');
    }

    // Phase 4: Calendar cycles
    var calendarCycleCount = 0;
    if (args.mode == _Mode.build || args.mode == _Mode.calendarOnly) {
      print('Phase 4: Fetching calendar cycles...');
      calendarCycleCount = await _fetchAndInsertCalendarCycles(db, args);
    } else {
      calendarCycleCount = await _countRows(db, 'calendar_cycles');
    }

    // Phase 5: Finalize
    if (args.mode != _Mode.programsOnly || args.mode == _Mode.build) {
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

// ── Phase 2: Programs + TestDates ────────────────────────────────────────

Future<void> _seedProgramsAndTestDates(ContentDatabase db, bool verbose) async {
  // ContentDatabase's onCreate already seeds programs + test dates when the
  // DB is brand new. For resumed runs, force an upsert so renamed/adjusted
  // seed data is reflected.
  for (final program in learningProgramSeeds) {
    final apiSource = program['api_source'] as String?;
    final apiKey = program['api_program_key'] as String?;
    final isCalendar = (program['is_calendar_program'] as bool?) ?? false;
    final apiSourceSql = apiSource == null ? 'NULL' : '?';
    final apiKeySql = apiKey == null ? 'NULL' : '?';

    final variables = <Variable<Object>>[
      Variable.withString(program['name']! as String),
      Variable.withString(program['display_name']! as String),
      Variable.withString(program['description']! as String),
      Variable.withString(program['curriculum_type']! as String),
      Variable.withBool(program['is_active']! as bool),
      Variable.withBool(program['has_tests']! as bool),
      Variable.withString(program['stages_config']! as String),
      Variable.withString(program['test_config']! as String),
      Variable.withDateTime(DateTime.now().toUtc()),
      if (apiSource != null) Variable.withString(apiSource),
      if (apiKey != null) Variable.withString(apiKey),
      Variable.withBool(isCalendar),
    ];
    await db.customInsert(
      'INSERT OR REPLACE INTO learning_programs '
      '(name, display_name, description, curriculum_type, is_active, '
      'has_tests, stages_config, test_config, created_at, api_source, '
      'api_program_key, is_calendar_program) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, $apiSourceSql, $apiKeySql, ?)',
      variables: variables,
    );
  }

  final programRows = await db.contentLearningProgramDao.getAllPrograms();
  print('  LearningPrograms: ${programRows.length} rows');

  // Test dates — 24 months ahead from build date (spec T5).
  final seeds = generateTestDateSeeds(
    from: DateTime.now().toUtc(),
    monthsAhead: 24,
  );
  await db.customStatement('DELETE FROM test_dates');
  var inserted = 0;
  for (final td in seeds) {
    final programName = td['program_name'] as String?;
    if (programName == null) continue;
    final program = programRows.where((p) => p.name == programName).toList();
    if (program.isEmpty) continue;
    await db.customInsert(
      'INSERT INTO test_dates (program_id, test_date, material_description) '
      'VALUES (?, ?, ?)',
      variables: [
        Variable.withInt(program.first.id),
        Variable.withDateTime(td['test_date']! as DateTime),
        Variable.withString(td['material_description'] as String? ?? ''),
      ],
    );
    inserted++;
  }
  print('  TestDates: $inserted rows');
}

// ── Phase 3: Text content ────────────────────────────────────────────────

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

  for (var i = 0; i < toFetch.length; i += _maxConcurrentFetches) {
    final batch = toFetch.skip(i).take(_maxConcurrentFetches).toList();

    final futures = batch.map((leaf) async {
      try {
        final texts = await _fetchBothLanguages(dio, leaf.ref);
        return (ref: leaf.ref, he: texts.he, en: texts.en, error: false);
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          await Future<void>.delayed(const Duration(seconds: 5));
          try {
            final texts = await _fetchBothLanguages(dio, leaf.ref);
            return (ref: leaf.ref, he: texts.he, en: texts.en, error: false);
          } catch (_) {
            return (ref: leaf.ref, he: '', en: '', error: true);
          }
        }
        return (ref: leaf.ref, he: '', en: '', error: true);
      } catch (_) {
        return (ref: leaf.ref, he: '', en: '', error: true);
      }
    });

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

    if (bufferedInserts.length >= _batchFlushSize) {
      await _flushTextBatch(db, bufferedInserts);
      bufferedInserts.clear();
    }

    final progress = fetched + errors;
    if (progress % 500 == 0 || progress == toFetch.length) {
      print(
        '    Progress: $progress/${toFetch.length} '
        '(fetched $fetched, errors $errors)',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  if (bufferedInserts.isNotEmpty) {
    await _flushTextBatch(db, bufferedInserts);
  }
  dio.close();

  final total = fetched + errors;
  final errorRate = total == 0 ? 0 : errors / total;
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

// ── Phase 4: Calendar cycles ─────────────────────────────────────────────

Future<int> _fetchAndInsertCalendarCycles(
  ContentDatabase db,
  _Args args,
) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.sefaria.org',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Sefaria: iterate 1 day at a time.
  await _fetchSefariaCalendar(db, dio, args);

  // Hebcal: monthly batches.
  await _fetchHebcalCalendar(db, args);

  dio.close();
  return _countRows(db, 'calendar_cycles');
}

Future<void> _fetchSefariaCalendar(
  ContentDatabase db,
  Dio dio,
  _Args args,
) async {
  // Resume support: find the max dateKey per program to skip ahead.
  final perProgramMax = <String, String>{};
  if (args.resume) {
    final existing = await db
        .customSelect(
          'SELECT program_key, MAX(date_key) AS max_date '
          'FROM calendar_cycles GROUP BY program_key',
        )
        .get();
    for (final row in existing) {
      perProgramMax[row.read<String>('program_key')] = row.read<String>(
        'max_date',
      );
    }
  }

  final totalDays = _calendarEnd.difference(_calendarStart).inDays + 1;
  var processed = 0;

  for (
    var d = _calendarStart;
    !d.isAfter(_calendarEnd);
    d = d.add(const Duration(days: 1))
  ) {
    final dateKey = _formatDate(d);

    // Skip if every Sefaria-sourced program already has a row for
    // this date or later.
    final allCovered = _sefariaCalendarMap.values.every(
      (programKey) => (perProgramMax[programKey] ?? '').compareTo(dateKey) >= 0,
    );
    if (allCovered) {
      processed++;
      continue;
    }

    Map<String, dynamic>? json;
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/calendars',
        queryParameters: {'year': d.year, 'month': d.month, 'day': d.day},
      );
      json = response.data;
    } catch (e) {
      if (args.verbose) {
        stderr.writeln('  Sefaria calendar fetch failed for $dateKey: $e');
      }
    }

    if (json != null) {
      final items = (json['calendar_items'] as List<dynamic>?) ?? const [];
      final rows = <({String program, String ref, String display})>[];
      for (final raw in items.cast<Map<String, dynamic>>()) {
        final titleEn =
            ((raw['title'] as Map<String, dynamic>?)?['en'] as String?) ?? '';
        final programKey = _sefariaCalendarMap[titleEn];
        if (programKey == null) continue;
        final ref = (raw['ref'] as String?) ?? '';
        if (ref.isEmpty) continue;
        final display =
            ((raw['displayValue'] as Map<String, dynamic>?)?['en']
                as String?) ??
            '';
        rows.add((program: programKey, ref: ref, display: display));
      }
      if (rows.isNotEmpty) {
        await db.transaction(() async {
          for (final r in rows) {
            await db.customInsert(
              'INSERT OR REPLACE INTO calendar_cycles '
              '(program_key, date_key, sefaria_ref, display_name) '
              'VALUES (?, ?, ?, ?)',
              variables: [
                Variable.withString(r.program),
                Variable.withString(dateKey),
                Variable.withString(r.ref),
                Variable.withString(r.display),
              ],
            );
          }
        });
      }
    }

    // Daf Yomi Cycle 15 fallback (post 2027-06-07).
    if (d.isAfter(DateTime.utc(2027, 6, 7))) {
      final existing = await db
          .customSelect(
            'SELECT 1 FROM calendar_cycles WHERE program_key = ? AND date_key = ?',
            variables: [
              Variable.withString('daf_yomi'),
              Variable.withString(dateKey),
            ],
          )
          .getSingleOrNull();
      if (existing == null) {
        final fallback = _dafYomiCycle15Ref(d);
        if (fallback != null) {
          await db.customInsert(
            'INSERT OR REPLACE INTO calendar_cycles '
            '(program_key, date_key, sefaria_ref, display_name) '
            'VALUES (?, ?, ?, ?)',
            variables: [
              Variable.withString('daf_yomi'),
              Variable.withString(dateKey),
              Variable.withString(fallback),
              const Variable(''),
            ],
          );
        }
      }
    }

    processed++;
    if (processed % 100 == 0 || processed == totalDays) {
      print('    Sefaria calendar: $processed/$totalDays days');
    }
    // Rate limit: ~2 req/s.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> _fetchHebcalCalendar(ContentDatabase db, _Args args) async {
  final hebcalDio = Dio(
    BaseOptions(
      baseUrl: 'https://www.hebcal.com',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  var month = DateTime.utc(_calendarStart.year, _calendarStart.month, 1);
  var batches = 0;
  while (!month.isAfter(_calendarEnd)) {
    final nextMonth = DateTime.utc(month.year, month.month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    final rangeStart = _formatDate(month);
    final rangeEnd = _formatDate(
      lastDay.isBefore(_calendarEnd) ? lastDay : _calendarEnd,
    );

    try {
      final response = await hebcalDio.get<Map<String, dynamic>>(
        '/hebcal',
        queryParameters: {
          'v': '1',
          'cfg': 'json',
          'start': rangeStart,
          'end': rangeEnd,
          'c': 'off',
          'nyomi': 'on',
          'dcc': 'on',
          'dksa': 'on',
        },
      );
      final items = (response.data?['items'] as List<dynamic>?) ?? const [];
      final rows =
          <({String program, String dateKey, String ref, String display})>[];
      for (final raw in items.cast<Map<String, dynamic>>()) {
        final category = raw['category'] as String?;
        final programKey = _hebcalCategoryMap[category];
        if (programKey == null) continue;
        final date = raw['date'] as String? ?? '';
        final dateKey = date.length >= 10 ? date.substring(0, 10) : '';
        if (dateKey.isEmpty) continue;
        final ref = _extractRefFromHebcalLink(
          raw['link'] as String?,
          (raw['memo'] as String?) ?? (raw['title'] as String?) ?? '',
        );
        final display = (raw['title'] as String?) ?? '';
        rows.add((
          program: programKey,
          dateKey: dateKey,
          ref: ref,
          display: display,
        ));
      }
      if (rows.isNotEmpty) {
        await db.transaction(() async {
          for (final r in rows) {
            await db.customInsert(
              'INSERT OR REPLACE INTO calendar_cycles '
              '(program_key, date_key, sefaria_ref, display_name) '
              'VALUES (?, ?, ?, ?)',
              variables: [
                Variable.withString(r.program),
                Variable.withString(r.dateKey),
                Variable.withString(r.ref),
                Variable.withString(r.display),
              ],
            );
          }
        });
      }
    } catch (e) {
      if (args.verbose) {
        stderr.writeln('  Hebcal fetch failed for $rangeStart..$rangeEnd: $e');
      }
    }

    batches++;
    if (batches % 12 == 0) {
      print('    Hebcal: $batches monthly batches processed');
    }
    month = nextMonth;
    // Light rate-limit.
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  hebcalDio.close();
}

/// Daf Yomi Cycle 15 started Berakhot 2a on 2027-06-08 (Cycle 14 ends
/// 2027-06-07). Hard-coded fallback for dates beyond the Sefaria API.
String? _dafYomiCycle15Ref(DateTime date) {
  final cycleStart = DateTime.utc(2027, 6, 8);
  if (date.isBefore(cycleStart)) return null;
  final dayIndex = date.difference(cycleStart).inDays;
  if (dayIndex < 0 || dayIndex >= _dafYomiSequence.length) return null;
  return _dafYomiSequence[dayIndex];
}

/// Complete 2,711-entry Daf Yomi cycle sequence imported from
/// tool/lib/daf_yomi_sequence.dart.
const List<String> _dafYomiSequence = dafYomiSequence;

String _extractRefFromHebcalLink(String? link, String fallback) {
  if (link == null || !link.contains('sefaria.org/')) return fallback;
  try {
    final uri = Uri.parse(link);
    final path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    return Uri.decodeComponent(path);
  } catch (_) {
    return fallback;
  }
}

// ── Phase 5: Finalize ────────────────────────────────────────────────────

Future<String> _computeContentHash(ContentDatabase db) async {
  final refs = await db
      .customSelect('SELECT sefaria_ref FROM text_cache ORDER BY sefaria_ref')
      .get();
  final cycles = await db
      .customSelect(
        'SELECT program_key, date_key FROM calendar_cycles '
        'ORDER BY program_key, date_key',
      )
      .get();

  final buffer = StringBuffer();
  for (final r in refs) {
    buffer
      ..write(r.read<String>('sefaria_ref'))
      ..write('\n');
  }
  buffer.write('---\n');
  for (final r in cycles) {
    buffer
      ..write(r.read<String>('program_key'))
      ..write('|')
      ..write(r.read<String>('date_key'))
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
    '(version, built_at, build_id, text_cache_count, calendar_cycle_count) '
    'VALUES (?, ?, ?, ?, ?)',
    variables: [
      Variable.withInt(version),
      Variable.withString(DateTime.now().toUtc().toIso8601String()),
      Variable.withString(buildId),
      Variable.withInt(textCacheCount),
      Variable.withInt(calendarCycleCount),
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
      'calendar_cycles',
      'learning_programs',
      'test_dates',
      'seed_metadata',
    ];
    for (final t in expectedTables) {
      final info = await db.customSelect('PRAGMA table_info($t)').get();
      if (info.isEmpty) {
        stderr.writeln('❌ Missing table: $t');
        exit(1);
      }
    }

    final meta = await db.seedMetadataDao.getVersion();
    if (meta == null) {
      stderr.writeln('❌ No SeedMetadata row');
      exit(1);
    }

    final textCount = await _countRows(db, 'text_cache');
    final cycleCount = await _countRows(db, 'calendar_cycles');
    final programCount = await _countRows(db, 'learning_programs');
    final metaCount = await _countRows(db, 'seed_metadata');

    print('  Version:         ${meta.version}');
    print('  Built:           ${meta.builtAt}');
    print('  Build ID:        ${meta.buildId}');
    print('  TextCache:       $textCount');
    print('  CalendarCycles:  $cycleCount');
    print('  LearningPrograms:$programCount');
    print('  SeedMetadata:    $metaCount');

    final failures = <String>[];
    if (args.mode == _Mode.validateOnly) {
      // Row-count thresholds (skip in programs-only builds).
      if (programCount != 18) {
        failures.add('LearningPrograms expected 18, got $programCount');
      }
      if (metaCount != 1) {
        failures.add('SeedMetadata expected 1, got $metaCount');
      }
      // Only enforce large-content thresholds when a full build has run.
      if (textCount > 0 && textCount < 50000) {
        failures.add('TextCache expected >= 50000, got $textCount');
      }
      if (cycleCount > 0 && cycleCount < 10000) {
        failures.add('CalendarCycles expected >= 10000, got $cycleCount');
      }
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

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void _printSizeReport(String dbPath) {
  print('');
  print('=== Size Report ===');
  final file = File(dbPath);
  print(
    'Total DB size: '
    '${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
  );
}
