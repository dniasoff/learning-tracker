// Tests for `tool/check_sync_explainer_merger_count.dart` (AUD-docs-18, AG-8).
//
// Mirrors the fixture-based approach used elsewhere under test/tool/ (see
// check_story_dod_test.dart): mutate the doc the checker reads, run the
// script, assert it fires, restore the original content, assert a clean
// pass. This is the Rule-0 "demonstrate it fires on a deliberately-broken
// fixture then passes clean" evidence, captured as a durable regression
// test rather than a one-off manual run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_sync_explainer_merger_count.dart';
  final docFile = File('$packageDir/../docs/explainers/sync-subsystem.md');

  late String originalContent;

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  setUp(() {
    originalContent = docFile.readAsStringSync();
  });

  tearDown(() {
    // Always restore, even if a test fails mid-assertion.
    docFile.writeAsStringSync(originalContent);
  });

  group('tool/check_sync_explainer_merger_count.dart (AUD-docs-18, AG-8)', () {
    test('exits 0 on the real doc — its stated EntityMerger count matches '
        'lib/core/sync/merge/', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('check OK'));
    });

    test('AC: rewriting the doc to claim a stale count (8, the pre-AUD-docs-18 '
        'number) flips the checker from clean to FAILED, and restoring the '
        'real count restores clean', () async {
      final rewritten = originalContent.replaceAll(
        RegExp(r'\d+\s+`?EntityMerger'),
        '8 EntityMerger',
      );
      // Sanity: the substitution must actually have changed the file,
      // otherwise this test would trivially pass without exercising
      // anything.
      expect(rewritten, isNot(equals(originalContent)));
      docFile.writeAsStringSync(rewritten);

      final withStaleCount = await runCheck();
      expect(
        withStaleCount.exitCode,
        1,
        reason:
            'a doc claiming a stale EntityMerger count must fail the '
            'checker.\nstdout=${withStaleCount.stdout}\n'
            'stderr=${withStaleCount.stderr}',
      );
      expect(
        withStaleCount.stderr.toString(),
        allOf(contains('claims 8 EntityMerger'), contains('actually has')),
      );

      docFile.writeAsStringSync(originalContent);
      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'restoring the real doc content must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('AC: a doc with no EntityMerger count claim at all fails loudly '
        'instead of silently passing', () async {
      final stripped = originalContent.replaceAll(
        RegExp(r'\d+\s+`?EntityMerger'),
        'several EntityMerger',
      );
      expect(stripped, isNot(equals(originalContent)));
      expect(RegExp(r'\d+\s+`?EntityMerger').hasMatch(stripped), isFalse);
      docFile.writeAsStringSync(stripped);

      final result = await runCheck();
      expect(
        result.exitCode,
        1,
        reason:
            'a doc with zero count claims must fail loudly, not silently '
            'pass.\nstdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stderr.toString(),
        contains('no longer states an "<N> EntityMerger(s)" count'),
      );
    });
  });
}
