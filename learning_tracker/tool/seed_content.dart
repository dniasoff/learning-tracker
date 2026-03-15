// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';

import 'lib/sefaria/bavli_fetcher.dart';
import 'lib/sefaria/chumash_fetcher.dart';
import 'lib/sefaria/mishna_berurah_fetcher.dart';
import 'lib/sefaria/mishna_fetcher.dart';
import 'lib/sefaria/yerushalmi_fetcher.dart';

/// CLI script to fetch content from Sefaria API and generate bundled JSON files.
///
/// Usage: dart run tool/seed_content.dart
///
/// Generates JSON files in assets/content/ for each curriculum.
Future<void> main() async {
  print('🌱 Seeding content from Sefaria API...\n');

  // Configure Dio for Sefaria API
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.sefaria.org',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Create output directory
  final outputDir = Directory('assets/content');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Define fetchers with their output filenames
  final fetchers = [
    (MishnaFetcher(dio: dio), 'mishnayos.json'),
    (BavliFetcher(dio: dio), 'bavli.json'),
    (YerushalmiFetcher(dio: dio), 'yerushalmi.json'),
    (ChumashFetcher(dio: dio), 'chumash.json'),
    (MishnaBerurahFetcher(dio: dio), 'mishna_berurah.json'),
  ];

  var totalSize = 0;

  for (final (fetcher, filename) in fetchers) {
    try {
      print('Fetching ${fetcher.curriculumId}...');
      final result = await fetcher.fetchAllContent();

      // Convert to JSON structure
      final json = {
        'hierarchyConfig': {
          'curriculumId': result.hierarchyConfig.curriculumId,
          'levelLabels': result.hierarchyConfig.levelLabels,
          'maxLevels': result.hierarchyConfig.depth,
          'totalItems': result.hierarchyConfig.totalItems,
        },
        'items': result.items
            .map(
              (item) => {
                'curriculumId': item.curriculumId,
                'level1': item.level1,
                if (item.level2 != null) 'level2': item.level2,
                if (item.level3 != null) 'level3': item.level3,
                if (item.level4 != null) 'level4': item.level4,
                'displayNameHe': item.displayNameHe,
                'displayNameEn': item.displayNameEn,
                'sefariaRef': item.sefariaRef,
                'sortOrder': item.sortOrder,
                'isLeaf': item.isLeaf,
              },
            )
            .toList(),
      };

      // Validate schema
      _validateSchema(json, filename);

      // Write to file
      final file = File('${outputDir.path}/$filename');
      final encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(json);
      await file.writeAsString(jsonString);

      final fileSize = file.lengthSync();
      final fileSizeKB = (fileSize / 1024).toStringAsFixed(2);
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
      totalSize += fileSize;

      print(
        '✓ ${fetcher.curriculumId}: '
        '${result.items.length} items, '
        '${result.hierarchyConfig.totalItems} leaves → '
        '$fileSizeKB KB ($fileSizeMB MB)',
      );
    } catch (e, stack) {
      print('✗ Error fetching ${fetcher.curriculumId}: $e');
      print(stack);
      exit(1);
    }
  }

  final totalSizeMB = (totalSize / (1024 * 1024)).toStringAsFixed(2);
  print('\n✓ Total bundled content: $totalSizeMB MB');
  print('📦 Files written to assets/content/\n');
}

/// Validates that the JSON structure matches the expected schema.
void _validateSchema(Map<String, dynamic> json, String filename) {
  // Validate hierarchyConfig
  final config = json['hierarchyConfig'] as Map<String, dynamic>?;
  if (config == null) {
    throw Exception('$filename: Missing hierarchyConfig');
  }
  if (!config.containsKey('curriculumId') ||
      !config.containsKey('levelLabels') ||
      !config.containsKey('maxLevels') ||
      !config.containsKey('totalItems')) {
    throw Exception('$filename: Invalid hierarchyConfig structure');
  }

  // Validate items array
  final items = json['items'] as List?;
  if (items == null || items.isEmpty) {
    throw Exception('$filename: Missing or empty items array');
  }

  final requiredFields = [
    'curriculumId',
    'level1',
    'displayNameHe',
    'displayNameEn',
    'sefariaRef',
    'sortOrder',
    'isLeaf',
  ];

  // Validate a sample: first item, last item, and a random middle item.
  // For small lists, validate all items.
  final indicesToCheck = items.length <= 10
      ? List.generate(items.length, (i) => i)
      : [0, items.length - 1, Random().nextInt(items.length - 2) + 1];

  var invalidCount = 0;
  for (final idx in indicesToCheck) {
    final item = items[idx] as Map<String, dynamic>;
    for (final field in requiredFields) {
      if (!item.containsKey(field)) {
        print('WARNING: $filename item[$idx] missing required field: $field');
        invalidCount++;
      }
    }
  }

  if (invalidCount > 0) {
    throw Exception(
      '$filename: $invalidCount schema violation(s) found in sampled items',
    );
  }
}
