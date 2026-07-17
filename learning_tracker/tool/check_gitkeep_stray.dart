/// Rule-0 checker — no stray `.gitkeep` placeholder in a non-empty `lib/`
/// directory (AUD-core-constants-02).
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
///
/// This checker's own first run surfaced the same pattern in 47 other
/// `lib/` directories, independently of AUD-core-constants-02's single
/// named evidence site (that finding's own `why` field calls this out
/// explicitly as "an informal repo-wide grep ... context only, not a full
/// audit"). Cleaning up that wider backlog is out of THIS finding's scope
/// — a drive-by, not this finding's job — so it is tolerated via
/// [_baseline], the same ratchet shape as
/// `tool/check_notifications_duplicate_test_classes.dart` (AUD-t-
/// notifications-03) and `tool/check_test_mirroring.dart` (AG-5). The gate
/// fails only on a NEW stray `.gitkeep` outside that tracked list, or on
/// `lib/core/constants` regressing back to having one. Shrink [_baseline]
/// as each directory's stale `.gitkeep` is deleted.
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
///   0 — no non-baselined `lib/` directory carries both a `.gitkeep` and
///       another git-tracked file
///   1 — one or more directories violate that outside [_baseline] (prints
///       the offending directories)
library;

import 'dart:io';

/// Pre-existing backlog this checker tolerates — discovered by this
/// checker's own first run, out of AUD-core-constants-02's named scope
/// (that finding names only `lib/core/constants/.gitkeep`). Never add to
/// this set to paper over a NEW violation; shrink it as directories are
/// cleaned up.
const _baseline = <String>{
  'lib/app/bootstrap',
  'lib/app/restore',
  'lib/app/router',
  'lib/app/sync_runtime',
  'lib/core/database/daos',
  'lib/core/logging',
  'lib/core/theme',
  'lib/features/account/data/repositories',
  'lib/features/account/domain/repositories',
  'lib/features/account/presentation/providers',
  'lib/features/account/presentation/screens',
  'lib/features/account/presentation/widgets',
  'lib/features/content_browsing/data/repositories',
  'lib/features/content_browsing/domain/repositories',
  'lib/features/content_browsing/presentation/providers',
  'lib/features/content_browsing/presentation/screens',
  'lib/features/content_browsing/presentation/widgets',
  'lib/features/gamification/presentation/providers',
  'lib/features/gamification/presentation/screens',
  'lib/features/gamification/presentation/widgets',
  'lib/features/learning/data/repositories',
  'lib/features/learning/domain/entities',
  'lib/features/learning/domain/repositories',
  'lib/features/learning/domain/use_cases',
  'lib/features/learning/presentation/providers',
  'lib/features/learning/presentation/screens',
  'lib/features/notifications/domain/repositories',
  'lib/features/notifications/presentation/providers',
  'lib/features/notifications/presentation/screens',
  'lib/features/notifications/presentation/widgets',
  'lib/features/onboarding/presentation/providers',
  'lib/features/onboarding/presentation/screens',
  'lib/features/onboarding/presentation/widgets',
  'lib/features/progress/data/repositories',
  'lib/features/progress/domain/repositories',
  'lib/features/progress/presentation/providers',
  'lib/features/progress/presentation/screens',
  'lib/features/progress/presentation/widgets',
  'lib/features/scheduler/data/repositories',
  'lib/features/scheduler/domain/repositories',
  'lib/features/scheduler/presentation/providers',
  'lib/features/scheduler/presentation/screens',
  'lib/features/scheduler/presentation/widgets',
  'lib/features/settings/presentation/providers',
  'lib/features/settings/presentation/screens',
  'lib/features/settings/presentation/widgets',
  'lib/features/sync/presentation/providers',
};

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
    if (hasGitkeep && hasOtherTrackedFile && !_baseline.contains(dir)) {
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
    'Stray .gitkeep check passed — no non-baselined lib/ directory carries '
    'a .gitkeep alongside another git-tracked file '
    '(${_baseline.length} pre-existing baselined director${_baseline.length == 1 ? 'y' : 'ies'} tolerated).',
  );
}
