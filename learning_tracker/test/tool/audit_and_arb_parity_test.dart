// Tests for `make audit` and `tool/arb_parity_check.dart` (DNI-389 / Story 27.13).
//
// These tests shell out to the real Make target and Dart script and
// assert their behaviour. This keeps the same integration-style
// approach as `schema_check_test.dart`.
//
// NOTE: `make audit` may exit non-zero on the current codebase because
// enforcement greps catch pre-existing violations from earlier stories
// (e.g. EdgeInsets.only, firebase_storage outside core/sync — those
// stories land in Epics 26–27). The test therefore validates that the
// target *runs all 17 greps and prints file:line hits* rather than
// asserting a clean exit code. A separate live-clean assertion is
// guarded with a skip note so it can be re-enabled once all
// violations are resolved.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (`learning_tracker/`).
  // The repo root is one level up; the Makefile lives in the package dir.
  final packageDir = Directory.current.path;
  final repoRoot = Directory.current.parent.path;

  group('make audit (DNI-389 — Story 27.13 AC1)', () {
    test('prints N/total headers for all 17 greps', () async {
      final result = await Process.run('make', [
        'audit',
      ], workingDirectory: packageDir);
      final stdout = result.stdout.toString();
      // The target must attempt all 17 greps regardless of whether
      // earlier ones fail, so every N/total header must appear.
      // Greps 1-15 are labelled N/15; greps 16-17 are labelled N/17.
      for (var i = 1; i <= 15; i++) {
        expect(
          stdout,
          contains('$i/15'),
          reason:
              'make audit must run grep $i of 15.\n'
              'stdout=$stdout\nstderr=${result.stderr}',
        );
      }
      for (var i = 16; i <= 17; i++) {
        expect(
          stdout,
          contains('$i/17'),
          reason:
              'make audit must run grep $i of 17.\n'
              'stdout=$stdout\nstderr=${result.stderr}',
        );
      }
    });

    test('prints file:line paths for violations', () async {
      final result = await Process.run('make', [
        'audit',
      ], workingDirectory: packageDir);
      final stdout = result.stdout.toString();
      // When there are violations, each hit must contain a colon
      // indicating file:line format. We verify this if any violation
      // output is present (i.e. a line that looks like a grep hit).
      final hitLines = stdout
          .split('\n')
          .where(
            (line) =>
                line.contains('.dart:') &&
                !line.startsWith('[') &&
                line.isNotEmpty,
          )
          .toList();

      // Either there are no violations (OK) or each hit has file:line.
      for (final line in hitLines) {
        expect(
          RegExp(r'\.dart:\d+:').hasMatch(line),
          isTrue,
          reason: 'violation line must match file:line format: $line',
        );
      }
    });

    test(
      'exits 0 when codebase is fully clean [skip until Epics 26–27 violations resolved]',
      () async {
        // This test is skipped until all enforcement violations from
        // Epics 25–26 are resolved (Stories 25.9, 25.10, 25.11, 25.19,
        // 25.21, 26.31, etc.).
        //
        // To re-enable: remove the `skip:` parameter from this group()
        // when `make audit` exits 0 on the main branch.
      },
      skip:
          'Pre-existing violations from Epics 25–26 not yet resolved; '
          're-enable once make audit is fully clean (DNI-389 tracks this)',
    );

    test('check 23/23 asserts exactly one coding-standards.md outside '
        'docs/_archive/ (AUD-docs-04)', () async {
      final result = await Process.run('make', [
        'audit',
      ], workingDirectory: packageDir);
      final stdout = result.stdout.toString();
      expect(
        stdout,
        contains('23/23'),
        reason:
            'make audit must run the coding-standards.md uniqueness '
            'check (AUD-docs-04).\n'
            'stdout=$stdout\nstderr=${result.stderr}',
      );
      expect(
        stdout,
        isNot(contains('Expected exactly one coding-standards.md')),
        reason:
            'docs/coding-standards.md must be the only file named '
            'coding-standards.md outside docs/_archive/ — a duplicate '
            'root copy would regress AUD-docs-04.\n'
            'stdout=$stdout\nstderr=${result.stderr}',
      );
    });
  });

  group('tool/arb_parity_check.dart (DNI-389 — Story 27.13 AC2)', () {
    final scriptPath = '$repoRoot/tool/arb_parity_check.dart';

    Future<ProcessResult> runCheck({String? enPath, String? hePath}) {
      final args = <String>[
        'run',
        scriptPath,
        if (enPath != null) ...['--en', enPath],
        if (hePath != null) ...['--he', hePath],
      ];
      return Process.run('dart', args, workingDirectory: repoRoot);
    }

    test(
      'exits 0 when English and Hebrew keys are in parity (live ARBs)',
      () async {
        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason:
              'arb_parity_check must pass on the live ARB files.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stdout.toString(),
          contains('arb_parity_check OK'),
          reason: 'stdout should confirm parity',
        );
      },
    );

    test('exits 1 when English has keys missing in Hebrew', () async {
      final tmpDir = Directory.systemTemp.createTempSync('arb_parity_test_');
      try {
        final enArb = File('${tmpDir.path}/app_en.arb');
        final heArb = File('${tmpDir.path}/app_he.arb');

        enArb.writeAsStringSync(
          '{"@@locale":"en","hello":"Hello","world":"World"}',
        );
        heArb.writeAsStringSync('{"@@locale":"he","hello":"שלום"}');

        final result = await runCheck(enPath: enArb.path, hePath: heArb.path);

        expect(
          result.exitCode,
          1,
          reason:
              'should fail when Hebrew is missing a key.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stderr.toString(),
          contains('world'),
          reason: 'stderr should name the missing key',
        );
        expect(
          result.stderr.toString(),
          contains('arb_parity_check FAILED'),
          reason: 'stderr should contain FAILED marker',
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('metadata keys (@-prefixed) are excluded from parity check', () async {
      final tmpDir = Directory.systemTemp.createTempSync('arb_parity_meta_');
      try {
        final enArb = File('${tmpDir.path}/app_en.arb');
        final heArb = File('${tmpDir.path}/app_he.arb');

        // English has a user-facing key `greeting` and a metadata key
        // `@greeting`. Hebrew has only `greeting` (no metadata key).
        // The check should pass because metadata keys are exempt.
        enArb.writeAsStringSync(
          '{"@@locale":"en","greeting":"Hello","@greeting":{"description":"A greeting"}}',
        );
        heArb.writeAsStringSync('{"@@locale":"he","greeting":"שלום"}');

        final result = await runCheck(enPath: enArb.path, hePath: heArb.path);

        expect(
          result.exitCode,
          0,
          reason:
              'metadata keys must not be required in the target locale.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('exits 2 when English ARB path does not exist', () async {
      final result = await runCheck(
        enPath: '/nonexistent/app_en.arb',
        hePath: '$repoRoot/learning_tracker/lib/l10n/app_he.arb',
      );
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('not found'));
    });

    test('exits 2 when Hebrew ARB path does not exist', () async {
      final result = await runCheck(
        enPath: '$repoRoot/learning_tracker/lib/l10n/app_en.arb',
        hePath: '/nonexistent/app_he.arb',
      );
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('not found'));
    });

    test('exits 2 when English ARB is not valid JSON', () async {
      final tmpDir = Directory.systemTemp.createTempSync('arb_parity_json_');
      try {
        final enArb = File('${tmpDir.path}/app_en.arb')
          ..writeAsStringSync('not-json');
        final heArb = File('${tmpDir.path}/app_he.arb')
          ..writeAsStringSync('{"@@locale":"he"}');

        final result = await runCheck(enPath: enArb.path, hePath: heArb.path);

        expect(result.exitCode, 2);
        expect(result.stderr.toString(), contains('parse'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });
  });
}
