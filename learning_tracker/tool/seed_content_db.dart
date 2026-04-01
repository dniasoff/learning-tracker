// ignore_for_file: avoid_print

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
///   4. Populate TextCache (from Sefaria API — ~52K items, ~60-90 min)
///   5. Populate CalendarCycles (from Sefaria/Hebcal APIs — ~22 min)
///   6. Compress to .gz
///
/// The text and calendar population phases are stubs that will be
/// fully implemented when API integration is ready. For now, the tool
/// creates a valid but empty seed DB for development.
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

  // Phase 3: Populate SeedMetadata
  print('Phase 3: Writing SeedMetadata...');
  await db.customInsert(
    'INSERT INTO seed_metadata (version, built_at, build_id, text_cache_count, calendar_cycle_count) '
    'VALUES (?, ?, ?, ?, ?)',
    variables: [
      Variable.withInt(bundledSeedVersion),
      Variable.withString(DateTime.now().toUtc().toIso8601String()),
      Variable.withString('local-dev-${DateTime.now().millisecondsSinceEpoch}'),
      Variable.withInt(0),
      Variable.withInt(0),
    ],
  );

  // Phase 4: Text content (stub — full implementation in separate PR)
  print('Phase 4: TextCache population (stub — 0 items for dev)');
  // TODO: Integrate with existing seed_content.dart fetchers
  // to populate ~52,528 text items from Sefaria API

  // Phase 5: Calendar cycles (stub — full implementation in separate PR)
  print('Phase 5: CalendarCycles population (stub — 0 items for dev)');
  // TODO: Reverse-engineer all 12 calendar programs from
  // Sefaria/Hebcal APIs for 2024-2030 date range

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
  print('  Output:       $gzPath → $assetPath');

  if (sizeReport) {
    await _printSizeReport(dbPath);
  }
}

Future<void> _seedLearningPrograms(ContentDatabase db) async {
  for (final program in learningProgramSeeds) {
    await db.customInsert(
      'INSERT INTO learning_programs (name, display_name, description, '
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
  // Detailed per-table breakdown would require raw SQL DBSTAT queries
  // which are not available through Drift. The total size is sufficient
  // for budget monitoring.
}
