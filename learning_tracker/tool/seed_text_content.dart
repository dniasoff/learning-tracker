// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart'; // Used in tool/ only (dev_dependency)

/// Fetches text content (Hebrew with nikud + English) from Sefaria API
/// for all leaf items in each curriculum's hierarchy JSON.
///
/// Usage:
///   dart run tool/seed_text_content.dart [curriculum]
///
/// Examples:
///   dart run tool/seed_text_content.dart           # all curricula
///   dart run tool/seed_text_content.dart mishnayos  # single curriculum
///
/// Output: build/text_content/{curriculum}_text.json.gz per curriculum
///
/// Features:
///   - Resume support: skips already-fetched refs from existing output
///   - Rate limiting: configurable concurrent requests
///   - Progress tracking: prints per-item and per-batch progress

const _curricula = {
  'mishnayos': 'mishnayos.json',
  'bavli': 'bavli.json',
  'yerushalmi': 'yerushalmi.json',
  'chumash': 'chumash.json',
  'mishna_berurah': 'mishna_berurah.json',
};

const _maxConcurrent = 5;
const _batchFlushSize = 100; // flush to disk every N items

Future<void> main(List<String> args) async {
  final targetCurriculum = args.isNotEmpty ? args[0] : null;

  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.sefaria.org',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Ensure output directory exists
  final outputDir = Directory('build/text_content');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  for (final entry in _curricula.entries) {
    final curriculumKey = entry.key;
    final hierarchyFile = entry.value;

    if (targetCurriculum != null && curriculumKey != targetCurriculum) {
      continue;
    }

    print('\n=== Processing $curriculumKey ===');
    await _processCurriculum(dio, curriculumKey, hierarchyFile, outputDir);
  }

  dio.close();
  print('\nDone!');
}

Future<void> _processCurriculum(
  Dio dio,
  String curriculumKey,
  String hierarchyFile,
  Directory outputDir,
) async {
  // 1. Read hierarchy JSON to get leaf items
  final hierarchyPath = 'assets/content/$hierarchyFile';
  final hierarchyJson =
      jsonDecode(File(hierarchyPath).readAsStringSync())
          as Map<String, dynamic>;
  final allItems = hierarchyJson['items'] as List<dynamic>;
  final leafItems = allItems
      .cast<Map<String, dynamic>>()
      .where((item) => item['isLeaf'] == true)
      .toList();

  print('Found ${leafItems.length} leaf items');

  // 2. Load existing progress (resume support)
  final progressFile = File('${outputDir.path}/${curriculumKey}_progress.json');
  final fetchedTexts = <String, Map<String, String>>{};

  if (progressFile.existsSync()) {
    final existing =
        jsonDecode(progressFile.readAsStringSync()) as Map<String, dynamic>;
    final existingItems = existing['items'] as List<dynamic>? ?? [];
    for (final item in existingItems) {
      final m = item as Map<String, dynamic>;
      fetchedTexts[m['ref'] as String] = {
        'he': m['he'] as String,
        'en': m['en'] as String,
      };
    }
    print('Resuming: ${fetchedTexts.length} already fetched');
  }

  // 3. Filter to unfetched items
  final remaining = leafItems
      .where((item) => !fetchedTexts.containsKey(item['sefariaRef']))
      .toList();

  print('Remaining to fetch: ${remaining.length}');

  if (remaining.isEmpty) {
    print('All items already fetched!');
    _writeOutput(outputDir, curriculumKey, fetchedTexts);
    return;
  }

  // 4. Fetch text for each item with concurrency control
  var fetched = 0;
  var errors = 0;
  final total = remaining.length;

  for (var i = 0; i < remaining.length; i += _maxConcurrent) {
    final batch = remaining.skip(i).take(_maxConcurrent).toList();

    final futures = batch.map((item) async {
      final ref = item['sefariaRef'] as String;
      try {
        final texts = await _fetchBothLanguages(dio, ref);
        return (ref: ref, he: texts.he, en: texts.en, error: false);
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          // Rate limited - wait and retry once
          print('  Rate limited, waiting 5s...');
          await Future<void>.delayed(const Duration(seconds: 5));
          try {
            final texts = await _fetchBothLanguages(dio, ref);
            return (ref: ref, he: texts.he, en: texts.en, error: false);
          } catch (_) {
            return (ref: ref, he: '', en: '', error: true);
          }
        }
        return (ref: ref, he: '', en: '', error: true);
      } catch (_) {
        return (ref: ref, he: '', en: '', error: true);
      }
    });

    final results = await Future.wait(futures);

    for (final result in results) {
      if (!result.error) {
        fetchedTexts[result.ref] = {'he': result.he, 'en': result.en};
        fetched++;
      } else {
        errors++;
        print('  ERROR: ${result.ref}');
      }
    }

    // Progress
    final progress = fetched + errors;
    if (progress % 50 == 0 || progress == total) {
      print('  Progress: $progress/$total ($errors errors)');
    }

    // Periodic flush
    if (progress % _batchFlushSize == 0) {
      _flushProgress(progressFile, curriculumKey, fetchedTexts);
    }

    // Small delay between batches to be polite to Sefaria
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  // 5. Final flush + write output
  _flushProgress(progressFile, curriculumKey, fetchedTexts);
  _writeOutput(outputDir, curriculumKey, fetchedTexts);

  print('Completed: $fetched fetched, $errors errors');
}

/// Fetches both Hebrew and English text in a single API call.
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

  final versions = data['versions'] as List<dynamic>? ?? [];

  String? hebrewText;
  String? englishText;

  for (final version in versions) {
    if (version is! Map<String, dynamic>) continue;
    final vLang =
        version['actualLanguage'] as String? ??
        version['language'] as String? ??
        '';
    final text = version['text'];

    if (vLang == 'he' && hebrewText == null) {
      hebrewText = _extractText(text);
    } else if (vLang == 'en' && englishText == null) {
      englishText = _extractText(text);
    }
  }

  return (he: hebrewText ?? '', en: englishText ?? '');
}

String _extractText(dynamic text) {
  if (text == null) return '';
  if (text is String) return _stripHtml(text);
  if (text is List) {
    return text.map(_extractText).where((s) => s.isNotEmpty).join('\n');
  }
  return '';
}

String _stripHtml(String html) {
  return html.replaceAll(RegExp('<[^>]*>'), '').trim();
}

void _flushProgress(
  File progressFile,
  String curriculumKey,
  Map<String, Map<String, String>> fetchedTexts,
) {
  final json = {
    'curriculumId': curriculumKey,
    'itemCount': fetchedTexts.length,
    'items': fetchedTexts.entries
        .map((e) => {'ref': e.key, 'he': e.value['he'], 'en': e.value['en']})
        .toList(),
  };
  progressFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(json),
  );
}

void _writeOutput(
  Directory outputDir,
  String curriculumKey,
  Map<String, Map<String, String>> fetchedTexts,
) {
  final output = {
    'version': 1,
    'curriculumId': curriculumKey,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'itemCount': fetchedTexts.length,
    'items': fetchedTexts.entries
        .map((e) => {'ref': e.key, 'he': e.value['he'], 'en': e.value['en']})
        .toList(),
  };

  // Write compact JSON (no indentation) to minimize size
  final jsonString = jsonEncode(output);

  // Write gzipped version
  final gzipped = gzip.encode(utf8.encode(jsonString));
  final gzFile = File('${outputDir.path}/${curriculumKey}_text.json.gz');
  gzFile.writeAsBytesSync(gzipped);

  // Also write uncompressed for inspection
  final jsonFile = File('${outputDir.path}/${curriculumKey}_text.json');
  jsonFile.writeAsStringSync(jsonString);

  final sizeMb = (gzFile.lengthSync() / 1024 / 1024).toStringAsFixed(2);
  final rawSizeMb = (jsonFile.lengthSync() / 1024 / 1024).toStringAsFixed(2);
  print('  Output: ${gzFile.path} (${sizeMb}MB gzipped, ${rawSizeMb}MB raw)');
}
