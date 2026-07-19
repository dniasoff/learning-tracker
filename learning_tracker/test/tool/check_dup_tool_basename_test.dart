// Tests for `tool/check_dup_tool_basename.dart` (AUD-guardrails-10
// acceptance_criteria[1]: "A grep/CI check fails if two files share a
// basename under tool/** and learning_tracker/tool/** with diverging
// content").
//
// Each fixture test builds two disposable directory trees under the system
// temp directory and drives the checker at them via `--dir-a`/`--dir-b`
// (and, for the ratchet test, `--baseline`) — fully isolated from this
// repo's real tool/ directories, mirroring the pattern used by
// test/tool/check_orphaned_screens_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_dup_tool_basename.dart';

  Future<ProcessResult> runReport(String dirA, String dirB) => Process.run(
    'dart',
    ['run', scriptPath, '--dir-a', dirA, '--dir-b', dirB, '--report'],
    workingDirectory: packageDir,
  );

  Future<ProcessResult> runRatchet(String dirA, String dirB, String baseline) =>
      Process.run('dart', [
        'run',
        scriptPath,
        '--dir-a',
        dirA,
        '--dir-b',
        dirB,
        '--baseline',
        baseline,
      ], workingDirectory: packageDir);

  group('tool/check_dup_tool_basename.dart (AUD-guardrails-10)', () {
    test('exits 0 on the real repo tool/ directories — the only known '
        'diverging collision (gen_arch_tables.dart) is in the tracked '
        'baseline', () async {
      final result = await Process.run('dart', [
        'run',
        scriptPath,
      ], workingDirectory: packageDir);
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('ratchet OK'));
    });

    test('AC: a file basename shared between dir-a and dir-b with DIFFERENT '
        'content is reported as a diverging collision', () async {
      final dirA = await Directory.systemTemp.createTemp(
        'dup_tool_basename_a_',
      );
      final dirB = await Directory.systemTemp.createTemp(
        'dup_tool_basename_b_',
      );
      try {
        File('${dirA.path}/seed_content_db.dart').writeAsStringSync(
          '// orphaned fragment\nFuture<int> _fetch() async => 1;\n',
        );
        File(
          '${dirB.path}/seed_content_db.dart',
        ).writeAsStringSync("import 'dart:async';\nvoid main() {}\n");

        final result = await runReport(dirA.path, dirB.path);
        expect(
          result.exitCode,
          0,
          reason:
              '--report always exits 0 regardless of findings.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stdout.toString(),
          contains('seed_content_db.dart'),
          reason: 'A diverging same-basename pair must be reported',
        );
      } finally {
        if (dirA.existsSync()) dirA.deleteSync(recursive: true);
        if (dirB.existsSync()) dirB.deleteSync(recursive: true);
      }
    });

    test('a file basename shared between dir-a and dir-b with IDENTICAL '
        'content is NOT reported', () async {
      final dirA = await Directory.systemTemp.createTemp(
        'dup_tool_basename_identical_a_',
      );
      final dirB = await Directory.systemTemp.createTemp(
        'dup_tool_basename_identical_b_',
      );
      try {
        const sharedContent = "void main() { print('same'); }\n";
        File(
          '${dirA.path}/shared_script.dart',
        ).writeAsStringSync(sharedContent);
        File(
          '${dirB.path}/shared_script.dart',
        ).writeAsStringSync(sharedContent);

        final result = await runReport(dirA.path, dirB.path);
        expect(
          result.stdout.toString(),
          isNot(contains('shared_script.dart')),
          reason: 'A byte-identical duplicate is not a diverging collision',
        );
        expect(result.stdout.toString(), contains('0 diverging'));
      } finally {
        if (dirA.existsSync()) dirA.deleteSync(recursive: true);
        if (dirB.existsSync()) dirB.deleteSync(recursive: true);
      }
    });

    test(
      'a basename present in only one of dir-a/dir-b is NOT reported',
      () async {
        final dirA = await Directory.systemTemp.createTemp(
          'dup_tool_basename_onlya_',
        );
        final dirB = await Directory.systemTemp.createTemp(
          'dup_tool_basename_onlyb_',
        );
        try {
          File(
            '${dirA.path}/only_in_a.dart',
          ).writeAsStringSync('void main() {}\n');

          final result = await runReport(dirA.path, dirB.path);
          expect(result.stdout.toString(), contains('0 diverging'));
        } finally {
          if (dirA.existsSync()) dirA.deleteSync(recursive: true);
          if (dirB.existsSync()) dirB.deleteSync(recursive: true);
        }
      },
    );

    test(
      'ratchet mode: a NEW diverging collision not in the baseline fails '
      '(exit 1); the same collision listed in the baseline passes (exit 0)',
      () async {
        final dirA = await Directory.systemTemp.createTemp(
          'dup_tool_basename_ratchet_a_',
        );
        final dirB = await Directory.systemTemp.createTemp(
          'dup_tool_basename_ratchet_b_',
        );
        try {
          File('${dirA.path}/seed_content_db.dart').writeAsStringSync(
            '// orphaned fragment\nFuture<int> _fetch() async => 1;\n',
          );
          File(
            '${dirB.path}/seed_content_db.dart',
          ).writeAsStringSync("import 'dart:async';\nvoid main() {}\n");
          final emptyBaseline = File('${dirA.path}/empty_baseline.txt')
            ..writeAsStringSync('');

          final withoutBaseline = await runRatchet(
            dirA.path,
            dirB.path,
            emptyBaseline.path,
          );
          expect(
            withoutBaseline.exitCode,
            1,
            reason:
                'A NEW diverging collision not in the baseline must fail '
                'the gate.\nstdout=${withoutBaseline.stdout}\n'
                'stderr=${withoutBaseline.stderr}',
          );
          expect(
            withoutBaseline.stderr.toString(),
            contains('seed_content_db.dart'),
          );

          final trackedBaseline = File('${dirA.path}/tracked_baseline.txt')
            ..writeAsStringSync('seed_content_db.dart\n');

          final withBaseline = await runRatchet(
            dirA.path,
            dirB.path,
            trackedBaseline.path,
          );
          expect(
            withBaseline.exitCode,
            0,
            reason:
                'A collision already recorded in the baseline must pass.\n'
                'stdout=${withBaseline.stdout}\nstderr=${withBaseline.stderr}',
          );
        } finally {
          if (dirA.existsSync()) dirA.deleteSync(recursive: true);
          if (dirB.existsSync()) dirB.deleteSync(recursive: true);
        }
      },
    );
  });
}
