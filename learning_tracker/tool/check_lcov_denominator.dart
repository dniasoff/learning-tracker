/// R6 coverage-denominator guard — flake & CI-trust gate
/// (`docs/test-artifacts/reassurance-plan.md` Surface 6, item (d)).
///
/// The `test` Makefile target's coverage floor (see `.github/workflows/ci.yml`,
/// "Assert coverage floor >= 60%") reads line coverage as a fraction of the
/// lines lcov actually SAW. A `lib/**.dart` file that is never imported by
/// any test-reachable code path never gets a `SF:` entry in
/// `coverage/lcov.info` at all — it doesn't show up as "0% covered", it
/// simply VANISHES from both the numerator and the denominator, so it costs
/// the percentage nothing. A file can sit at genuinely zero test coverage
/// forever and the 60% floor will never see it. This checker closes that
/// hole: every non-generated `lib/**.dart` file must have at least one `SF:`
/// entry in the lcov report, or be a already-tracked pre-existing gap.
///
/// Generated files are excluded from the file set the same way the `test`
/// Makefile target already excludes them from lcov.info itself
/// (`*.g.dart`, `*.freezed.dart`, `lib/l10n/app_localizations*.dart`) — they
/// are build output, not hand-written behavior to protect. `*.gr.dart`
/// (auto_route's generated route table) is deliberately NOT excluded here,
/// matching the Makefile's own lcov.info, which doesn't strip it either.
///
/// This is a RATCHET, not a full hard-fail — the same shape as
/// `tool/check_orphaned_screens.dart` / `tool/check_test_mirroring.dart`: the
/// pre-existing backlog of already-invisible files is tracked in
/// [_baselinePath] (generated via `--update-baseline`) and tolerated. The
/// gate only fails when a NEW file vanishes from the denominator that isn't
/// already in the tracked baseline — burn the backlog down over time by
/// adding a real test that imports/exercises the file (directly or
/// transitively) and re-running `--update-baseline`, never by adding an
/// entry to paper over a new gap.
///
/// Soft-skips (exits 0 with a notice, does not fail the gate) when
/// `coverage/lcov.info` doesn't exist — running the full coverage suite is
/// `make test`'s job, not `make audit`'s; a dev running `make audit` alone
/// without ever having run `make test` should not be blocked by a stale/
/// absent coverage report. Pass `--strict` (used by CI, right after the
/// coverage-generating step) to instead hard-fail when the lcov file is
/// missing — there, its absence itself means the gate never ran.
///
/// Usage (from `learning_tracker/`, after `flutter test --coverage` or
/// `make test` has produced `coverage/lcov.info`):
///   dart run tool/check_lcov_denominator.dart                 # ratchet check (soft-skip if lcov missing)
///   dart run tool/check_lcov_denominator.dart --strict         # ratchet check (hard-fail if lcov missing)
///   dart run tool/check_lcov_denominator.dart --report         # list ALL currently-missing files, exit 0
///   dart run tool/check_lcov_denominator.dart --update-baseline
///   dart run tool/check_lcov_denominator.dart --root <path> --lcov <path> --baseline <path>
///     # test-only: point at a fixture root/lcov/baseline instead of the real ones
///
/// Exit codes (ratchet mode):
///   0 — no NEW zero-coverage file outside the tracked baseline (or lcov.info
///       absent and --strict was not passed)
///   1 — one or more NEW zero-coverage files found (prints them), or
///       --strict was passed and lcov.info is missing
library;

import 'dart:io';

/// Baseline of already-known zero-coverage (denominator-invisible) files.
const _baselinePath = 'tool/lcov_denominator_baseline.txt';

/// Generated files excluded from the file set — mirrors exactly what the
/// `test` Makefile target strips from lcov.info itself (AUD-t-cross-16 /
/// AUD-t-cross-44) so this checker never flags a file nobody expects to
/// appear in the denominator in the first place. `*.gr.dart` is
/// deliberately NOT here — the Makefile doesn't strip it either.
bool _isExcluded(String libRelativePath) {
  if (libRelativePath.endsWith('.g.dart')) return true;
  if (libRelativePath.endsWith('.freezed.dart')) return true;
  if (libRelativePath.startsWith('lib/l10n/app_localizations') &&
      libRelativePath.endsWith('.dart')) {
    return true;
  }
  return false;
}

/// Every non-generated `lib/**.dart` file under `$root/lib`, as a path
/// relative to [root] (e.g. `lib/core/foo.dart`).
List<String> _allLibFiles(String root) {
  final libDir = Directory('$root/lib');
  if (!libDir.existsSync()) return const [];
  final files = <String>[];
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final full = entity.path.replaceAll(r'\', '/');
    if (!full.endsWith('.dart')) continue;
    final relPath = full.substring(root.length + 1); // strip "$root/"
    if (_isExcluded(relPath)) continue;
    files.add(relPath);
  }
  files.sort();
  return files;
}

/// Every path named by an `SF:` line in an lcov.info file, normalized to
/// forward slashes. lcov's `SF:` paths are written relative to the working
/// directory `flutter test --coverage` ran from (`learning_tracker/`), i.e.
/// already in the same `lib/...` form [_allLibFiles] produces.
Set<String> _lcovSourceFiles(File lcovFile) {
  final covered = <String>{};
  for (final line in lcovFile.readAsLinesSync()) {
    if (!line.startsWith('SF:')) continue;
    covered.add(line.substring('SF:'.length).trim().replaceAll(r'\', '/'));
  }
  return covered;
}

Set<String> _readBaseline(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

void _writeBaseline(String path, List<String> entries) {
  final buffer = StringBuffer()
    ..writeln('# R6 lcov-denominator baseline — generated by')
    ..writeln('# tool/check_lcov_denominator.dart --update-baseline.')
    ..writeln(
      '# Pre-existing backlog of lib/**.dart files with ZERO `SF:` entries in',
    )
    ..writeln(
      '# coverage/lcov.info — i.e. files invisible to both the numerator AND',
    )
    ..writeln(
      '# the denominator of the 60% coverage floor, not merely "0% covered".',
    )
    ..writeln(
      '# A new file NOT listed here fails `make audit` (or the CI --strict',
    )
    ..writeln(
      '# step). Burn this list down over time by adding a test that imports/',
    )
    ..writeln('# exercises the file (directly or transitively) and re-running')
    ..writeln('# --update-baseline — do NOT add fresh entries to paper over a')
    ..writeln('# new gap.');
  for (final entry in entries) {
    buffer.writeln(entry);
  }
  File(path).writeAsStringSync(buffer.toString());
}

String _flagValue(List<String> args, String flag, String fallback) {
  final i = args.indexOf(flag);
  return (i != -1 && i + 1 < args.length) ? args[i + 1] : fallback;
}

void main(List<String> args) {
  final root = _flagValue(args, '--root', '.');
  final lcovPath = _flagValue(args, '--lcov', 'coverage/lcov.info');
  final baselinePath = _flagValue(args, '--baseline', _baselinePath);
  final report = args.contains('--report');
  final updateBaseline = args.contains('--update-baseline');
  final strict = args.contains('--strict');

  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    if (strict) {
      stderr.writeln(
        'R6 lcov-denominator check FAILED (--strict): $lcovPath not found. '
        'Run `flutter test --coverage` (or `make test`) first so this gate '
        'has real data to check.',
      );
      exit(1);
    }
    stdout.writeln(
      'R6 lcov-denominator check SKIPPED: $lcovPath not found (run '
      '`make test` first for full enforcement — this is not a failure of '
      '`make audit` alone).',
    );
    return;
  }

  final allFiles = _allLibFiles(root);
  final covered = _lcovSourceFiles(lcovFile);
  final missing = allFiles.where((f) => !covered.contains(f)).toList()..sort();

  if (report) {
    for (final m in missing) {
      stdout.writeln(m);
    }
    stdout.writeln(
      '--- ${missing.length} lib/ file(s) absent from the lcov denominator',
    );
    return;
  }

  if (updateBaseline) {
    _writeBaseline(baselinePath, missing);
    stdout.writeln(
      'Baseline updated: ${missing.length} zero-coverage file(s) recorded '
      'in $baselinePath',
    );
    return;
  }

  final baseline = _readBaseline(baselinePath);
  final newViolations = missing.toSet().difference(baseline).toList()..sort();

  if (newViolations.isNotEmpty) {
    stderr.writeln(
      'R6 lcov-denominator check FAILED — the following lib/ file(s) have '
      'NO `SF:` entry anywhere in $lcovPath (never imported by any '
      'test-reachable code path, so they cost the 60% coverage floor '
      'nothing at all rather than dragging it down):',
    );
    for (final v in newViolations) {
      stderr.writeln('  $v');
    }
    stderr.writeln(
      '\nAdd a test that imports/exercises the file above (directly or '
      'transitively), OR if this is a deliberate, reviewed addition to the '
      'tracked backlog, regenerate the baseline with `dart run '
      'tool/check_lcov_denominator.dart --update-baseline` (only after team '
      'sign-off — this widens the ratchet).',
    );
    exit(1);
  }

  stdout.writeln(
    'R6 lcov-denominator check OK: ${missing.length} zero-coverage file(s), '
    'all within the tracked baseline (0 new violations).',
  );
}
