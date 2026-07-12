// Tests for `tool/check_dao_stateerror_messages.dart` (AUD-core-database-14,
// EH-5).
//
// Mirrors the fixture-based approach in `check_db_transactions_test.dart`:
// temporarily mutate one of the 4 scoped (file, method) targets back to its
// pre-fix `StateError(...)` shape, run the script, assert it fires, restore
// the fixed content, assert a clean pass. This is the Rule-0 "demonstrate it
// fires on a deliberately-broken fixture then passes clean" evidence,
// captured as a durable regression test rather than a one-off manual run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_dao_stateerror_messages.dart';
  final scopedFile = File(
    '$packageDir/lib/core/database/daos/user_profile_dao.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  group('tool/check_dao_stateerror_messages.dart (AUD-core-database-14, '
      'EH-5)', () {
    test('exits 0 on the real (fixed) tree — none of the 4 scoped methods '
        'construct a StateError', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('check passed'));
    });

    test('AC: reverting UserTierX.fromDb to a raw English StateError message '
        'flips the checker from clean to FAILED, and restoring the '
        'DaoInvariantError fix restores clean', () async {
      final originalContent = scopedFile.readAsStringSync();

      try {
        // The exact pre-fix shape this finding (AUD-core-database-14)
        // replaced.
        final regressed = originalContent.replaceFirst(
          '_ => throw DaoInvariantError(DaoErrorCode.unknownAccountTier, value),',
          r"_ => throw StateError('Unknown tier: $value'),",
        );
        expect(
          regressed,
          isNot(equals(originalContent)),
          reason:
              'the replaceFirst target string must actually be '
              'present in the real fixed file for this test to be '
              'meaningful — if UserTierX.fromDb was refactored, update '
              'this fixture string too',
        );
        scopedFile.writeAsStringSync(regressed);

        final withFixture = await runCheck();
        expect(
          withFixture.exitCode,
          1,
          reason:
              'a StateError reintroduced in UserTierX.fromDb must fail '
              'the checker.\n'
              'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
        );
        expect(
          withFixture.stderr.toString(),
          allOf(contains('user_profile_dao.dart'), contains('fromDb(')),
        );
      } finally {
        scopedFile.writeAsStringSync(originalContent);
      }

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'restoring the DaoInvariantError-based fix must restore a '
            'clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('does not flag ActiveCurriculumDao.archiveByProfile\'s pre-existing, '
        'out-of-scope StateError (adjacent defect, not named by this '
        'finding\'s evidence — deliberately not fixed here)', () {
      final content = File(
        '$packageDir/lib/core/database/daos/active_curriculum_dao.dart',
      ).readAsStringSync();
      expect(
        content,
        contains(
          "'Cannot deactivate the last active curriculum for this profile'",
        ),
        reason:
            'archiveByProfile is expected to still carry the raw message '
            '— this documents why the checker is scoped to '
            'deactivateByProfile only, not the whole file.',
      );
    });
  });
}
