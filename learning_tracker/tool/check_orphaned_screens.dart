/// Rule-0/AG-6 companion checker — no orphaned (unreachable) screen widget
/// (AUD-settings-08, acceptance_criteria[0]: "before this screen is wired
/// into app_router.dart, a check confirms every non-generated screen file
/// has at least one route/Navigator.push call site (flagging orphaned
/// screens)").
///
/// A "screen file" is any non-generated `lib/**/*_screen.dart` — the
/// naming convention every screen in this codebase already follows (see
/// `find lib -name '*_screen.dart'`). For each top-level `class FooScreen`
/// declared in such a file, the class is considered "wired" (reachable)
/// when EITHER:
///   - the file carries an `@RoutePage(` annotation (the auto_route
///     registration marker — the same signal AUD-settings-08's own
///     evidence used to establish `ScopeSelectionScreen` was dead code); or
///   - the class name appears as a call site (`FooScreen(`) in some OTHER
///     `lib/` file — covering the many screens pushed manually via
///     `Navigator.push(MaterialPageRoute(builder: (_) => FooScreen(...)))`
///     or embedded inline as a step widget, rather than through the
///     declarative auto_route table.
///
/// A class satisfying neither is an orphan: finished widget code with no
/// path a user can reach it from. This deliberately does NOT resolve
/// `app_router.gr.dart` (auto_route's generated route table) — that file is
/// gitignored/regenerated and may not exist in a fresh checkout/worktree at
/// all (see `.gitignore`: `*.gr.dart`); keying off the `@RoutePage(`
/// annotation in the *source* file is the portable, generation-independent
/// equivalent.
///
/// This checker is a RATCHET, not a full hard-fail: today's one known
/// orphan (`ScopeSelectionScreen` — finished-but-unwired, tracked by
/// AUD-settings-08 pending a future navigation-entry-point finding) is
/// recorded in [_baselinePath] and tolerated. The gate only fails when a
/// NEW orphaned screen appears that is not already in the baseline — same
/// shape as `tool/check_test_mirroring.dart` (AG-5).
///
/// Usage:
///   dart run tool/check_orphaned_screens.dart                 # ratchet check
///   dart run tool/check_orphaned_screens.dart --report         # list ALL orphans, exit 0
///   dart run tool/check_orphaned_screens.dart --root <path>    # test-only: scan
///     an arbitrary directory's lib/ instead of the current one, so the
///     regression test (test/tool/check_orphaned_screens_test.dart) can
///     exercise deliberately-broken fixtures without touching this repo's
///     real screens.
///   dart run tool/check_orphaned_screens.dart --baseline <path> # test-only:
///     read the tracked baseline from an arbitrary file instead of
///     [_baselinePath].
///
/// Exit codes (ratchet mode):
///   0 — no NEW orphaned screen file outside the tracked baseline
///   1 — one or more NEW orphaned screens found (prints them)
library;

import 'dart:io';

/// Baseline of already-known orphaned screens (the pre-existing backlog).
const _baselinePath = 'tool/orphaned_screens_baseline.txt';

final _classPattern = RegExp(
  r'^class ([A-Za-z0-9_]+Screen)\b',
  multiLine: true,
);

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart');

List<File> _dartFilesUnder(String libDir) {
  final dir = Directory(libDir);
  if (!dir.existsSync()) return const [];
  return dir.listSync(recursive: true).whereType<File>().where((f) {
    final p = f.path.replaceAll(r'\', '/');
    return p.endsWith('.dart') && !_isGenerated(p);
  }).toList();
}

/// One `FooScreen (path/to/file.dart)` orphan record, formatted for both
/// the baseline file and stderr output.
String _record(String className, String relativePath) =>
    '$className ($relativePath)';

List<String> _findOrphans(String root) {
  final libRoot = '$root/lib';
  final allFiles = _dartFilesUnder(libRoot);
  final screenFiles = allFiles
      .where((f) => f.path.replaceAll(r'\', '/').endsWith('_screen.dart'))
      .toList();

  // Read every file's content once; re-used both as the screen-file source
  // and as a cross-reference search target.
  final contentByPath = <String, String>{
    for (final f in allFiles) f.path: f.readAsStringSync(),
  };

  final orphans = <String>[];
  for (final screenFile in screenFiles) {
    final content = contentByPath[screenFile.path]!;
    final hasRoutePage = content.contains('@RoutePage(');
    if (hasRoutePage) continue;

    final relPath = screenFile.path
        .replaceAll(r'\', '/')
        .substring(root.length + 1); // strip "<root>/"

    for (final match in _classPattern.allMatches(content)) {
      final className = match.group(1)!;
      final callSite = RegExp('\\b$className\\(');
      final referencedElsewhere = contentByPath.entries.any(
        (entry) =>
            entry.key != screenFile.path && callSite.hasMatch(entry.value),
      );
      if (!referencedElsewhere) {
        orphans.add(_record(className, relPath));
      }
    }
  }
  orphans.sort();
  return orphans;
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

void main(List<String> args) {
  final rootIndex = args.indexOf('--root');
  final root = (rootIndex != -1 && rootIndex + 1 < args.length)
      ? args[rootIndex + 1]
      : '.';
  final baselineIndex = args.indexOf('--baseline');
  final baselinePath = (baselineIndex != -1 && baselineIndex + 1 < args.length)
      ? args[baselineIndex + 1]
      : _baselinePath;
  final report = args.contains('--report');

  final orphans = _findOrphans(root);

  if (report) {
    for (final o in orphans) {
      stdout.writeln(o);
    }
    stdout.writeln('--- ${orphans.length} orphaned screen(s) total');
    return;
  }

  final baseline = _readBaseline(baselinePath);
  final newViolations = orphans.toSet().difference(baseline).toList()..sort();

  if (newViolations.isNotEmpty) {
    stderr.writeln(
      'Orphaned-screen check FAILED (Rule-0/AG-6 companion, AUD-settings-08) '
      '— the following screen widget(s) have no @RoutePage( registration '
      'and no call site anywhere else in lib/. A finished screen no path '
      'can reach is either dead code (delete it) or missing its navigation '
      'entry point (wire it in) — see docs/coding-standards.md, PF-2 /'
      ' AG-6:',
    );
    for (final v in newViolations) {
      stderr.writeln('  $v');
    }
    exit(1);
  }

  stdout.writeln(
    'Orphaned-screen check passed — no NEW orphaned screen outside the '
    'tracked baseline (${baseline.length} tracked at $baselinePath).',
  );
}
