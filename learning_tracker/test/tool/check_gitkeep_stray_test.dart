// Tests for `tool/check_gitkeep_stray.dart` (AUD-core-constants-02).
//
// The checker keys off `git ls-files`, so a filesystem-only fixture (the
// pattern used by sibling checkers like
// check_notifications_duplicate_test_classes_test.dart) would never trip
// it — an untracked file is invisible to `git ls-files`. Mutating this
// repo's real git index from a test would also risk racing other test
// files under `--concurrency=2` (TQ-6: tests must be hermetic, no shared
// mutable state). Instead, each test in this file builds its own
// disposable `git init` repo under the system temp directory and drives
// the checker at it via `--root <tempDir>` — fully isolated, no shadow
// on this repo's actual git state.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<void> _run(String executable, List<String> args, String cwd) async {
  final result = await Process.run(executable, args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    fail(
      'setup command `$executable ${args.join(' ')}` failed in $cwd:\n'
      'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
  }
}

/// Initializes a throwaway git repo at [dir] with an initial commit so
/// `git ls-files` has a valid HEAD to work from.
Future<void> _initRepo(String dir) async {
  await _run('git', ['init', '-q'], dir);
  await _run('git', ['config', 'user.email', 'test@example.com'], dir);
  await _run('git', ['config', 'user.name', 'Test'], dir);
  // An initial commit isn't strictly required for `git ls-files` (it reads
  // the index, not history), but keeps the fixture repo realistic.
  File('$dir/README.md').writeAsStringSync('fixture repo\n');
  await _run('git', ['add', 'README.md'], dir);
  await _run('git', ['commit', '-q', '-m', 'init'], dir);
}

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_gitkeep_stray.dart';

  Future<ProcessResult> runCheck(String root) => Process.run('dart', [
    'run',
    scriptPath,
    '--root',
    root,
  ], workingDirectory: packageDir);

  group('tool/check_gitkeep_stray.dart (AUD-core-constants-02)', () {
    test('exits 0 on the real (fixed) tree — lib/core/constants/.gitkeep is '
        'gone', () async {
      final result = await Process.run('dart', [
        'run',
        scriptPath,
      ], workingDirectory: packageDir);
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('passed'));
      expect(
        File('$packageDir/lib/core/constants/.gitkeep').existsSync(),
        isFalse,
        reason: 'AUD-core-constants-02 AC: this file must be removed',
      );
    });

    test('AC: a .gitkeep tracked alongside another tracked file in the same '
        'lib/ directory flips the checker from clean to FAILED, and removing '
        'the stray .gitkeep restores clean', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'gitkeep_stray_fixture_',
      );
      try {
        await _initRepo(tempDir.path);

        final targetDir = Directory('${tempDir.path}/lib/core/some_module')
          ..createSync(recursive: true);
        final gitkeep = File('${targetDir.path}/.gitkeep')
          ..writeAsStringSync('');
        final sibling = File('${targetDir.path}/some_module.dart')
          ..writeAsStringSync('const x = 1;\n');
        await _run('git', [
          'add',
          'lib/core/some_module/.gitkeep',
          'lib/core/some_module/some_module.dart',
        ], tempDir.path);

        final withViolation = await runCheck(tempDir.path);
        expect(
          withViolation.exitCode,
          1,
          reason:
              'a .gitkeep alongside a tracked sibling file must fail the '
              'checker.\n'
              'stdout=${withViolation.stdout}\n'
              'stderr=${withViolation.stderr}',
        );
        expect(
          withViolation.stderr.toString(),
          contains('lib/core/some_module/.gitkeep'),
        );

        // Removing the stray .gitkeep (this finding's own recommended
        // fix) restores a clean pass — the sibling source file stays.
        gitkeep.deleteSync();
        await _run('git', [
          'rm',
          '--cached',
          '-q',
          'lib/core/some_module/.gitkeep',
        ], tempDir.path);

        final clean = await runCheck(tempDir.path);
        expect(
          clean.exitCode,
          0,
          reason:
              'deleting the stray .gitkeep must restore a clean pass.\n'
              'stdout=${clean.stdout}\nstderr=${clean.stderr}',
        );

        // Sanity: the sibling source file is untouched.
        expect(sibling.existsSync(), isTrue);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('a directory holding ONLY a .gitkeep (genuinely empty otherwise) does '
        'NOT trip the checker', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'gitkeep_stray_fixture_empty_',
      );
      try {
        await _initRepo(tempDir.path);

        Directory(
          '${tempDir.path}/lib/core/genuinely_empty',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/lib/core/genuinely_empty/.gitkeep',
        ).writeAsStringSync('');
        await _run('git', [
          'add',
          'lib/core/genuinely_empty/.gitkeep',
        ], tempDir.path);

        final result = await runCheck(tempDir.path);
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
