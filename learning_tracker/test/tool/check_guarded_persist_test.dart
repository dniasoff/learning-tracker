// Tests for `tool/check_guarded_persist.dart` (AUD-core-preferences-04,
// EH-2 / SM-5).
//
// Mirrors the fixture-based approach in `check_db_transactions_test.dart`:
// write a disposable fixture file into the checker's dedicated fixture
// directory, run the script, assert it fires, delete the fixture, assert a
// clean pass. This is the Rule-0 "demonstrate it fires on a deliberately-
// broken fixture then passes clean" evidence, captured as a durable
// regression test rather than a one-off manual run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_guarded_persist.dart';
  final fixtureDir = Directory(
    '$packageDir/test/fixtures/audit/guarded_persist',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  group('tool/check_guarded_persist.dart (AUD-core-preferences-04)', () {
    test('exits 0 on the real (fixed) tree — every Future<void> Notifier '
        'method in the scoped 6 files guards its persistence call', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('check passed'));
    });

    test('AC: a fixture Future<void> Notifier method with an unguarded await '
        'prefs.setBool(...) flips the checker from clean to FAILED, and '
        'removing it restores clean', () async {
      fixtureDir.createSync(recursive: true);
      final fixtureFile = File(
        '${fixtureDir.path}/zzz_audit_fixture_guarded_persist_do_not_commit.dart',
      );

      try {
        // A Future<void> method on a class (i.e. a Notifier-shaped method,
        // not a bare top-level function) with an unguarded
        // `await prefs.setBool(...)` — exactly the AUD-core-preferences-04
        // shape.
        fixtureFile.writeAsStringSync('''
class ZzzAuditFixtureGuardedPersistDoNotCommit {
  Future<void> setSomething(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('some_key', value);
  }
}
''');

        final withFixture = await runCheck();
        expect(
          withFixture.exitCode,
          1,
          reason:
              'a Future<void> Notifier method with an unguarded '
              'await prefs.setBool(...) must fail the checker.\n'
              'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
        );
        expect(
          withFixture.stderr.toString(),
          allOf(
            contains('zzz_audit_fixture_guarded_persist_do_not_commit.dart'),
            contains('setSomething'),
            contains('unguarded'),
          ),
        );
      } finally {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      }

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'removing the fixture must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('a fixture method wrapping the same await in try/catch does NOT trip '
        'the checker', () async {
      fixtureDir.createSync(recursive: true);
      final fixtureFile = File(
        '${fixtureDir.path}/zzz_audit_fixture_guarded_persist_tryok_do_not_commit.dart',
      );

      try {
        fixtureFile.writeAsStringSync('''
class ZzzAuditFixtureGuardedPersistTryOkDoNotCommit {
  Future<void> setSomething(bool value) async {
    final previous = state;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('some_key', value);
    } catch (e, st) {
      AppLogger.instance.error(event: 'x', exception: e, stackTrace: st);
      state = previous;
    }
  }
}
''');

        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason:
              'a method whose own body wraps the awaited persist call in '
              'try/catch must not be flagged.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      }
    });

    test('a fixture method routed through guardedPersist(...) does NOT trip '
        'the checker', () async {
      fixtureDir.createSync(recursive: true);
      final fixtureFile = File(
        '${fixtureDir.path}/zzz_audit_fixture_guarded_persist_helper_do_not_commit.dart',
      );

      try {
        fixtureFile.writeAsStringSync('''
class ZzzAuditFixtureGuardedPersistHelperDoNotCommit {
  Future<void> setSomething(bool value) async {
    final previous = state;
    state = value;
    await guardedPersist(
      event: 'x',
      write: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('some_key', value);
      },
      onFailure: () => state = previous,
    );
  }
}
''');

        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason:
              'a method whose own body routes the awaited persist call '
              'through guardedPersist(...) must not be flagged.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      }
    });
  });
}
