// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed/learning_program_seeds.dart';
import 'package:learning_tracker/core/database/seed_version.dart';

/// CLI tool to build the pre-built Content DB shipped in the APK.
///
/// Usage:
///   dart run tool/seed_content_db.dart [--validate-only] [--size-report]
///
/// Produces:
///   build/seed.db          — uncompressed SQLite database
///   build/seed.db.gz       — gzip compressed for APK bundling
///   assets/db/content.db.gz — copied for Flutter asset bundling
///
/// Phases:
///   1. Create SQLite DB matching ContentDatabase Drift schema
///   2. Populate LearningPrograms from seed constants
///   3. Populate SeedMetadata
///   4. Populate TextCache from fetched text JSON files
///   5. Populate CalendarCycles (stub — awaiting API integration)
///   6. Compress to .gz
///
/// Before running, fetch text content first:
///   dart run tool/seed_text_content.dart

const _curricula = [
  'mishnayos',
  'bavli',
  'yerushalmi',
  'chumash',
  'mishna_berurah',
  'nach',
  'mussar',
];

Future<void> main(List<String> args) async {
  final validateOnly = args.contains('--validate-only');
  final sizeReport = args.contains('--size-report');

  print('🌱 Seed Content DB Builder');
  print('  Version: $bundledSeedVersion');
  print('  Mode: ${validateOnly ? "validate-only" : "full build"}');
  print('');

  // Ensure output directory exists
  final buildDir = Directory('build');
  if (!buildDir.existsSync()) {
    buildDir.createSync(recursive: true);
  }

  final dbPath = 'build/seed.db';
  final gzPath = 'build/seed.db.gz';
  final assetPath = 'assets/db/content.db.gz';

  if (validateOnly) {
    await _validateExisting(dbPath);
    return;
  }

  // Delete existing build artifact
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) {
    dbFile.deleteSync();
  }

  // Phase 1: Create database with ContentDatabase schema
  print('Phase 1: Creating SQLite database...');
  final db = ContentDatabase(NativeDatabase(File(dbPath)));
  await db.customStatement('SELECT 1'); // Force schema creation

  // Phase 2: Populate LearningPrograms
  print('Phase 2: Populating LearningPrograms...');
  await _seedLearningPrograms(db);

  // Phase 3: Populate SeedMetadata (updated with actual counts after Phase 4)
  print('Phase 3: SeedMetadata — deferred until after content population');

  // Phase 4: Populate TextCache from fetched text JSON files
  print('Phase 4: Populating TextCache...');
  final textCacheCount = await _seedTextCache(db);

  // Phase 5: Calendar cycles (stub — full implementation in separate PR)
  print('Phase 5: CalendarCycles population (stub — 0 items for dev)');
  // TODO: Reverse-engineer all 12 calendar programs from
  // Sefaria/Hebcal APIs for 2024-2030 date range
  const calendarCycleCount = 0;

  // Write SeedMetadata with actual counts
  print('Phase 3 (deferred): Writing SeedMetadata...');
  await db.customInsert(
    'INSERT INTO seed_metadata (version, built_at, build_id, text_cache_count, calendar_cycle_count) '
    'VALUES (?, ?, ?, ?, ?)',
    variables: [
      Variable.withInt(bundledSeedVersion),
      Variable.withString(DateTime.now().toUtc().toIso8601String()),
      Variable.withString('local-dev-${DateTime.now().millisecondsSinceEpoch}'),
      Variable.withInt(textCacheCount),
      Variable.withInt(calendarCycleCount),
    ],
  );

  await db.close();

  // Phase 6: Compress
  print('Phase 6: Compressing...');
  final uncompressed = File(dbPath).readAsBytesSync();
  final compressed = gzip.encode(uncompressed);
  File(gzPath).writeAsBytesSync(compressed);

  // Copy to assets directory
  final assetDir = Directory('assets/db');
  if (!assetDir.existsSync()) {
    assetDir.createSync(recursive: true);
  }
  File(gzPath).copySync(assetPath);

  // Report
  final uncompressedMB = uncompressed.length / 1024 / 1024;
  final compressedMB = compressed.length / 1024 / 1024;
  print('');
  print('✅ Seed DB built successfully!');
  print('  Uncompressed: ${uncompressedMB.toStringAsFixed(2)} MB');
  print('  Compressed:   ${compressedMB.toStringAsFixed(2)} MB');
  print('  Ratio:        ${(compressed.length / uncompressed.length * 100).toStringAsFixed(1)}%');
  print('  TextCache:    $textCacheCount items');
  print('  CalendarCycles: $calendarCycleCount items');
  print('  Output:       $gzPath → $assetPath');

  if (sizeReport) {
    await _printSizeReport(dbPath);
  }
}

Future<void> _seedLearningPrograms(ContentDatabase db) async {
  for (final program in learningProgramSeeds) {
    await db.customInsert(
      'INSERT OR IGNORE INTO learning_programs (name, display_name, description, '
      'curriculum_type, is_active, has_tests, stages_config, test_config, '
      'created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(program['name']! as String),
        Variable.withString(program['display_name']! as String),
        Variable.withString(program['description']! as String),
        Variable.withString(program['curriculum_type']! as String),
        Variable.withBool(program['is_active']! as bool),
        Variable.withBool(program['has_tests']! as bool),
        Variable.withString(program['stages_config']! as String),
        Variable.withString(program['test_config']! as String),
        Variable.withDateTime(DateTime.now().toUtc()),
      ],
    );
  }
  final count = await db.contentLearningProgramDao.getAllPrograms();
  print('  Inserted ${count.length} programs');
}

/// Populates TextCache from pre-fetched text JSON files.
///
/// Reads `build/text_content/{curriculum}_text.json.gz` (or uncompressed
/// `.json`) for each curriculum and bulk-inserts into the TextCache table.
///
/// Returns the total number of items inserted.
Future<int> _seedTextCache(ContentDatabase db) async {
  final textContentDir = Directory('build/text_content');
  if (!textContentDir.existsSync()) {
    print('  ⚠️  No build/text_content/ directory found.');
    print('  Run `dart run tool/seed_text_content.dart` first to fetch text.');
    return 0;
  }

  var totalInserted = 0;
  final now = DateTime.now().toUtc();

  for (final curriculum in _curricula) {
    final gzFile = File('${textContentDir.path}/${curriculum}_text.json.gz');
    final jsonFile = File('${textContentDir.path}/${curriculum}_text.json');
    // Also check progress file as fallback
    final progressFile =
        File('${textContentDir.path}/${curriculum}_progress.json');

    String? jsonString;

    if (gzFile.existsSync()) {
      final compressed = gzFile.readAsBytesSync();
      jsonString = utf8.decode(gzip.decode(compressed));
    } else if (jsonFile.existsSync()) {
      jsonString = jsonFile.readAsStringSync();
    } else if (progressFile.existsSync()) {
      jsonString = progressFile.readAsStringSync();
    }

    if (jsonString == null) {
      print('  ⚠️  No text data for $curriculum — skipping');
      continue;
    }

    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      print('  ⚠️  $curriculum: 0 items — skipping');
      continue;
    }

    // Bulk insert using batched raw SQL for performance
    var inserted = 0;
    var skipped = 0;

    for (final item in items) {
      final m = item as Map<String, dynamic>;
      final ref = m['ref'] as String?;
      final he = m['he'] as String? ?? '';
      final en = m['en'] as String? ?? '';

      if (ref == null || ref.isEmpty) {
        skipped++;
        continue;
      }

      // Skip items with no content at all
      if (he.isEmpty && en.isEmpty) {
        skipped++;
        continue;
      }

      await db.customInsert(
        'INSERT OR IGNORE INTO text_cache '
        '(sefaria_ref, hebrew_text, english_text, fetched_at) '
        'VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(ref),
          Variable.withString(he),
          Variable.withString(en),
          Variable.withDateTime(now),
        ],
      );
      inserted++;
    }

    totalInserted += inserted;
    print(
      '  $curriculum: $inserted inserted'
      '${skipped > 0 ? ', $skipped skipped' : ''}',
    );
  }

  print('  Total TextCache: $totalInserted items');
  return totalInserted;
}

Future<void> _validateExisting(String dbPath) async {
  print('Validating existing seed DB at $dbPath...');
  final file = File(dbPath);
  if (!file.existsSync()) {
    print('❌ File not found: $dbPath');
    exit(1);
  }

  final db = ContentDatabase(NativeDatabase(file));
  try {
    final meta = await db.seedMetadataDao.getVersion();
    if (meta == null) {
      print('❌ No SeedMetadata found');
      exit(1);
    }
    print('  Version: ${meta.version}');
    print('  Built:   ${meta.builtAt}');
    print('  Build:   ${meta.buildId}');

    final programs = await db.contentLearningProgramDao.getAllPrograms();
    print('  LearningPrograms: ${programs.length}');

    final refs = await db.contentTextCacheDao.getAllCachedRefs();
    print('  TextCache: ${refs.length} items');

    if (refs.isEmpty) {
      print('  ⚠️  TextCache is empty! Text display will show offline message.');
    }

    print('✅ Validation passed');
  } finally {
    await db.close();
  }
}

Future<void> _printSizeReport(String dbPath) async {
  print('');
  print('=== Size Report ===');
  final file = File(dbPath);
  print('Total DB size: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');
}
