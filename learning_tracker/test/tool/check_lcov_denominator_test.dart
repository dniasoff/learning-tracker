// Tests for `tool/check_lcov_denominator.dart` (R6 — flake & CI-trust gate,
// docs/test-artifacts/reassurance-plan.md Surface 6, item (d)).
//
// Each fixture test builds a disposable `lib/` tree + a synthetic lcov.info
// under the system temp directory and drives the checker at it via
// `--root`/`--lcov`/`--baseline` — fully isolated from this repo's real
// lib/ tree and coverage/lcov.info, mirroring the pattern used by
// test/tool/check_orphaned_screens_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_lcov_denominator.dart';

  Future<ProcessResult> run(List<String> args) => Process.run('dart', [
    'run',
    scriptPath,
    ...args,
  ], workingDirectory: packageDir);

  group('tool/check_lcov_denominator.dart (R6d)', () {
    test(
      'a lib/ file with no SF: entry in lcov.info is reported as missing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'lcov_denominator_fixture_',
        );
        try {
          Directory('${tempDir.path}/lib/core').createSync(recursive: true);
          File(
            '${tempDir.path}/lib/core/covered.dart',
          ).writeAsStringSync('int a() => 1;\n');
          File(
            '${tempDir.path}/lib/core/never_imported.dart',
          ).writeAsStringSync('int b() => 2;\n');

          final lcov = File('${tempDir.path}/lcov.info')
            ..writeAsStringSync(
              'SF:lib/core/covered.dart\n'
              'DA:1,1\n'
              'end_of_record\n',
            );

          final result = await run([
            '--root',
            tempDir.path,
            '--lcov',
            lcov.path,
            '--report',
          ]);
          expect(
            result.exitCode,
            0,
            reason: '--report always exits 0.\nstderr=${result.stderr}',
          );
          expect(
            result.stdout.toString(),
            contains('lib/core/never_imported.dart'),
            reason:
                'a file with zero SF: entries must be reported as missing '
                'from the denominator.\nstdout=${result.stdout}',
          );
          expect(
            result.stdout.toString(),
            isNot(contains('lib/core/covered.dart')),
            reason: 'a file WITH an SF: entry must not be reported as missing.',
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('generated files (.g.dart, .freezed.dart, l10n) are excluded even '
        'when absent from lcov.info', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lcov_denominator_fixture_',
      );
      try {
        Directory('${tempDir.path}/lib/l10n').createSync(recursive: true);
        File(
          '${tempDir.path}/lib/core_model.g.dart',
        ).writeAsStringSync('// generated\n');
        File(
          '${tempDir.path}/lib/core_model.freezed.dart',
        ).writeAsStringSync('// generated\n');
        File(
          '${tempDir.path}/lib/l10n/app_localizations_en.dart',
        ).writeAsStringSync('// generated\n');

        final lcov = File('${tempDir.path}/lcov.info')..writeAsStringSync('');

        final result = await run([
          '--root',
          tempDir.path,
          '--lcov',
          lcov.path,
          '--report',
        ]);
        expect(
          result.stdout.toString(),
          contains('0 lib/ file(s) absent'),
          reason:
              'generated files must never be flagged as missing, even '
              'with an empty lcov.info.\nstdout=${result.stdout}',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('AC1: a file in the tracked baseline does not fail the ratchet; a '
        'NEW file outside the baseline does', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lcov_denominator_fixture_',
      );
      try {
        Directory('${tempDir.path}/lib/core').createSync(recursive: true);
        File(
          '${tempDir.path}/lib/core/already_known.dart',
        ).writeAsStringSync('int a() => 1;\n');
        final lcov = File('${tempDir.path}/lcov.info')..writeAsStringSync('');
        final baseline = File('${tempDir.path}/baseline.txt')
          ..writeAsStringSync('lib/core/already_known.dart\n');

        final clean = await run([
          '--root',
          tempDir.path,
          '--lcov',
          lcov.path,
          '--baseline',
          baseline.path,
        ]);
        expect(
          clean.exitCode,
          0,
          reason:
              'a file already in the tracked baseline must not fail the '
              'ratchet.\nstdout=${clean.stdout}\nstderr=${clean.stderr}',
        );

        // Now introduce a NEW never-imported file outside the baseline —
        // the exact RED-DEMO shape (a lib/ file added but never wired
        // into any test-reachable import path).
        File(
          '${tempDir.path}/lib/core/new_never_imported.dart',
        ).writeAsStringSync('int b() => 2;\n');

        final dirty = await run([
          '--root',
          tempDir.path,
          '--lcov',
          lcov.path,
          '--baseline',
          baseline.path,
        ]);
        expect(
          dirty.exitCode,
          isNot(0),
          reason:
              'a NEW zero-coverage file outside the baseline must fail '
              'the ratchet.\nstdout=${dirty.stdout}',
        );
        expect(
          dirty.stderr.toString(),
          contains('lib/core/new_never_imported.dart'),
          reason: 'the failure must name the new offending file.',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('--strict hard-fails when lcov.info is missing; default mode '
        'soft-skips', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lcov_denominator_fixture_',
      );
      try {
        Directory('${tempDir.path}/lib').createSync(recursive: true);
        final missingLcov = '${tempDir.path}/does_not_exist.info';

        final soft = await run(['--root', tempDir.path, '--lcov', missingLcov]);
        expect(
          soft.exitCode,
          0,
          reason:
              'without --strict, a missing lcov.info must soft-skip, not '
              'fail.\nstdout=${soft.stdout}\nstderr=${soft.stderr}',
        );

        final strict = await run([
          '--root',
          tempDir.path,
          '--lcov',
          missingLcov,
          '--strict',
        ]);
        expect(
          strict.exitCode,
          isNot(0),
          reason:
              '--strict must hard-fail when lcov.info is missing (used by '
              'the CI step right after coverage generation).',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
