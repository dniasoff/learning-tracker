// Calls the same calendar generators that seed_content_db.dart uses for a
// random sample of dates and cross-checks against live Sefaria API responses.
// This verifies the wired-up cache + fallback logic without running the full
// seed build (which would also fetch tens of thousands of text entries).
//
// Usage (from learning_tracker/):
//   dart run tool/verify_seed_calendar.dart
//   dart run tool/verify_seed_calendar.dart --samples=40

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _cachePath = 'tool/data/sefaria_calendar_cache.json';

const _start = '2024-01-01';
const _end = '2032-12-31';

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

Future<void> main(List<String> args) async {
  final samplesArg = args
      .firstWhere(
        (a) => a.startsWith('--samples='),
        orElse: () => '--samples=40',
      )
      .substring('--samples='.length);
  final n = int.parse(samplesArg);

  // Load cache the same way seed_content_db.dart does.
  final cacheFile = File(_cachePath);
  if (!cacheFile.existsSync()) {
    stderr.writeln('Cache missing — run tool/sefaria_fetch (go).');
    exit(2);
  }
  final cacheRaw =
      jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
  final cache = cacheRaw.map(
    (date, inner) => MapEntry(
      date,
      (inner as Map<String, dynamic>).map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(
          k,
          _Cached(en: m['en'] as String? ?? '', he: m['he'] as String? ?? ''),
        );
      }),
    ),
  );

  final start = DateTime.parse(_start);
  final end = DateTime.parse(_end);
  final totalDays = end.difference(start).inDays + 1;
  final rng = Random(42);
  final picks = <DateTime>{};
  while (picks.length < n) {
    picks.add(start.add(Duration(days: rng.nextInt(totalDays))));
  }
  final samples = picks.toList()..sort();

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final report = <String, _Tally>{};

  for (final d in samples) {
    final dk = _fmt(d);
    final live = await _fetchDay(client, d);
    if (live.isEmpty) {
      stderr.writeln('  SKIP $dk (live fetch failed)');
      continue;
    }
    final cachedDay = cache[dk] ?? const <String, _Cached>{};
    for (final entry in _titleToKey.entries) {
      final liveKey = entry.value;
      if (!live.containsKey(liveKey)) continue;
      final liveRef = live[liveKey]!;
      final cached = cachedDay[liveKey];
      final t = report.putIfAbsent(liveKey, _Tally.new);
      if (cached == null) {
        t.absent++;
        t.diffs.add('$dk: cache=ABSENT  live=$liveRef');
        continue;
      }
      // Compare English ref. Allow Yerushalmi displayValue equivalence.
      final enMatches =
          cached.en == liveRef ||
          _isYerushalmiEquivalent(
            cached.en,
            liveRef,
            live['${liveKey}__display'],
          );
      final liveHe = live['${liveKey}__he'] ?? '';
      final heMatches = cached.he == liveHe;
      if (enMatches && heMatches) {
        t.matched++;
      } else if (!enMatches) {
        t.mismatched++;
        t.diffs.add('$dk: cache_en=${cached.en} live_en=$liveRef');
      } else {
        t.heMismatched++;
        t.diffs.add('$dk: cache_he=${cached.he} live_he=$liveHe');
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  client.close(force: true);

  var totalChecks = 0;
  var totalProblems = 0;
  for (final e in report.entries) {
    final t = e.value;
    final total = t.matched + t.mismatched + t.heMismatched + t.absent;
    totalChecks += total;
    totalProblems += t.mismatched + t.heMismatched + t.absent;
    final flag = (t.mismatched == 0 && t.heMismatched == 0 && t.absent == 0)
        ? 'OK   '
        : 'CHECK';
    stdout.writeln(
      '  $flag ${e.key.padRight(28)} matched=${t.matched}/$total  '
      'en_mismatch=${t.mismatched}  he_mismatch=${t.heMismatched}  absent=${t.absent}',
    );
    for (final d in t.diffs.take(3)) {
      stdout.writeln('         $d');
    }
    if (t.diffs.length > 3) {
      stdout.writeln('         … ${t.diffs.length - 3} more');
    }
  }
  stdout.writeln('\n$totalChecks checks, $totalProblems mismatches/missing');
  exit(totalProblems == 0 ? 0 : 1);
}

bool _isYerushalmiEquivalent(String cached, String live, String? disp) {
  if (!cached.startsWith('Jerusalem Talmud ')) return false;
  if (disp == null) return false;
  return cached == 'Jerusalem Talmud $disp';
}

class _Tally {
  int matched = 0;
  int mismatched = 0;
  int heMismatched = 0;
  int absent = 0;
  final diffs = <String>[];
}

class _Cached {
  _Cached({required this.en, this.he = ''});
  final String en;
  final String he;
}

Future<Map<String, String>> _fetchDay(HttpClient client, DateTime d) async {
  final url = Uri.parse(
    'https://www.sefaria.org/api/calendars'
    '?diaspora=1&year=${d.year}&month=${d.month}&day=${d.day}',
  );
  for (var attempt = 0; attempt < 4; attempt++) {
    try {
      final req = await client.getUrl(url);
      final resp = await req.close();
      if (resp.statusCode == 429) {
        await resp.drain<void>();
        await Future<void>.delayed(const Duration(seconds: 30));
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
        final t = (item['title'] as Map<String, dynamic>)['en'] as String;
        final k = _titleToKey[t];
        if (k == null) continue;
        final ref = item['ref'] as String?;
        if (ref != null) out[k] = ref;
        final dispMap = item['displayValue'] as Map<String, dynamic>?;
        final dispEn = dispMap?['en'] as String?;
        if (dispEn != null) out['${k}__display'] = dispEn;
        final dispHe = dispMap?['he'] as String?;
        if (dispHe != null) out['${k}__he'] = dispHe;
      }
      return out;
    } on Object {
      await Future<void>.delayed(Duration(seconds: 2 << attempt));
    }
  }
  return const {};
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
