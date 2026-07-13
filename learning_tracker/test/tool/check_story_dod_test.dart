// Tests for `tool/check_story_dod.dart` (AUD-docs-24, AG-9).
//
// Mirrors the fixture-based approach used elsewhere under test/tool/ (see
// check_db_transactions_test.dart): write a disposable fixture file into
// the checker's scanned directory, run the script, assert it fires, delete
// the fixture, assert a clean pass. This is the Rule-0 "demonstrate it
// fires on a deliberately-broken fixture then passes clean" evidence,
// captured as a durable regression test rather than a one-off manual run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_story_dod.dart';
  final storiesDir = Directory('$packageDir/../docs/stories/implementation');
  final fixtureFile = File(
    '${storiesDir.path}/zzz-audit-fixture-story-dod-do-not-commit.md',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  tearDown(() {
    if (fixtureFile.existsSync()) fixtureFile.deleteSync();
  });

  group('tool/check_story_dod.dart (AUD-docs-24, AG-9)', () {
    test('exits 0 on the real tree — the tracked epic-21 backlog is within '
        'the baseline and no NEW violation exists', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('ratchet OK'));
    });

    test('--report lists the known baseline (16 epic-21 stories + '
        '7 epic-19 stories + 16-1-pace-based-goal-mode.md) and nothing else '
        'new', () async {
      final result = await Process.run('dart', [
        'run',
        scriptPath,
        '--report',
      ], workingDirectory: packageDir);
      expect(result.exitCode, 0);
      final out = result.stdout.toString();
      for (final expected in [
        '21-1-device-account-registry.md',
        '21-16-cloud-function-deletion.md',
        '16-1-pace-based-goal-mode.md',
      ]) {
        expect(out, contains(expected));
      }
      // Baseline grew 17 -> 24 when AUD-docs-06 backfilled 7 pre-existing
      // Epic-19 offline-first stories (real, tested deliverables; DoD-doc
      // sections still pending) into the tracked ratchet baseline.
      expect(out, contains('24 docs/stories/implementation'));
      // Confirm the 7 Epic-19 additions are genuinely present in the report.
      for (final expected in [
        '19-2-two-database-split.md',
        '19-12-content-db-resilience-error-recovery.md',
      ]) {
        expect(out, contains(expected));
      }
    });

    test('AC: a fixture story with Status: done, an unchecked Tasks/Subtasks '
        'line, and an unfilled Dev Agent Record flips the checker from clean '
        'to FAILED, and removing it restores clean', () async {
      fixtureFile.writeAsStringSync('''
# Fixture Story

Status: done

## Tasks / Subtasks

- [ ] Do the thing

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
''');

      final withFixture = await runCheck();
      expect(
        withFixture.exitCode,
        1,
        reason:
            'a Status: done story with an unchecked Tasks/Subtasks line '
            'and an empty Dev Agent Record must fail the checker.\n'
            'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
      );
      expect(
        withFixture.stderr.toString(),
        allOf(
          contains('zzz-audit-fixture-story-dod-do-not-commit.md'),
          contains("unchecked '- [ ]' line in Tasks/Subtasks"),
          contains('Dev Agent Record section has only empty headers'),
        ),
      );

      fixtureFile.deleteSync();

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'removing the fixture must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('a fixture story with Status: done, all tasks checked, and a '
        'populated Dev Agent Record does NOT trip the checker', () async {
      fixtureFile.writeAsStringSync('''
# Fixture Story

Status: done

## Tasks / Subtasks

- [x] Do the thing

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Completion Notes List

- Did the thing.

### Change Log
''');

      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason:
            'a fully-checked-off story with a populated Dev Agent Record '
            'must not be flagged.\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
    });

    test('a fixture story with Status: ready-for-dev and unchecked tasks does '
        'NOT trip the checker (only done/review are in scope)', () async {
      fixtureFile.writeAsStringSync('''
# Fixture Story

Status: ready-for-dev

## Tasks / Subtasks

- [ ] Do the thing

## Dev Agent Record

### Agent Model Used
### Completion Notes List
### Change Log
''');

      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason:
            'Status: ready-for-dev is out of AG-9 scope and must not be '
            'flagged.\nstdout=${result.stdout}\nstderr=${result.stderr}',
      );
    });
  });
}
