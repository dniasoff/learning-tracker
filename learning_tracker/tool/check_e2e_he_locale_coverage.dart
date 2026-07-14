/// AUD-t-cross-31 Rule-0 checker — dims=he catalog rows vs. actual
/// `Locale('he')` usage in the matching *_test.dart journey.
///
/// AUD-t-cross-31 found three E2E journeys (E2E-516, E2E-922, E2E-416)
/// catalogued in docs/planning/e2e-test-suite-plan.md with `dims: he`
/// (meaning: this journey MUST run under the Hebrew MaterialApp locale) that
/// instead pumped the default `en` locale — two of them via comments falsely
/// claiming `E2EHarness.pumpApp` "hardcodes" or "cannot override" the
/// locale, when `pumpApp(locale:)` has been injectable since commit
/// 9c9655ed. Its acceptance criterion names this checker: "A grep-based
/// checker cross-referencing docs/planning/e2e-test-suite-plan.md rows
/// tagged dims=he against Locale('he') usage in the matching *_test.dart
/// file returns zero mismatches."
///
/// Method:
///   1. Parse every `| E2E-XXX | ... |` catalog row whose `dims` column is
///      exactly `he`.
///   2. Locate that id's block in test/e2e/journeys/*.dart via the file's
///      own `// ── E2E-XXX ──` section-marker convention (used throughout
///      this suite — see e.g. scheduler_p1_test.dart, tracks_p1_test.dart).
///      A block runs from its marker to the next `// ── E2E-` marker (or
///      EOF). When no marker exists for an id (a handful of ids are folded
///      into a cross-cutting sweep test instead of getting their own
///      section — e.g. E2E-1512's overflow sweep), fall back to scanning the
///      id's WHOLE containing file (found via a plain substring match)
///      rather than reporting a false "missing" mismatch.
///   3. A block/file "uses he locale" when it contains a direct
///      `Locale('he')` / `Locale("he")` literal, OR a `locale: <ident>`
///      reference to a file-level constant itself assigned
///      `(const )?Locale('he')` (the `_he` alias pattern hebrew_rtl_p1_test
///      .dart and overflow_sweep_p2_test.dart use).
///   4. Any dims=he catalog row whose id cannot be found in ANY journey file,
///      or whose located block/file shows no he-locale usage, is a mismatch.
///
/// Usage:
///   dart run tool/check_e2e_he_locale_coverage.dart
///
/// Exit codes:
///   0 — every dims=he catalog row has a matching Locale('he') usage
///   1 — one or more mismatches (prints the offending ids)
library;

import 'dart:io';

final _catalogRow = RegExp(r'^\|\s*(E2E-\d+)\s*\|(.*)\|$');
final _sectionMarker = RegExp(r'//\s*──\s*(E2E-\d+)\s*──');
final _heLocaleLiteral = RegExp(r'''Locale\(\s*['"]he['"]\s*\)''');
final _heAliasDecl = RegExp(
  r'''(_?[A-Za-z][A-Za-z0-9]*)\s*=\s*(?:const\s+)?Locale\(\s*['"]he['"]\s*\)''',
);
final _localeRef = RegExp(r'locale:\s*([A-Za-z_][A-Za-z0-9_]*)');

/// Strips `//`-to-end-of-line comments from [text] so a comment merely
/// MENTIONING `Locale('he')` (documentation, a stale "this used to hardcode
/// en" note, ...) cannot masquerade as an actual code usage. Deliberately
/// simple (no string-literal awareness) — good enough for this suite's
/// style, where `//` inside a string literal essentially never occurs.
String _stripLineComments(String text) {
  final buffer = StringBuffer();
  for (final line in text.split('\n')) {
    final idx = line.indexOf('//');
    buffer.writeln(idx == -1 ? line : line.substring(0, idx));
  }
  return buffer.toString();
}

/// Extracts the `dims` column (6th `|`-delimited field, 1-indexed after the
/// leading empty split) from a catalog row's tail (everything after the id).
String? _dimsColumn(String rowTail) {
  final cols = rowTail.split('|');
  // rowTail = " name | P | modes | dims | key assertions | seed/pre "
  // cols:      [0]=name [1]=P [2]=modes [3]=dims [4]=assertions [5]=seed
  if (cols.length < 4) return null;
  return cols[3].trim();
}

void main() {
  final catalogFile = File('../docs/planning/e2e-test-suite-plan.md');
  if (!catalogFile.existsSync()) {
    stderr.writeln(
      'ERROR: docs/planning/e2e-test-suite-plan.md not found — run from '
      'learning_tracker/.',
    );
    exit(1);
  }

  final heIds = <String>[];
  for (final line in catalogFile.readAsLinesSync()) {
    final m = _catalogRow.firstMatch(line);
    if (m == null) continue;
    final id = m.group(1)!;
    final dims = _dimsColumn(m.group(2)!);
    if (dims == 'he') heIds.add(id);
  }

  if (heIds.isEmpty) {
    stderr.writeln(
      'ERROR: parsed zero dims=he rows from the catalog — the table format '
      'likely changed; update tool/check_e2e_he_locale_coverage.dart\'s '
      '_catalogRow / _dimsColumn parsing.',
    );
    exit(1);
  }

  final journeysDir = Directory('test/e2e/journeys');
  final journeyFiles =
      journeysDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final mismatches = <String>[];

  for (final id in heIds) {
    String? matchedFile;
    var scanRegion = '';

    for (final file in journeyFiles) {
      final content = file.readAsStringSync();
      if (!content.contains(id)) continue;
      matchedFile = file.path;

      // Find this id's section marker and slice to the next marker (or EOF).
      final markers = _sectionMarker.allMatches(content).toList();
      final ownMarker = markers.where((m) => m.group(1) == id).toList();
      if (ownMarker.isNotEmpty) {
        final start = ownMarker.first.end;
        final laterStarts = markers.map((m) => m.start).where((s) => s > start);
        final end = laterStarts.isEmpty
            ? content.length
            : laterStarts.reduce((a, b) => a < b ? a : b);
        scanRegion = content.substring(start, end);
      } else {
        // No per-id section marker (cross-cutting sweep test, e.g.
        // E2E-1512) — scan the whole file instead of declaring "missing".
        scanRegion = content;
      }
      break;
    }

    if (matchedFile == null) {
      mismatches.add(
        '$id — dims=he in the catalog but no test/e2e/journeys/*.dart file '
        'mentions this id at all',
      );
      continue;
    }

    // Code-only view (comments stripped) — a comment merely MENTIONING
    // Locale('he') must not satisfy the check; only real usage counts.
    final codeOnlyScanRegion = _stripLineComments(scanRegion);

    final hasDirectLiteral = _heLocaleLiteral.hasMatch(codeOnlyScanRegion);
    var hasAliasUsage = false;
    if (!hasDirectLiteral) {
      // Resolve `locale: someIdent` references against file-level aliases
      // assigned `(const )?Locale('he')` anywhere in the SAME file (aliases
      // are typically declared once near the top, outside any one id's
      // block).
      final codeOnlyFileContent = _stripLineComments(
        File(matchedFile).readAsStringSync(),
      );
      final heAliases = _heAliasDecl
          .allMatches(codeOnlyFileContent)
          .map((m) => m.group(1)!)
          .toSet();
      if (heAliases.isNotEmpty) {
        for (final refMatch in _localeRef.allMatches(codeOnlyScanRegion)) {
          if (heAliases.contains(refMatch.group(1))) {
            hasAliasUsage = true;
            break;
          }
        }
      }
    }

    if (!hasDirectLiteral && !hasAliasUsage) {
      mismatches.add(
        '$id — dims=he in the catalog but $matchedFile has no '
        "Locale('he') usage (direct or via a file-level he-locale alias) "
        'in its section',
      );
    }
  }

  if (mismatches.isNotEmpty) {
    stderr.writeln(
      'E2E dims=he locale-coverage check FAILED — the following catalog '
      'rows are tagged dims=he but their journey does not actually pump '
      "Locale('he') (AUD-t-cross-31):",
    );
    for (final m in mismatches) {
      stderr.writeln('  $m');
    }
    exit(1);
  }

  stdout.writeln(
    'E2E dims=he locale-coverage check passed — all ${heIds.length} '
    "catalog rows tagged dims=he have a matching Locale('he') usage in "
    'their journey file.',
  );
}
