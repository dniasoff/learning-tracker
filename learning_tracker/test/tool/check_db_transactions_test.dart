// Tests for `tool/check_db_transactions.dart` (AUD-onboarding-06, DB-2).
//
// Mirrors the fixture-based approach in `audit_and_arb_parity_test.dart`'s
// "AC1: adding then removing a throwaway cross-feature import flips check
// 15/15" test: write a disposable fixture file into the checker's scanned
// directory, run the script, assert it fires, delete the fixture, assert a
// clean pass. This is the Rule-0 "demonstrate it fires on a deliberately-
// broken fixture then passes clean" evidence, captured as a durable
// regression test rather than a one-off manual run.

@Tags(['serial-tools'])
// serial-tools: this test writes/deletes a fixture under learning_tracker/lib/
// while its checker recursively walks that same tree. It contends with the
// other real-lib fixture tests under the parallel main lane; run it through
// `make test-serial-tools` with --concurrency=1.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_db_transactions.dart';
  final scanDir = Directory(
    '$packageDir/lib/features/onboarding/domain/services',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  group('tool/check_db_transactions.dart (AUD-onboarding-06, DB-2)', () {
    test(
      'exits 0 on the real (fixed) tree — every multi-write method in '
      'features/onboarding/domain/services has an enclosing transaction()',
      () async {
        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stdout.toString(), contains('check passed'));
      },
    );

    test(
      'AC: a fixture method with 2 unwrapped mutation calls flips the '
      'checker from clean to FAILED, and removing it restores clean',
      () async {
        final fixtureFile = File(
          '${scanDir.path}/zzz_audit_fixture_db2_do_not_commit.dart',
        );

        try {
          // A method with two awaited mutation-shaped calls and no
          // enclosing transaction()/batch() — exactly the DB-2 shape.
          fixtureFile.writeAsStringSync('''
class ZzzAuditFixtureDb2DoNotCommit {
  Future<void> doTwoUnwrappedWrites() async {
    await someDao.insertThing(1);
    await someDao.deleteThing(2);
  }
}
''');

          final withFixture = await runCheck();
          expect(
            withFixture.exitCode,
            1,
            reason:
                'a method with >=2 awaited mutation calls and no enclosing '
                'transaction()/batch() must fail the checker.\n'
                'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
          );
          expect(
            withFixture.stderr.toString(),
            allOf(
              contains('zzz_audit_fixture_db2_do_not_commit.dart'),
              contains('doTwoUnwrappedWrites'),
              contains('no enclosing transaction()/batch()'),
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
      },
    );

    test('a fixture method wrapping the same 2 mutation calls in '
        'runTransaction() does NOT trip the checker', () async {
      final fixtureFile = File(
        '${scanDir.path}/zzz_audit_fixture_db2_transacted_do_not_commit.dart',
      );

      try {
        fixtureFile.writeAsStringSync('''
class ZzzAuditFixtureDb2TransactedDoNotCommit {
  Future<void> doTwoWrapped() async {
    await someDao.runTransaction(() async {
      await someDao.insertThing(1);
      await someDao.deleteThing(2);
    });
  }
}
''');

        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason:
              'a method whose own body contains runTransaction( must not '
              'be flagged, even with >=2 mutation calls inside it.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      }
    });
  });
}
