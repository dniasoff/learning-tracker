// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'lib/sefaria_mongo.dart';

/// Builds `tool/data/book_text_cache.json` (clean {ref: {en, he}}) by resolving
/// every atomic ref in `tool/data/curriculum_books.json` against the local
/// Sefaria Mongo. NO public-API calls.
///
/// Usage:
///   dart run tool/seed/build_text_cache.dart [--limit N] [--mongo URI]
///     --limit N  Resolve only the first N refs (validation); writes to
///                book_text_cache.sample.json instead of the real output.
///
/// Output: tool/data/book_text_cache.json  (refs with no text dropped)

const _defaultManifest = 'tool/data/curriculum_books.json';
const _output = 'tool/data/book_text_cache.json';

Future<void> main(List<String> args) async {
  var limit = 0;
  var uri = 'mongodb://127.0.0.1:27117/sefaria';
  var manifest = _defaultManifest;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--limit':
        limit = int.parse(args[++i]);
      case '--mongo':
        uri = args[++i];
      case '--manifest':
        manifest = args[++i];
      default:
        stderr.writeln('Unknown flag: ${args[i]}');
        exit(2);
    }
  }

  final refs = _loadManifestRefs(manifest);
  print('Manifest refs: ${refs.length}');
  final targets = limit > 0 ? refs.take(limit).toList() : refs;
  if (limit > 0) print('LIMIT MODE: $limit refs');

  final m = await SefariaMongo.connect(uri);
  await m.warmTitles();

  final out = <String, Map<String, String>>{};
  var done = 0, kept = 0, parseFail = 0, empty = 0, withEn = 0;
  final failSamples = <String>[];
  final sw = Stopwatch()..start();
  for (final ref in targets) {
    final r = await m.resolve(ref);
    done++;
    if (r.he.isEmpty && r.en.isEmpty) {
      // Distinguish a genuine empty (text-less ref, e.g. Talmud 1a) from a
      // parse failure for diagnostics.
      final parsed = await m.debugParse(ref);
      if (parsed == 'PARSE FAILED') {
        parseFail++;
        if (failSamples.length < 60) failSamples.add(ref);
      } else {
        empty++;
      }
      continue;
    }
    out[ref] = {'en': r.en, 'he': r.he};
    kept++;
    if (r.en.isNotEmpty) withEn++;
    if (done % 2000 == 0) {
      final rate = done / sw.elapsed.inSeconds.clamp(1, 1 << 30);
      print(
        '  $done/${targets.length}  kept=$kept en=$withEn '
        'parseFail=$parseFail empty=$empty  ${rate.toStringAsFixed(0)}/s',
      );
    }
  }
  print(
    'DONE: resolved=$done kept=$kept english=$withEn '
    'parseFail=$parseFail empty=$empty',
  );
  if (failSamples.isNotEmpty) {
    print('parse-failure samples (${failSamples.length}):');
    for (final f in failSamples) {
      print('  FAIL $f');
    }
  }

  final isSample = limit > 0 || manifest != _defaultManifest;
  final path = isSample ? 'tool/data/book_text_cache.sample.json' : _output;
  final sortedKeys = out.keys.toList()..sort();
  final ordered = <String, dynamic>{};
  for (final k in sortedKeys) {
    ordered[k] = out[k];
  }
  File(path).writeAsStringSync(jsonEncode(ordered));
  print('Wrote $path: ${ordered.length} refs');

  await m.close();
}

List<String> _loadManifestRefs(String manifest) {
  final raw =
      jsonDecode(File(manifest).readAsStringSync()) as Map<String, dynamic>;
  final refs = <String>{};
  for (final books in raw.values) {
    for (final list in (books as Map<String, dynamic>).values) {
      for (final r in list as List<dynamic>) {
        refs.add(r as String);
      }
    }
  }
  final sorted = refs.toList()..sort();
  return sorted;
}
