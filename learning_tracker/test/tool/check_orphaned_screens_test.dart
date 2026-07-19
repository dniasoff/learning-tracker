// Tests for `tool/check_orphaned_screens.dart` (Rule-0/AG-6 companion,
// AUD-settings-08 acceptance_criteria[0]).
//
// Each fixture test builds a disposable `lib/` tree under the system temp
// directory and drives the checker at it via `--root <tempDir>` (and, for
// the ratchet test, `--baseline <tempFile>`) — fully isolated from this
// repo's real screens, mirroring the pattern used by
// test/tool/check_gitkeep_stray_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_orphaned_screens.dart';

  Future<ProcessResult> runReport(String root) => Process.run('dart', [
    'run',
    scriptPath,
    '--root',
    root,
    '--report',
  ], workingDirectory: packageDir);

  Future<ProcessResult> runRatchet(String root, String baseline) => Process.run(
    'dart',
    ['run', scriptPath, '--root', root, '--baseline', baseline],
    workingDirectory: packageDir,
  );

  group('tool/check_orphaned_screens.dart (AUD-settings-08)', () {
    test('exits 0 on the real tree — the only known orphan '
        '(ScopeSelectionScreen) is in the tracked baseline', () async {
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
    });

    test('AC1: a *_screen.dart class with no @RoutePage( and no call site '
        'elsewhere in lib/ is reported as an orphan', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'orphaned_screens_fixture_',
      );
      try {
        final screensDir = Directory(
          '${tempDir.path}/lib/features/widget/presentation/screens',
        )..createSync(recursive: true);
        File('${screensDir.path}/lonely_screen.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

class LonelyScreen extends StatelessWidget {
  const LonelyScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');

        final result = await runReport(tempDir.path);
        expect(
          result.exitCode,
          0,
          reason:
              '--report always exits 0 regardless of findings.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stdout.toString(),
          contains(
            'LonelyScreen (lib/features/widget/presentation/'
            'screens/lonely_screen.dart)',
          ),
          reason: 'An unreferenced screen class must be reported',
        );
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('a *_screen.dart class carrying @RoutePage( is NOT reported, even '
        'with zero call sites elsewhere', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'orphaned_screens_fixture_routed_',
      );
      try {
        final screensDir = Directory(
          '${tempDir.path}/lib/features/widget/presentation/screens',
        )..createSync(recursive: true);
        File('${screensDir.path}/routed_screen.dart').writeAsStringSync('''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class RoutedScreen extends StatelessWidget {
  const RoutedScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');

        final result = await runReport(tempDir.path);
        expect(
          result.stdout.toString(),
          isNot(contains('RoutedScreen')),
          reason:
              'An @RoutePage(-annotated screen must never be flagged '
              'as orphaned, regardless of call sites elsewhere',
        );
        expect(result.stdout.toString(), contains('0 orphaned screen'));
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('a *_screen.dart class constructed elsewhere in lib/ (manual '
        'Navigator.push) is NOT reported', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'orphaned_screens_fixture_pushed_',
      );
      try {
        final screensDir = Directory(
          '${tempDir.path}/lib/features/widget/presentation/screens',
        )..createSync(recursive: true);
        File('${screensDir.path}/pushed_screen.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

class PushedScreen extends StatelessWidget {
  const PushedScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');
        final callerDir = Directory(
          '${tempDir.path}/lib/features/widget/presentation/widgets',
        )..createSync(recursive: true);
        File('${callerDir.path}/launcher.dart').writeAsStringSync('''
import 'package:flutter/material.dart';
import '../screens/pushed_screen.dart';

void launch(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PushedScreen()),
  );
}
''');

        final result = await runReport(tempDir.path);
        expect(
          result.stdout.toString(),
          isNot(contains('PushedScreen')),
          reason:
              'A screen constructed via Navigator.push elsewhere in '
              'lib/ must not be flagged as orphaned',
        );
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('ratchet mode: a NEW orphan not in the baseline fails (exit 1); the '
        'same orphan listed in the baseline passes (exit 0)', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'orphaned_screens_fixture_ratchet_',
      );
      try {
        final screensDir = Directory(
          '${tempDir.path}/lib/features/widget/presentation/screens',
        )..createSync(recursive: true);
        File('${screensDir.path}/lonely_screen.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

class LonelyScreen extends StatelessWidget {
  const LonelyScreen({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''');
        final emptyBaseline = File('${tempDir.path}/empty_baseline.txt')
          ..writeAsStringSync('');

        final withoutBaseline = await runRatchet(
          tempDir.path,
          emptyBaseline.path,
        );
        expect(
          withoutBaseline.exitCode,
          1,
          reason:
              'A NEW orphan not in the baseline must fail the gate.\n'
              'stdout=${withoutBaseline.stdout}\n'
              'stderr=${withoutBaseline.stderr}',
        );
        expect(withoutBaseline.stderr.toString(), contains('LonelyScreen'));

        final trackedBaseline = File('${tempDir.path}/tracked_baseline.txt')
          ..writeAsStringSync(
            'LonelyScreen (lib/features/widget/presentation/screens/'
            'lonely_screen.dart)\n',
          );

        final withBaseline = await runRatchet(
          tempDir.path,
          trackedBaseline.path,
        );
        expect(
          withBaseline.exitCode,
          0,
          reason:
              'An orphan already recorded in the baseline must pass.\n'
              'stdout=${withBaseline.stdout}\nstderr=${withBaseline.stderr}',
        );
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
