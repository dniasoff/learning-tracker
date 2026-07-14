// Tests for `tool/check_notifications_duplicate_test_classes.dart`
// (AUD-t-notifications-03).
//
// Mirrors the fixture-based approach in
// `check_db_dao_loop_writes_test.dart`: write a disposable fixture file
// into the checker's scanned directory, run the script, assert it fires,
// delete the fixture, assert a clean pass. This is the Rule-0 "demonstrate
// it fires on a deliberately-broken fixture then passes clean" evidence,
// captured as a durable regression test rather than a one-off manual run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath =
      '$packageDir/tool/check_notifications_duplicate_test_classes.dart';
  final fixtureFile = File(
    '$packageDir/test/features/notifications/_tmp_aud_notifications_03_fixture_test.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  group('tool/check_notifications_duplicate_test_classes.dart '
      '(AUD-t-notifications-03)', () {
    test(
      'exits 0 on the real (fixed) tree — MockNotificationGateway is '
      'declared once (support/mock_notification_gateway.dart) and imported '
      'by notifications_screen_test.dart / ws5_two_layers_test.dart',
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

    test('AC: a NEW file redeclaring a public top-level class already defined '
        'elsewhere in test/features/notifications/ flips the checker from '
        'clean to FAILED, and deleting the fixture restores clean', () async {
      expect(
        fixtureFile.existsSync(),
        isFalse,
        reason: 'fixture must not already exist before this test runs',
      );

      try {
        // The exact defect shape AUD-t-notifications-03 found: a second
        // file independently redeclaring the shared mock's class name.
        fixtureFile.writeAsStringSync('''
class MockNotificationGateway {}

void main() {}
''');

        final withFixture = await runCheck();
        expect(
          withFixture.exitCode,
          1,
          reason:
              'a duplicate public top-level class name must fail the '
              'checker.\n'
              'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
        );
        expect(
          withFixture.stderr.toString(),
          allOf(
            contains('MockNotificationGateway'),
            contains('_tmp_aud_notifications_03_fixture_test.dart'),
            contains('support/mock_notification_gateway.dart'),
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
            'deleting the offending fixture must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('a fixture with a private (underscore) class of the same base name '
        'does NOT trip the checker — private classes are library-scoped and '
        'cannot collide across files', () async {
      try {
        fixtureFile.writeAsStringSync('''
class _MockNotificationGateway {}

void main() {}
''');

        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      }
    });
  });
}
