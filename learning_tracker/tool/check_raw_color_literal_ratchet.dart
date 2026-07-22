/// Run-9 systemic-guard checker — raw brightness-blind color literal
/// ratchet (device-audit-run9).
///
/// `docs/test-artifacts/device-audit-run9/_REPORT.md`'s dominant finding
/// (10 of 10 confirmed P1s, 6/6 devices, ~15 distinct widgets — "White-
/// surface / brightness-blind literal cluster") is ONE bug repeated: a raw
/// `Colors.white` / `Colors.black` (or its exact hex twin,
/// `Color(0xFFFFFFFF)` / `Color(0xFF000000)`) used as a foreground/surface
/// color in presentation code. The brightness-aware palette migration
/// (`5f1e71f5`, `lib/core/theme/app_palette.dart`) rewrote every
/// `AppColors.*`/`AppTheme.*` reference it could see, but a raw `Colors.*`
/// literal is structurally invisible to a find/replace over symbol names —
/// it never resolves through the palette, so it renders identically in
/// light and dark, producing near-invisible text the moment its sibling
/// surface/ink DOES flip (measured on-device as low as 1.03:1 and 1.07:1
/// contrast against a 4.5:1 AA floor).
///
/// The pre-existing guard, `test/core/widgets/aud_core_widgets_03_no_color_literals_test.dart`
/// (AUD-core-widgets-03), only greps `Color(0x…)` hex under
/// `lib/core/widgets/` — it hard-fails on ANY hex literal there, but a
/// NAMED constant like `Colors.white` slips through untouched (run-9's own
/// root-cause note: "the audit guard … only greps `Color(0x…)` hex, so a
/// named `Colors.*` constant passes"), and its scope is one directory, not
/// the wider presentation surface where every run-9 hit actually lives
/// (`lib/features/**/presentation/`, `lib/app/`). This checker closes both
/// gaps: it scans `lib/features/**/presentation/**`, `lib/app/**`, and
/// `lib/core/widgets/**` for `Colors.white`/`Colors.black` (and their
/// numbered-opacity siblings — `white10/12/24/30/38/54/60/70`,
/// `black12/26/38/45/54/87`) plus the exact hex twins `Color(0xFFFFFFFF)`/
/// `Color(0xFF000000)` in any letter-case.
///
/// This is a RATCHET, not a hard zero-tolerance gate — the same shape as
/// `tool/check_tq3_pump_app_migration.dart` (AUD-t-profiles-02) and
/// `tool/check_sm7_learning_program_singleton.dart` (AUD-scheduler-23): the
/// backlog is tracked as a baseline COUNT in [_baselinePath], and the gate
/// fails only on growth above it. Two reasons a hard zero-tolerance gate
/// was NOT chosen, both stated plainly rather than silently baked in:
///   1. Run-9's cluster (~15 widgets) is the actively-worked sibling fix
///      (`reassurance/run9-darkmode-legibility`) — this checker's job is to
///      stop the count from growing again, not to block on a backlog this
///      task did not itself introduce.
///   2. A "white text on an intentionally-always-saturated brand button"
///      call site (e.g. a destructive red button whose background never
///      changes with brightness, so white foreground text is legitimately
///      always correct) is a real, non-buggy use of `Colors.white` that
///      this checker cannot reliably distinguish from a buggy card/surface
///      literal by regex alone — that would need to resolve the enclosing
///      widget's background color, which is beyond a text-based scan. Per
///      the run-9 follow-up brief: "if you cannot distinguish reliably,
///      baseline them and say so" — every such site, if any exist in the
///      current count, is baselined here rather than guessed at.
///
/// Baseline provenance: pinned to today's (2026-07-22) occurrence count on
/// `dev` tip — the sibling cluster-fix branch
/// (`reassurance/run9-darkmode-legibility`) had NOT yet landed any commits
/// at the time this checker was authored (`git diff dev...` was empty), so
/// there was nothing to pin the "after the ~15-widget fix" count to. Once
/// that branch merges, re-run `--update-baseline` to lock the lower count
/// in — do not leave this baseline sitting above the true remaining
/// backlog.
///
/// Usage:
///   dart run tool/check_raw_color_literal_ratchet.dart            # ratchet check
///   dart run tool/check_raw_color_literal_ratchet.dart --report    # list matching file:line hits, exit 0
///   dart run tool/check_raw_color_literal_ratchet.dart --update-baseline
///
/// Exit codes (ratchet mode):
///   0 — occurrence count is at or below the tracked baseline
///   1 — occurrence count exceeds the tracked baseline (prints the delta)
library;

import 'dart:io';

/// Baseline occurrence count (the pre-existing, not-yet-fixed run-9
/// white-surface/hero-fill backlog, plus any legitimate-but-indistinguishable
/// white-on-saturated-brand-button sites — see the class doc above).
/// Maintainers burn this down by migrating a call site onto
/// `context.colors.*` and re-running with `--update-baseline`; the ratchet
/// then locks the new, smaller count. Re-pin lower once
/// `reassurance/run9-darkmode-legibility` merges.
const _baselinePath = 'tool/raw_color_literal_ratchet_baseline.txt';

/// `Colors.white` and its numbered-opacity siblings (Flutter's `Colors`
/// class defines exactly these: white, white10, white12, white24, white30,
/// white38, white54, white60, white70).
final _colorsWhite = RegExp(r'\bColors\.white(?:10|12|24|30|38|54|60|70)?\b');

/// `Colors.black` and its numbered-opacity siblings (black, black12,
/// black26, black38, black45, black54, black87).
final _colorsBlack = RegExp(r'\bColors\.black(?:12|26|38|45|54|87)?\b');

/// `Color(0xFFFFFFFF)` in any letter-case — the exact hex twin of
/// `Colors.white`, just as brightness-blind.
final _hexWhite = RegExp(r'Color\(0x[fF]{2}[fF]{6}\)');

/// `Color(0xFF000000)` in any letter-case — the exact hex twin of
/// `Colors.black`.
final _hexBlack = RegExp(r'Color\(0x[fF]{2}0{6}\)');

/// True if [relPath] (posix-style, relative to `learning_tracker/`) falls
/// under this checker's scanned surface: `lib/app/**`, `lib/core/widgets/**`,
/// or `lib/features/**/presentation/**`. Generated files are excluded —
/// they are never hand-authored, so a raw literal there can't be "fixed" by
/// a human editing this codebase. `lib/core/theme/` (where the palette
/// itself legitimately defines these constants) is structurally outside
/// all three scanned roots, so no separate exclusion is needed for it.
bool _inScope(String relPath) {
  if (relPath.endsWith('.g.dart') || relPath.endsWith('.freezed.dart')) {
    return false;
  }
  if (relPath.startsWith('lib/app/')) return true;
  if (relPath.startsWith('lib/core/widgets/')) return true;
  if (relPath.startsWith('lib/features/') &&
      relPath.contains('/presentation/')) {
    return true;
  }
  return false;
}

/// One `file:line: <matched text>` string per hit in [content].
List<String> _hitsIn(String path, String content) {
  final hits = <String>[];
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final pattern in [_colorsWhite, _colorsBlack, _hexWhite, _hexBlack]) {
      for (final match in pattern.allMatches(line)) {
        hits.add('$path:${i + 1}: ${match.group(0)}');
      }
    }
  }
  return hits;
}

List<String> _scan() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    stderr.writeln('ERROR: lib/ not found — run from learning_tracker/.');
    exit(2);
  }

  final dartFiles =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where(_inScope)
          .toList()
        ..sort();

  final hits = <String>[];
  for (final path in dartFiles) {
    hits.addAll(_hitsIn(path, File(path).readAsStringSync()));
  }
  return hits;
}

int _readBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) return 0;
  final dataLine = file.readAsLinesSync().firstWhere(
    (l) => l.trim().isNotEmpty && !l.trim().startsWith('#'),
    orElse: () => '0',
  );
  return int.tryParse(dataLine.trim()) ?? 0;
}

void main(List<String> args) {
  final hits = _scan();

  if (args.contains('--report')) {
    hits.forEach(stdout.writeln);
    stdout.writeln(
      '${hits.length} raw Colors.white/Colors.black/hex-twin occurrence(s) '
      'under lib/app, lib/core/widgets, lib/features/**/presentation/.',
    );
    return;
  }

  if (args.contains('--update-baseline')) {
    File(_baselinePath).writeAsStringSync(
      '# Run-9 raw color literal ratchet baseline — generated by\n'
      '# tool/check_raw_color_literal_ratchet.dart --update-baseline.\n'
      '# Tracks the count of raw Colors.white/Colors.black (+ numbered-\n'
      '# opacity siblings) and Color(0xFFFFFFFF)/Color(0xFF000000) hex twins\n'
      '# under lib/app/, lib/core/widgets/, and lib/features/**/presentation/\n'
      '# — brightness-blind literals that bypass the AppPalette migration\n'
      '# (device-audit-run9, ~15-widget white-surface cluster).\n'
      '# Lower this only by migrating a call site onto context.colors.* — do\n'
      '# NOT raise it to paper over a new raw literal.\n'
      '${hits.length}\n',
    );
    stdout.writeln('Baseline updated to ${hits.length}.');
    return;
  }

  final baseline = _readBaseline();
  if (hits.length > baseline) {
    stderr.writeln(
      'Raw color literal ratchet FAILED (device-audit-run9) — '
      '${hits.length} raw Colors.white/Colors.black/hex-twin occurrence(s) '
      'found under lib/app/, lib/core/widgets/, lib/features/**/presentation/, '
      'up from the tracked baseline of $baseline. A raw Colors.white / '
      'Colors.black / Color(0xFFFFFFFF) / Color(0xFF000000) literal bypasses '
      'the brightness-aware AppPalette and renders identically in light and '
      'dark — this is the exact defect class that produced run-9\'s 10 '
      'confirmed P1 dark-mode legibility findings (measured as low as '
      '1.03:1 contrast). Route the new call site through context.colors.* '
      'instead. If you deliberately migrated call site(s) OFF a raw literal '
      'and lowered the count, re-run with --update-baseline to lock the '
      'win in.\n\nNew/changed hit(s) (see --report for the full list):',
    );
    hits.forEach(stderr.writeln);
    exit(1);
  }

  stdout.writeln(
    'Raw color literal ratchet passed — ${hits.length} occurrence(s) under '
    'lib/app/, lib/core/widgets/, lib/features/**/presentation/ (tracked '
    'baseline: $baseline).',
  );
}
