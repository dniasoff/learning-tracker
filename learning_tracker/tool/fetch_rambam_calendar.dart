// Fetches Sefaria's /api/calendars and extracts ONLY the two Daily Rambam
// programs (1-chapter and 3-chapter) for the seed-build date range. Writes
// to tool/data/sefaria_rambam_cache.json.
//
// Why a dedicated fetcher rather than a CSV: Sefaria-Data publishes a single
// 3-chapter CSV cycle (~339 days). The Daily Rambam cycle skips Yom Tov +
// fast days, so the cycle DRIFTS against the Gregorian calendar each
// iteration. A naive (n % cycle_len) lookup is correct for cycle 1 only.
//
// Run sparingly — Sefaria rate-limits aggressively. Saves incrementally so
// crashes / cancellations don't lose progress.
//
// Usage (from learning_tracker/):
//   dart run tool/fetch_rambam_calendar.dart
//   dart run tool/fetch_rambam_calendar.dart --refresh   (re-fetches all)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _cachePath = 'tool/data/sefaria_rambam_cache.json';
const _start = '2024-01-01';
const _end = '2032-12-31';

const _titleToKey = <String, String>{
  'Daily Rambam': 'daily_rambam',
  'Daily Rambam (3 Chapters)': 'daily_rambam_3',
};

const _requestSpacingMs = 350; // ~3/s sustained — well under Sefaria's bucket
const _flushEvery = 50;
const _retries = 6;

Future<void> main(List<String> args) async {
  final refresh = args.contains('--refresh');
  final cacheFile = File(_cachePath);
  cacheFile.parent.createSync(recursive: true);

  final cache = <String, Map<String, String>>{};
  if (cacheFile.existsSync() && !refresh) {
    final raw =
        jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in raw.entries) {
      final inner = (entry.value as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      );
      if (inner.length == _titleToKey.length) cache[entry.key] = inner;
    }
    stdout.writeln('Loaded ${cache.length} fully-cached days');
  }

  final all = _datesBetween(DateTime.parse(_start), DateTime.parse(_end));
  final missing = all.where((d) => !cache.containsKey(d)).toList();
  stdout.writeln(
    'Need to fetch ${missing.length} of ${all.length} days '
    '(${cache.length} already cached, target ~3/s).',
  );
  if (missing.isEmpty) {
    stdout.writeln('Cache complete.');
    return;
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final start = DateTime.now();
  var done = 0;

  for (final date in missing) {
    final entry = await _fetchDay(client, date);
    cache[date] = entry;
    done++;
    if (done % _flushEvery == 0 || done == missing.length) {
      _writeCache(cacheFile, cache);
      final elapsed = DateTime.now().difference(start);
      final rate = done / elapsed.inSeconds.clamp(1, 1 << 30);
      stdout.writeln(
        '  $done/${missing.length} '
        '(${rate.toStringAsFixed(1)} req/s, ${elapsed.inSeconds}s)',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: _requestSpacingMs));
  }
  client.close(force: true);
  _writeCache(cacheFile, cache);
  stdout.writeln('DONE');
}

void _writeCache(File f, Map<String, Map<String, String>> cache) {
  final keys = cache.keys.toList()..sort();
  final ordered = <String, Map<String, String>>{};
  for (final k in keys) {
    final inner = cache[k]!;
    final innerKeys = inner.keys.toList()..sort();
    ordered[k] = {for (final ik in innerKeys) ik: inner[ik]!};
  }
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(ordered));
}

Future<Map<String, String>> _fetchDay(HttpClient client, String date) async {
  final parts = date.split('-');
  final url = Uri.parse(
    'https://www.sefaria.org/api/calendars'
    '?diaspora=1&year=${parts[0]}&month=${parts[1]}&day=${parts[2]}',
  );
  for (var attempt = 0; attempt < _retries; attempt++) {
    try {
      final req = await client.getUrl(url);
      final resp = await req.close();
      if (resp.statusCode == 429) {
        await resp.drain<void>();
        // Exponential backoff on 429.
        final wait = 30 * (1 << attempt);
        stderr.writeln('  $date 429 — sleeping ${wait}s');
        await Future<void>.delayed(Duration(seconds: wait));
        continue;
      }
      if (resp.statusCode != 200) {
        await resp.drain<void>();
        throw HttpException('HTTP ${resp.statusCode}');
      }
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final items = json['calendar_items'] as List<dynamic>;
      final out = <String, String>{};
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final title = (item['title'] as Map<String, dynamic>)['en'] as String;
        final key = _titleToKey[title];
        if (key == null) continue;
        final ref = item['ref'] as String?;
        if (ref == null || ref.isEmpty) continue;
        out[key] = ref; // last entry per program wins (transition days)
      }
      return out;
    } on Object catch (e) {
      if (attempt == _retries - 1) {
        stderr.writeln('  $date FAILED: $e');
        return const {};
      }
      await Future<void>.delayed(Duration(seconds: 2 << attempt));
    }
  }
  return const {};
}

List<String> _datesBetween(DateTime start, DateTime end) {
  final out = <String>[];
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    out.add(_fmt(d));
  }
  return out;
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
