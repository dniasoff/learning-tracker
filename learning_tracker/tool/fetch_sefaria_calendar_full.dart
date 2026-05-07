// Fetches Sefaria's /api/calendars day-by-day for the seed-build range
// (2024-01-01 → 2032-12-31) and captures BOTH the English `ref` and Hebrew
// `heRef` for every supported program. Writes incrementally to
// tool/data/sefaria_calendar_cache.json so the run can be resumed if
// Sefaria rate-limits us partway through.
//
// Output cache shape:
//   { "YYYY-MM-DD": { "<programKey>": { "en": "<ref>", "he": "<heRef>" } } }
//
// Programs captured (anything Sefaria's calendar response covers):
//   daf_yomi, daily_mishnah, daily_rambam, daily_rambam_3, daf_a_week,
//   halakhah_yomit, arukh_hashulchan_yomi, tanakh_yomi, yerushalmi_yomi,
//   nach_yomi, chofetz_chaim_daily, kitzur_shulchan_aruch_yomi.
//
// Rate behaviour: ~1 req/sec sustained. On 429, exponential backoff capped
// at 5 min. Saves to disk every 50 days.
//
// Usage (from learning_tracker/):
//   dart run tool/fetch_sefaria_calendar_full.dart
//   dart run tool/fetch_sefaria_calendar_full.dart --refresh
//   dart run tool/fetch_sefaria_calendar_full.dart --start=2026-01-01

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _cachePath = 'tool/data/sefaria_calendar_cache.json';

const _buildStart = '2024-01-01';
const _buildEnd = '2032-12-31';

/// Maps Sefaria's calendar item title (English) to our program-key.
/// Anything not in this map is skipped.
const _titleToKey = <String, String>{
  'Daf Yomi': 'daf_yomi',
  'Daily Mishnah': 'daily_mishnah',
  'Daily Rambam': 'daily_rambam',
  'Daily Rambam (3 Chapters)': 'daily_rambam_3',
  'Daf a Week': 'daf_a_week',
  'Halakhah Yomit': 'halakhah_yomit',
  'Arukh HaShulchan Yomi': 'arukh_hashulchan_yomi',
  'Tanakh Yomi': 'tanakh_yomi',
  'Yerushalmi Yomi': 'yerushalmi_yomi',
  'Nach Yomi': 'nach_yomi',
  'Chofetz Chaim': 'chofetz_chaim_daily',
  'Kitzur Shulchan Arukh': 'kitzur_shulchan_aruch_yomi',
};

const _requestSpacingMs = 1100;
const _flushEvery = 50;
const _retries = 8;

Future<void> main(List<String> args) async {
  final refresh = args.contains('--refresh');
  String? overrideStart;
  for (final a in args) {
    if (a.startsWith('--start=')) overrideStart = a.substring(8);
  }

  final cacheFile = File(_cachePath);
  cacheFile.parent.createSync(recursive: true);

  final cache = <String, Map<String, Map<String, String>>>{};
  if (cacheFile.existsSync() && !refresh) {
    final raw =
        jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in raw.entries) {
      final inner = entry.value as Map<String, dynamic>;
      final converted = <String, Map<String, String>>{};
      var allHaveHe = true;
      for (final pe in inner.entries) {
        final v = pe.value;
        // Drop legacy en-only string shape — we want en + he.
        if (v is String) {
          allHaveHe = false;
          continue;
        }
        final m = (v as Map<String, dynamic>).map(
          (k, vv) => MapEntry(k, vv as String),
        );
        if (!m.containsKey('en')) continue;
        if (!m.containsKey('he')) allHaveHe = false;
        converted[pe.key] = m;
      }
      // Only treat the day as "fully cached" when every program has both
      // en and he — otherwise we want this day re-fetched so the missing
      // Hebrew refs land.
      if (converted.isNotEmpty && allHaveHe) cache[entry.key] = converted;
    }
    stdout.writeln(
      'Loaded ${cache.length} fully-cached days '
      '(skipped any en-only legacy entries).',
    );
  }

  final start = DateTime.parse(overrideStart ?? _buildStart);
  final end = DateTime.parse(_buildEnd);
  final all = _datesBetween(start, end);
  final missing = all.where((d) => !cache.containsKey(d)).toList();
  stdout.writeln(
    'Need to fetch ${missing.length} of ${all.length} days '
    '(${cache.length} cached, target ~1 req/s).',
  );
  if (missing.isEmpty) {
    stdout.writeln('Cache is complete.');
    return;
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final began = DateTime.now();
  var done = 0;
  var failures = 0;

  for (final date in missing) {
    final entry = await _fetchDay(client, date);
    if (entry == null) {
      failures++;
      // Persist what we have and pause briefly before continuing.
      _writeCache(cacheFile, cache);
      stderr.writeln(
        '  $date abandoned after $_retries attempts (total failures: $failures); '
        'sleeping 60s before resuming…',
      );
      await Future<void>.delayed(const Duration(seconds: 60));
      continue;
    }
    cache[date] = entry;
    done++;
    if (done % _flushEvery == 0 || done == missing.length) {
      _writeCache(cacheFile, cache);
      final elapsed = DateTime.now().difference(began);
      final rate = done / elapsed.inSeconds.clamp(1, 1 << 30);
      stdout.writeln(
        '  $done/${missing.length} '
        '(${rate.toStringAsFixed(2)} req/s, ${elapsed.inSeconds}s elapsed)',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: _requestSpacingMs));
  }

  client.close(force: true);
  _writeCache(cacheFile, cache);
  stdout.writeln(
    'DONE — ${cache.length} days cached, $failures days failed (will be '
    'retried on next run).',
  );
}

void _writeCache(File f, Map<String, Map<String, Map<String, String>>> cache) {
  final keys = cache.keys.toList()..sort();
  final ordered = <String, Map<String, Map<String, String>>>{};
  for (final k in keys) {
    final inner = cache[k]!;
    final innerKeys = inner.keys.toList()..sort();
    ordered[k] = {
      for (final ik in innerKeys)
        ik: {
          for (final f in const ['en', 'he'])
            if (inner[ik]!.containsKey(f)) f: inner[ik]![f]!,
        },
    };
  }
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(ordered));
}

Future<Map<String, Map<String, String>>?> _fetchDay(
  HttpClient client,
  String date,
) async {
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
        // Exponential backoff: 30s, 60s, 120s, 240s, 300s (cap), 300s, 300s.
        final wait = (30 * (1 << attempt)).clamp(30, 300);
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
      final out = <String, Map<String, String>>{};
      for (final raw in items) {
        final item = raw as Map<String, dynamic>;
        final title = (item['title'] as Map<String, dynamic>)['en'] as String;
        final key = _titleToKey[title];
        if (key == null) continue;
        final ref = item['ref'] as String?;
        if (ref == null || ref.isEmpty) continue;
        // Sefaria's /api/calendars puts the user-facing Hebrew form in
        // displayValue.he (e.g. "בבא קמא ס׳") — not in heRef. heRef is null
        // for calendar items. Capture displayValue.he as our he ref.
        final displayValue = item['displayValue'] as Map<String, dynamic>?;
        final he = displayValue?['he'] as String?;
        // Last entry wins on transition days (matches what users actually
        // study that day — the freshly-opened content).
        final entry = <String, String>{'en': ref};
        if (he != null && he.isNotEmpty) entry['he'] = he;
        out[key] = entry;
      }
      return out;
    } on Object catch (e) {
      if (attempt == _retries - 1) {
        stderr.writeln('  $date FAILED ($_retries attempts): $e');
        return null;
      }
      await Future<void>.delayed(Duration(seconds: 2 << attempt));
    }
  }
  return null;
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
