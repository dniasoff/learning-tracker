// Builds tool/data/sefaria_calendar_cache.json from Sefaria-Data CSVs that
// were downloaded into tool/data/sefaria_calendars/.
//
// We do this offline (parsing committed CSVs) instead of hitting Sefaria's
// /api/calendars endpoint because the live API rate-limits aggressively.
// The CSVs in https://github.com/Sefaria/Sefaria-Data/tree/master/sources/calendars
// are the authoritative inputs Sefaria itself derives the API from, so values
// are identical.
//
// Output cache shape:
//   { "YYYY-MM-DD": { "halakhah_yomit": "...", "yerushalmi_yomi": "...", … } }
//
// Programs covered by this builder (Sefaria-Data CSVs):
//   halakhah_yomit, arukh_hashulchan_yomi, daily_rambam, daily_rambam_3,
//   tanakh_yomi, yerushalmi_yomi, daf_a_week.
//
// Programs NOT covered here (use existing local sequence files):
//   daf_yomi, daily_mishnah  (already verified working)
//   nach_yomi, chofetz_chaim_daily, kitzur_shulchan_aruch_yomi  (Hebcal)
//
// Usage (from learning_tracker/):
//   dart run tool/build_sefaria_calendar_cache.dart

import 'dart:convert';
import 'dart:io';

const _outputPath = 'tool/data/sefaria_calendar_cache.json';
const _csvDir = 'tool/data/sefaria_calendars';

const _buildStart = '2024-01-01';
const _buildEnd = '2032-12-31';

void main() {
  final cache = <String, Map<String, String>>{};

  _addAll(cache, 'halakhah_yomit', _parseHalakhahYomit());
  _addAll(cache, 'arukh_hashulchan_yomi', _parseArukhHaShulchan());
  // Daily Rambam (3 chapters) and (1 chapter) skip Yom Tov / fast days, so
  // the cycle drifts vs. the Gregorian calendar across iterations. Sefaria's
  // CSV captures only one cycle — repeating it linearly produces wrong dates
  // for cycles 2+. These two programs are populated separately by
  // tool/fetch_rambam_calendar.dart, which slow-fetches the live API.
  _addAll(cache, 'tanakh_yomi', _parseTanakhYomi());
  _addAll(cache, 'yerushalmi_yomi', _parseYerushalmiYomi());

  // Merge in any previously-fetched Rambam data (slow API fetcher writes its
  // own file). Both files coexist; this script is idempotent.
  _mergeRambamCache(cache);
  // Daf a Week is computed algorithmically from the Daf Yomi sequence
  // (week_index → dafYomiSequence[week_index]) — the existing local logic in
  // seed_content_db.dart is correct, so we don't need a CSV for it.

  final filtered = <String, Map<String, String>>{};
  final start = DateTime.parse(_buildStart);
  final end = DateTime.parse(_buildEnd);
  for (final entry in cache.entries) {
    final d = DateTime.parse(entry.key);
    if (d.isBefore(start) || d.isAfter(end)) continue;
    filtered[entry.key] = entry.value;
  }

  // Order keys for deterministic output.
  final ordered = <String, Map<String, String>>{};
  final dateKeys = filtered.keys.toList()..sort();
  for (final dk in dateKeys) {
    final inner = filtered[dk]!;
    final ik = inner.keys.toList()..sort();
    ordered[dk] = {for (final k in ik) k: inner[k]!};
  }

  File(
    _outputPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(ordered));

  // Per-program coverage report.
  final programs = <String>{};
  for (final v in ordered.values) {
    programs.addAll(v.keys);
  }
  stdout.writeln('Wrote $_outputPath');
  stdout.writeln('  Date range: ${dateKeys.first} → ${dateKeys.last}');
  stdout.writeln('  Total days: ${ordered.length}');
  for (final key in programs.toList()..sort()) {
    final count = ordered.values.where((v) => v.containsKey(key)).length;
    final pct = (count / ordered.length * 100).toStringAsFixed(1);
    stdout.writeln('    ${key.padRight(28)} $count days  ($pct%)');
  }
}

void _addAll(
  Map<String, Map<String, String>> cache,
  String programKey,
  Map<String, String> entries,
) {
  for (final entry in entries.entries) {
    cache.putIfAbsent(entry.key, () => <String, String>{})[programKey] =
        entry.value;
  }
}

/// Folds a previously-fetched Rambam cache (built by fetch_rambam_calendar.dart
/// from the live Sefaria API) into the main cache. Missing file is ignored.
void _mergeRambamCache(Map<String, Map<String, String>> cache) {
  const path = 'tool/data/sefaria_rambam_cache.json';
  final file = File(path);
  if (!file.existsSync()) return;
  final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  for (final entry in raw.entries) {
    final inner = (entry.value as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as String),
    );
    if (inner.isEmpty) continue;
    cache.putIfAbsent(entry.key, () => <String, String>{}).addAll(inner);
  }
}

// ── Per-CSV parsers ─────────────────────────────────────────────────────

/// Halakhah_Yomit_2020-2038.csv — header row, then `M/D/YYYY,SECTION REF`
/// where SECTION is `OC` / `YD` / `EH` / `CM` / `Kitzur` mapping to a Sefaria
/// reference book.
Map<String, String> _parseHalakhahYomit() {
  final lines = File('$_csvDir/Halakhah_Yomit_2020-2038.csv').readAsLinesSync();
  final out = <String, String>{};
  for (var i = 1; i < lines.length; i++) {
    final cells = _splitCsv(lines[i]);
    if (cells.length < 2) continue;
    final dateKey = _normalizeUsDate(cells[0]);
    if (dateKey == null) continue;
    final raw = cells[1].trim();
    final ref = _expandHalakhahRef(raw);
    if (ref != null) out[dateKey] = ref;
  }
  return out;
}

String? _expandHalakhahRef(String raw) {
  // Examples: "OC 1:1-3", "YD 240:5", "Kitzur 29:16-20", "OC 629:18 - 630:1".
  final match = RegExp(r'^([A-Za-z]+)\s+(.+)$').firstMatch(raw);
  if (match == null) return null;
  final code = match.group(1)!;
  // Some rows have spaces around the dash on cross-siman ranges; Sefaria's
  // ref form is tight (no spaces), so collapse them.
  final rest = match.group(2)!.replaceAll(' - ', '-');
  switch (code) {
    case 'OC':
      return 'Shulchan Arukh, Orach Chayim $rest';
    case 'YD':
      return "Shulchan Arukh, Yoreh De'ah $rest";
    case 'EH':
      return 'Shulchan Arukh, Even HaEzer $rest';
    case 'CM':
      return 'Shulchan Arukh, Choshen Mishpat $rest';
    case 'Kitzur':
      return 'Kitzur Shulchan Arukh $rest';
    default:
      return null;
  }
}

/// AhS_Yomi_Calendar — `M/D/YYYY,Arukh_HaShulchan%2C_<Section>.<Siman>.<Range>`
/// where %2C is a URL-encoded comma. Use the longer (newer) file that covers
/// through 2034.
Map<String, String> _parseArukhHaShulchan() {
  const filePath =
      '$_csvDir/AhS_Yomi_Calendar_-_Sefaria - AhS_Yomi_Calendar_-_Sefaria.csv';
  final lines = File(filePath).readAsLinesSync();
  final out = <String, String>{};
  for (final line in lines) {
    if (line.isEmpty) continue;
    final cells = _splitCsv(line);
    if (cells.length < 2) continue;
    final dateKey = _normalizeUsDate(cells[0]);
    if (dateKey == null) continue;
    final encoded = cells[1].trim();
    if (encoded.isEmpty) continue;
    var ref = Uri.decodeComponent(encoded).replaceAll('_', ' ');
    // CSV has occasional typos: "OYoreh De'ah" (extra leading O), "OOrach"
    // (double O). Strip ONLY the duplicate-O case, never a legitimate "O…".
    ref = ref
        .replaceFirst('Arukh HaShulchan, OYoreh', 'Arukh HaShulchan, Yoreh')
        .replaceFirst('Arukh HaShulchan, OOrach', 'Arukh HaShulchan, Orach');
    // Section refs use dot delimiters (e.g. "Orach Chaim.1.1-8") — convert
    // the first dot after the section name to a space and the second to ":".
    ref = _dotToSpaceColonAfterSection(
      ref,
      sectionPrefix: 'Arukh HaShulchan, ',
    );
    out[dateKey] = ref;
  }
  return out;
}

/// Tanach_Yomi_Sedarim_Calendar — `M/D/YYYY,Seder Name,Start Ref,End Ref`
/// where rows like `2/1/2021,Parasha,,` mark Shabbat (no learning).
Map<String, String> _parseTanakhYomi() {
  final lines = File(
    '$_csvDir/Tanach_Yomi_Sedarim_Calendar_-_updated.csv',
  ).readAsLinesSync();
  final out = <String, String>{};
  for (final line in lines) {
    if (line.isEmpty) continue;
    final cells = _splitCsv(line);
    if (cells.length < 4) continue;
    final dateKey = _normalizeEuDate(cells[0]);
    if (dateKey == null) continue;
    final seder = cells[1].trim();
    final startRef = cells[2].trim();
    final endRef = cells[3].trim();
    if (seder == 'Parasha' || startRef.isEmpty || endRef.isEmpty) continue;
    // Sefaria's API formats Tanakh Yomi as "Book Ch:V-Ch:V" (one book name).
    // Our CSV has the book name in both. Strip duplication when start and end
    // are in the same book.
    out[dateKey] = _formatTanakhRange(startRef, endRef);
  }
  return out;
}

String _formatTanakhRange(String start, String end) {
  final m1 = RegExp(r'^(.+?)\s+(\d+):(\d+)$').firstMatch(start);
  final m2 = RegExp(r'^(.+?)\s+(\d+):(\d+)$').firstMatch(end);
  if (m1 == null || m2 == null) return '$start-$end';
  final book1 = m1.group(1);
  final book2 = m2.group(1);
  final chapter1 = m1.group(2);
  final chapter2 = m2.group(2);
  if (book1 == book2 && chapter1 == chapter2) {
    // Same chapter — keep just the verse range.
    return '$book1 $chapter1:${m1.group(3)}-${m2.group(3)}';
  }
  if (book1 == book2) {
    // Same book, different chapters.
    return '$book1 $chapter1:${m1.group(3)}-$chapter2:${m2.group(3)}';
  }
  return '$start-$end';
}

/// Yerushalmi_Yomi_Cal_-_Sheet1.csv — `M/D/YYYY,DayAbbr,Hebrew Date,Daf Label`
/// Daf label looks like "Berakhot 1" which the seed engine will use to
/// resolve to a Sefaria ref like `Jerusalem Talmud Berakhot.1`.
Map<String, String> _parseYerushalmiYomi() {
  final lines = File(
    '$_csvDir/Yerushalmi_Yomi_Cal_-_Sheet1.csv',
  ).readAsLinesSync();
  final out = <String, String>{};
  for (final line in lines) {
    if (line.isEmpty) continue;
    final cells = _splitCsv(line);
    if (cells.length < 4) continue;
    final dateKey = _normalizeUsDate(cells[0]);
    if (dateKey == null) continue;
    final daf = cells[3].trim();
    if (daf.isEmpty) continue;
    out[dateKey] = 'Jerusalem Talmud $daf';
  }
  return out;
}

// ── Helpers ──────────────────────────────────────────────────────────────

List<String> _splitCsv(String line) {
  // Sefaria CSVs don't quote fields, so plain split is fine.
  return line.split(',');
}

/// Parse "M/D/YYYY" (American). Returns null on bad input. Strict on
/// month/day ranges so a D/M file doesn't silently produce a wrapped date.
String? _normalizeUsDate(String raw) {
  return _normalizeSlashDate(raw, dayFirst: false);
}

/// Parse "D/M/YYYY" (European). Used by the Tanakh Yomi CSV which is in this
/// format despite Sefaria's other calendars using M/D.
String? _normalizeEuDate(String raw) {
  return _normalizeSlashDate(raw, dayFirst: true);
}

String? _normalizeSlashDate(String raw, {required bool dayFirst}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
  if (m == null) return null;
  final a = int.parse(m.group(1)!);
  final b = int.parse(m.group(2)!);
  final yyyy = m.group(3)!;
  final dd = dayFirst ? a : b;
  final mm = dayFirst ? b : a;
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
  return '$yyyy-${mm.toString().padLeft(2, '0')}-'
      '${dd.toString().padLeft(2, '0')}';
}

String _dotToSpaceColonAfterSection(
  String ref, {
  required String sectionPrefix,
}) {
  if (!ref.startsWith(sectionPrefix)) return ref;
  final tail = ref.substring(sectionPrefix.length);
  // Tail is e.g. "Orach Chaim.1.1-8". Replace the FIRST dot after the section
  // name with a space, then any remaining dots with ':'.
  final firstDot = tail.indexOf('.');
  if (firstDot == -1) return ref;
  final sectionName = tail.substring(0, firstDot);
  final rest = tail.substring(firstDot + 1).replaceAll('.', ':');
  return '$sectionPrefix$sectionName $rest';
}
