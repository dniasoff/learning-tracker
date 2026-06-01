// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'lib/sefaria_mongo.dart';

/// Builds `tool/data/daily_content_cache.json` (clean {date:{program:{en,he}}})
/// by resolving every (date, program) calendar entry against the local Sefaria
/// Mongo. NO public-API calls.
///
/// Calendar source-of-truth: the committed `hebcal_calendar_cache.json` +
/// `sefaria_calendar_cache.json` (date → program → {en, he, url}). The
/// canonical Sefaria ref for each entry comes from the entry's `url` (the `en`
/// display string is often abbreviated/non-canonical); program-specific
/// resolvers handle sefer_hamitzvot day-numbers and rambam cross-book ranges.
///
/// Usage: dart run tool/seed/build_daily_content.dart [--limit-days N] [--mongo URI]

const _hebcalPath = 'tool/data/hebcal_calendar_cache.json';
const _sefariaPath = 'tool/data/sefaria_calendar_cache.json';
const _output = 'tool/data/daily_content_cache.json';

Future<void> main(List<String> args) async {
  var limitDays = 0;
  var uri = 'mongodb://127.0.0.1:27117/sefaria';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--limit-days':
        limitDays = int.parse(args[++i]);
      case '--mongo':
        uri = args[++i];
      default:
        stderr.writeln('Unknown flag: ${args[i]}');
        exit(2);
    }
  }

  final hebcal = _loadCalendar(_hebcalPath, required: true);
  final sefaria = _loadCalendar(_sefariaPath, required: false);
  final days = <String, Map<String, _ProgRef>>{};
  hebcal.forEach((d, p) => days.putIfAbsent(d, () => {}).addAll(p));
  sefaria.forEach((d, p) => days.putIfAbsent(d, () => {}).addAll(p));

  final sortedDates = days.keys.toList()..sort();
  final dateSlice = limitDays > 0
      ? sortedDates.take(limitDays).toList()
      : sortedDates;
  if (limitDays > 0) print('LIMIT MODE: first $limitDays days');

  // Build the resolution plan + distinct ref set.
  final plan = <String, Map<String, _Resolution>>{};
  final allRefs = <String>{};
  var externalCount = 0;
  for (final date in dateSlice) {
    for (final entry in days[date]!.entries) {
      final program = entry.key;
      final ref = entry.value;
      if (ref.en.isEmpty) continue;
      final res = _resolve(ref.en, ref.url, program);
      plan.putIfAbsent(date, () => {});
      // Always carry the display strings so the output step can fall back to
      // an `external` entry if the resolved ref(s) come back text-empty
      // (mirrors main.py: unresolvable display ref → external, never dropped).
      final withDisplay = _Resolution(
        refs: res.refs,
        external: res.refs.isEmpty,
        displayEn: ref.en,
        displayHe: ref.he,
      );
      plan[date]![program] = withDisplay;
      if (res.refs.isEmpty) {
        externalCount++;
      } else {
        allRefs.addAll(res.refs);
      }
    }
  }
  print(
    'Planned. distinct refs to resolve: ${allRefs.length}, '
    'external fallbacks: $externalCount',
  );

  // Resolve all distinct refs from Mongo.
  final m = await SefariaMongo.connect(uri);
  await m.warmTitles();
  final cache = <String, ({String he, String en})>{};
  var done = 0, miss = 0;
  final missSamples = <String>[];
  final sw = Stopwatch()..start();
  for (final ref in allRefs) {
    final r = await m.resolve(ref);
    cache[ref] = r;
    done++;
    if (r.he.isEmpty && r.en.isEmpty) {
      miss++;
      if (missSamples.length < 40) missSamples.add(ref);
    }
    if (done % 2000 == 0) {
      final rate = done / sw.elapsed.inSeconds.clamp(1, 1 << 30);
      print(
        '  $done/${allRefs.length}  miss=$miss  '
        '${rate.toStringAsFixed(0)}/s',
      );
    }
  }
  await m.close();
  print('Resolved ${allRefs.length} refs; empty/miss=$miss');
  if (missSamples.isNotEmpty) {
    print('miss samples:');
    for (final s in missSamples) {
      print('  MISS $s');
    }
  }

  _writeOutput(plan, cache);
}

// ── Calendar cache loading ──────────────────────────────────────────────────

class _ProgRef {
  const _ProgRef({required this.en, this.he = '', this.url});
  final String en;
  final String he;
  final String? url;
}

Map<String, Map<String, _ProgRef>> _loadCalendar(
  String path, {
  required bool required,
}) {
  final f = File(path);
  if (!f.existsSync()) {
    if (required) throw FileSystemException('cache missing', path);
    return {};
  }
  final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final out = <String, Map<String, _ProgRef>>{};
  raw.forEach((date, progs) {
    final inner = <String, _ProgRef>{};
    (progs as Map<String, dynamic>).forEach((prog, v) {
      final m = v as Map<String, dynamic>;
      inner[prog] = _ProgRef(
        en: (m['en'] as String?) ?? '',
        he: (m['he'] as String?) ?? '',
        url: m['url'] as String?,
      );
    });
    out[date] = inner;
  });
  return out;
}

// ── Ref resolution (mirrors tool/text_extract/main.py) ──────────────────────

class _Resolution {
  const _Resolution({
    required this.refs,
    this.external = false,
    this.displayEn = '',
    this.displayHe = '',
  });
  final List<String> refs;
  final bool external;
  final String displayEn;
  final String displayHe;
}

final _seferToken = RegExp(r'\b([NP])(\d+)\b');
final _seferLong = RegExp(
  r'(Negative|Positive)\s+Commandment\s+(\d+)',
  caseSensitive: false,
);
final _seferPrinciple = RegExp(
  r'Principle\s+(\d+)(?:\s*-\s*(\d+))?',
  caseSensitive: false,
);
final _seferIntro = RegExp('Introduction', caseSensitive: false);

List<String> _resolveSeferHamitzvot(String refStr) {
  final refs = <String>[];
  if (_seferIntro.hasMatch(refStr)) {
    refs.add('Sefer HaMitzvot, Introductions');
  }
  for (final m in _seferPrinciple.allMatches(refStr)) {
    final start = m.group(1);
    final end = m.group(2);
    refs.add(
      end != null
          ? 'Sefer HaMitzvot, Shorashim $start-$end'
          : 'Sefer HaMitzvot, Shorashim $start',
    );
  }
  final pairs = <(String, int)>[];
  for (final m in _seferLong.allMatches(refStr)) {
    final kind = m.group(1)!.toLowerCase() == 'negative'
        ? 'Negative'
        : 'Positive';
    pairs.add((kind, int.parse(m.group(2)!)));
  }
  if (pairs.isEmpty) {
    for (final m in _seferToken.allMatches(refStr)) {
      final kind = m.group(1) == 'N' ? 'Negative' : 'Positive';
      pairs.add((kind, int.parse(m.group(2)!)));
    }
  }
  for (final (kind, n) in pairs) {
    refs.add('Sefer HaMitzvot, $kind Commandments $n');
  }
  return refs;
}

List<String> _resolveMishnehTorahMulti(String refStr) {
  final parts = [
    for (final p in refStr.split(','))
      if (p.trim().isNotEmpty) p.trim(),
  ];
  if (parts.length < 2) return const [];
  return [for (final p in parts) 'Mishneh Torah, $p'];
}

_Resolution _resolve(String refStr, String? urlHint, String program) {
  if (program == 'sefer_hamitzvot') {
    final refs = _resolveSeferHamitzvot(refStr);
    if (refs.isNotEmpty) return _Resolution(refs: refs);
  }
  if (program == 'rambam_3_chapters' && refStr.contains(',')) {
    final refs = _resolveMishnehTorahMulti(refStr);
    if (refs.isNotEmpty) return _Resolution(refs: refs);
  }
  // The url carries the canonical ref; the en display string is a fallback.
  if (urlHint != null && urlHint.contains('sefaria.org')) {
    final path = urlHint.split('?').first.split('/').last;
    final canonical = Uri.decodeComponent(path).replaceAll('_', ' ');
    return _Resolution(refs: [canonical]);
  }
  return _Resolution(refs: [refStr]);
}

// ── Output assembly ─────────────────────────────────────────────────────────

void _writeOutput(
  Map<String, Map<String, _Resolution>> plan,
  Map<String, ({String he, String en})> cache,
) {
  final out = <String, dynamic>{};
  var entries = 0, external = 0, empty = 0;
  final dates = plan.keys.toList()..sort();
  for (final date in dates) {
    final dayOut = <String, dynamic>{};
    for (final entry in plan[date]!.entries) {
      final program = entry.key;
      final res = entry.value;
      if (res.external) {
        dayOut[program] = {
          'en': res.displayEn,
          'he': res.displayHe,
          'external': true,
        };
        external++;
        continue;
      }
      final isMulti =
          program == 'sefer_hamitzvot' || program == 'rambam_3_chapters';
      final enParts = <String>[];
      final heParts = <String>[];
      if (isMulti) {
        for (final ref in res.refs) {
          final v = cache[ref];
          if (v == null) continue;
          if (v.en.isNotEmpty) enParts.add(v.en);
          if (v.he.isNotEmpty) heParts.add(v.he);
        }
      } else {
        for (final ref in res.refs) {
          final v = cache[ref];
          if (v == null) continue;
          if (v.en.isNotEmpty || v.he.isNotEmpty) {
            enParts.add(v.en);
            heParts.add(v.he);
            break;
          }
        }
      }
      final en = enParts.where((s) => s.isNotEmpty).join('\n\n');
      final he = heParts.where((s) => s.isNotEmpty).join('\n\n');
      if (en.isEmpty && he.isEmpty) {
        // Resolved ref(s) had no text — fall back to an external entry with the
        // display strings (mirrors main.py), so the calendar→daily_content
        // cross-reference (seed Phase 4c) still resolves and the user sees the
        // ref name rather than a blank screen.
        dayOut[program] = {
          'en': res.displayEn,
          'he': res.displayHe,
          'external': true,
        };
        external++;
        empty++;
        continue;
      }
      dayOut[program] = {'en': en, 'he': he};
      entries++;
    }
    if (dayOut.isNotEmpty) out[date] = dayOut;
  }
  File(_output).writeAsStringSync(jsonEncode(out));
  print(
    'Wrote $_output: days=${out.length} entries=$entries '
    'external=$external empty(skipped)=$empty',
  );
}
