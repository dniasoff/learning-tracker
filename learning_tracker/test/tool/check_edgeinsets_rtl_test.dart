// Tests for `tool/check_edgeinsets_rtl.dart` (AUD-profiles-18 /
// AUD-tracks-13).
//
// The script lives in the repo-root `tool/` directory (not
// `learning_tracker/tool/`) and scans `learning_tracker/lib/` relative to
// the REPO ROOT — it backs the outer/root Makefile's AX-1 check, not the
// inner `learning_tracker/Makefile`. `flutter test` runs with cwd =
// `learning_tracker/`, so the script and its scan target are addressed via
// the repo root (the parent of `Directory.current`).
//
// Mirrors the fixture-based approach in `check_db_transactions_test.dart` /
// `check_dao_stateerror_messages_test.dart`: write a disposable multi-line
// `EdgeInsets.only(left:...)` fixture into the checker's scanned directory,
// run the script, assert it fires (AC1's "flags a deliberately-added
// multi-line EdgeInsets.only(left:...) fixture"), delete the fixture, assert
// a clean pass. This is the Rule-0 "demonstrate it fires on a deliberately-
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
  final repoRoot = Directory.current.parent.path;
  final scriptPath = '$repoRoot/tool/check_edgeinsets_rtl.dart';
  final fixtureFile = File(
    '$repoRoot/learning_tracker/lib/features/tracks/setup/presentation/'
    'widgets/_aud_tracks_13_check_edgeinsets_rtl_fixture.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: repoRoot);

  group('tool/check_edgeinsets_rtl.dart (AUD-profiles-18 / AUD-tracks-13)', () {
    setUp(() {
      // Guard against a prior failed run leaving the fixture behind.
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
    });

    tearDown(() {
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
    });

    test(
      'exits 0 on the real (fixed) tree — track_management_body.dart is no '
      'longer flagged (AUD-tracks-13 fixed it) and only the pre-existing, '
      'out-of-scope reward_configuration_screen.dart baseline remains',
      () async {
        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stdout.toString(), contains('check_edgeinsets_rtl OK'));
        expect(
          result.stdout.toString(),
          isNot(contains('track_management_body.dart')),
          reason:
              'track_management_body.dart was fixed by AUD-tracks-13 and '
              'removed from the baseline — it must not appear at all, '
              'baselined or otherwise.',
        );
        expect(
          result.stdout.toString(),
          // Re-pinned :111 -> :110 by the AppPalette theme migration, then
          // :110 -> :123 by the dark-mode legibility burndown (recolour of
          // reward_configuration_screen.dart shifted the lines down); the
          // site itself is unchanged, only its line number moved.
          contains('reward_configuration_screen.dart:123'),
          reason:
              'the pre-existing, out-of-scope baseline entry must still be '
              'suppressed (scope discipline — not this finding\'s site).',
        );
      },
    );

    test('AC1: a deliberately-added multi-line EdgeInsets.only(left:...) '
        'fixture flips the checker from clean to FAILED, and deleting it '
        'restores clean', () async {
      // The exact multi-line shape (open paren on its own line, left:/
      // right: on subsequent lines) that the OLD single-line grep
      // (`EdgeInsets\.only([^)]*(left|right):`) was blind to.
      fixtureFile.writeAsStringSync('''
import 'package:flutter/widgets.dart';

Widget buildAudTracks13Fixture() {
  return const Padding(
    padding: EdgeInsets.only(
      left: 4,
      right: 4,
      top: 2,
      bottom: 2,
    ),
    child: SizedBox(),
  );
}
''');

      final withFixture = await runCheck();
      expect(
        withFixture.exitCode,
        1,
        reason:
            'a fresh multi-line EdgeInsets.only(left:/right:) fixture '
            'must fail the checker.\n'
            'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
      );
      expect(
        withFixture.stdout.toString(),
        allOf(
          contains('_aud_tracks_13_check_edgeinsets_rtl_fixture.dart'),
          contains('non-baselined EdgeInsets.only(left:/right:)'),
        ),
      );

      fixtureFile.deleteSync();

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'deleting the fixture must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
      expect(clean.stdout.toString(), contains('check_edgeinsets_rtl OK'));
    });
  });
}
