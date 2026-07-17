/// Rule-0 checker — no `.gitkeep` placeholder in a non-empty `lib/`
/// directory, anywhere in the tree (AUD-core-constants-02, AC1: "flags
/// ANY .gitkeep whose directory contains another tracked file").
///
/// A `.gitkeep` file exists only to make git track an otherwise-empty
/// directory (git does not track empty directories at all). Once a
/// directory holds another git-tracked file, the `.gitkeep` no longer
/// serves that purpose and is pure repo-hygiene noise in `git status`/
/// `find` output. AUD-core-constants-02's own evidence site,
/// `lib/core/constants/.gitkeep`, sat alongside 3 real source files
/// (`app_constants.dart`, `curriculum_defaults.dart`, `hebrew_terms.dart`)
/// the whole time it existed in this repo.
///
/// This checker deliberately keys off `git ls-files` (tracked files), not
/// a raw filesystem listing — the finding's acceptance criterion is "any
/// `.gitkeep` whose directory contains another **tracked** file", and a
/// filesystem-only scan would also flag directories that hold only
/// gitignored/generated content, where the `.gitkeep` still does its job.
/// A directory that holds ONLY a `.gitkeep` (genuinely empty otherwise) is
/// never flagged — the `.gitkeep` is load-bearing there.
///
/// This checker's own first run surfaced the same redundant-`.gitkeep`
/// pattern in 47 other `lib/` directories, independently of
/// AUD-core-constants-02's single named evidence site (that finding's own
/// `why` field calls this out explicitly as "an informal repo-wide grep
/// ... context only, not a full audit"). Those 47 have since been cleaned
/// up (their `.gitkeep`s deleted; the directories stay tracked via their
/// other files), so this checker now enforces AC1 literally: it flags ANY
/// redundant `.gitkeep`, tolerating none. There is deliberately no
/// baseline/exemption set — unlike the ratchet shape used by
/// `tool/check_notifications_duplicate_test_classes.dart` (AUD-t-
/// notifications-03) and `tool/check_test_mirroring.dart` (AG-5), this
/// finding's AC does not say "no NEW violations"; it says "any". Do not
/// reintroduce a baseline/exemption set to paper over a new violation —
/// delete the offending `.gitkeep` instead.
///
/// Usage:
///   dart run tool/check_gitkeep_stray.dart
///   dart run tool/check_gitkeep_stray.dart --root <path>   # test-only: run
///     `git ls-files lib` against an arbitrary git working tree instead of
///     the current directory, so the regression test
///     (test/tool/check_gitkeep_stray_test.dart) can exercise a
///     deliberately-broken fixture in a disposable temp repo without
///     touching this repo's real git index.
///
/// Exit codes:
///   0 — no `lib/` directory carries both a `.gitkeep` and another
///       git-tracked file
///   1 — one or more directories violate that (prints the offending
///       directories)
library;

import 'dart:io';

void main(List<String> args) {
  final rootIndex = args.indexOf('--root');
  final root = (rootIndex != -1 && rootIndex + 1 < args.length)
      ? args[rootIndex + 1]
      : '.';

  final result = Process.runSync('git', ['-C', root, 'ls-files', 'lib']);
  if (result.exitCode != 0) {
    stderr.writeln(
      'ERROR: `git -C $root ls-files lib` failed: '
      '${result.stderr}',
    );
    exit(2);
  }

  final byDir = <String, List<String>>{};
  for (final rawLine in (result.stdout as String).split('\n')) {
    final path = rawLine.trim();
    if (path.isEmpty) continue;
    final lastSlash = path.lastIndexOf('/');
    final dir = lastSlash == -1 ? '' : path.substring(0, lastSlash);
    byDir.putIfAbsent(dir, () => []).add(path);
  }

  final violations = <String>[];
  byDir.forEach((dir, files) {
    final hasGitkeep = files.any((f) => f.endsWith('/.gitkeep'));
    final hasOtherTrackedFile = files.any((f) => !f.endsWith('/.gitkeep'));
    if (hasGitkeep && hasOtherTrackedFile) {
      violations.add(dir);
    }
  });
  violations.sort();

  if (violations.isNotEmpty) {
    stderr.writeln(
      'Stray .gitkeep check FAILED (AUD-core-constants-02) — the following '
      'lib/ directories carry a .gitkeep placeholder alongside another '
      'git-tracked file. A .gitkeep exists only to make git track an '
      'otherwise-empty directory; once real files land, it is pure noise. '
      'Delete it:',
    );
    for (final v in violations) {
      stderr.writeln('  $v/.gitkeep');
    }
    exit(1);
  }

  stdout.writeln(
    'Stray .gitkeep check passed — no lib/ directory carries a .gitkeep '
    'alongside another git-tracked file.',
  );
}
