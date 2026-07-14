// Tests for `tool/check_notifications_sync_effect_overrides.dart`
// (AUD-t-notifications-01).
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
      '$packageDir/tool/check_notifications_sync_effect_overrides.dart';
  final fixtureFile = File(
    '$packageDir/test/features/notifications/_tmp_aud_notifications_01_fixture_test.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  group('tool/check_notifications_sync_effect_overrides.dart '
      '(AUD-t-notifications-01)', () {
    test('exits 0 on the real (fixed) tree — notifications_screen_test.dart '
        'and ws5_two_layers_test.dart both override the keepAlive sync '
        'effects', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('check passed'));
    });

    test(
      'AC: a NEW widget test that pumps NotificationsScreen without '
      'overriding both keepAlive sync-effect providers flips the checker '
      'from clean to FAILED, and deleting the fixture restores clean',
      () async {
        expect(
          fixtureFile.existsSync(),
          isFalse,
          reason: 'fixture must not already exist before this test runs',
        );

        try {
          // The exact defect shape AUD-t-notifications-01 found: a
          // ProviderScope with no override for either sync-effect
          // provider, pumping NotificationsScreen.
          fixtureFile.writeAsStringSync('''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  ProviderScope(overrides: [], child: const NotificationsScreen());
}
''');

          final withFixture = await runCheck();
          expect(
            withFixture.exitCode,
            1,
            reason:
                'a widget test pumping NotificationsScreen with no '
                'sync-effect overrides must fail the checker.\n'
                'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
          );
          expect(
            withFixture.stderr.toString(),
            allOf(
              contains('_tmp_aud_notifications_01_fixture_test.dart'),
              contains('reminderSyncEffectProvider'),
              contains('streakAlertSyncEffectProvider'),
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
      },
    );

    test('a fixture overriding both sync effects (the real fix shape) does '
        'NOT trip the checker', () async {
      try {
        fixtureFile.writeAsStringSync('''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/screens/notifications_screen.dart';

void main() {
  ProviderScope(
    overrides: [
      reminderSyncEffectProvider.overrideWith((ref) async {}),
      streakAlertSyncEffectProvider.overrideWith((ref) async {}),
    ],
    child: const NotificationsScreen(),
  );
}
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
