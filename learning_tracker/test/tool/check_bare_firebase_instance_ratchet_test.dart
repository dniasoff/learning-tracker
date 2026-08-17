// Tests for `tool/check_bare_firebase_instance_ratchet.dart` (Story 2.6,
// docs/planning/epics-firestore-migration-phase0.md — AD-2/AD-28 bare
// FirebaseFirestore.instance/FirebaseAuth.instance ban).
//
// Mirrors the fixture-based approach in
// the MCF-11 ratchet test: write a
// disposable fixture file directly into the checker's scanned directory
// (`lib/`, outside the not-yet-built AccountFirebase registry path — the
// AC's exact "red-demo" requirement (b)), run the script as a subprocess,
// assert it flags the planted violation and `make audit`'s underlying check
// would fail, then delete the fixture and assert a clean pass again. This
// is a checker-INVOKING test (Process.run + exit code/stdout assertions) —
// it never reads a lib/ file's source text into a Dart string itself (the
// checker subprocess does that, not this test file), so it does not
// consume R7 ratchet headroom.
//
// setUp also guards against a prior killed run leaving the fixture behind
// (same crash-safety note the story flags for this exact fixture-in-lib/
// pattern; see the Story 2.4 fixture-leak incident this story's brief
// warns about).

@Tags(['serial-tools'])
// serial-tools: this file's checker scans the WHOLE lib/ tree for the
// literal token `FirebaseFirestore.instance` — the exact token
// `check_firebase_confinement_test.dart`'s red-demo fixture also plants
// (that fixture is simultaneously a real Firebase-confinement AND a real
// bare-instance violation, by design). Under the parallel main lane, a
// transient fixture from ONE of these files can be alive while the OTHER
// file's checker subprocess scans lib/, corrupting its match count
// (verified: a flaky cross-file count-off-by-one). Serializing these
// alongside `audit_and_arb_parity_test.dart` (--concurrency=1, via `make
// test-serial-tools`) removes the race entirely.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath =
      '$packageDir/tool/check_bare_firebase_instance_ratchet.dart';
  final fixtureFile = File(
    '$packageDir/lib/features/scheduler/domain/models/'
    '_story_2_6_bare_instance_fixture.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  Future<ProcessResult> runReport() => Process.run('dart', [
    'run',
    scriptPath,
    '--report',
  ], workingDirectory: packageDir);

  group(
    'tool/check_bare_firebase_instance_ratchet.dart (Story 2.6, AD-2/AD-28)',
    () {
      setUp(() {
        // Guard against a prior failed/killed run leaving the fixture behind
        // in lib/ — see the story's crash-safety note for this exact
        // fixture-in-lib/ pattern (Story 2.4 left one behind previously).
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      });

      tearDown(() {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      });

      test(
        'exits 0 on the real (fixed) tree, at the tracked baseline',
        () async {
          final result = await runCheck();
          expect(
            result.exitCode,
            0,
            reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
          );
          expect(
            result.stdout.toString(),
            contains('Bare-Firebase-instance ratchet passed'),
          );
        },
      );

      test('the future AccountFirebase registry path is never counted, even '
          'though it is where the bare singleton would legitimately be '
          'resolved once Phase 1 lands it', () async {
        final result = await runReport();
        expect(
          result.stdout.toString(),
          isNot(contains('account_firebase.dart')),
          reason:
              'the exempt registry path must be carved out entirely — '
              'stdout=${result.stdout}',
        );
      });

      test(
        'a doc-comment merely mentioning FirebaseFirestore.instance/FirebaseAuth.instance '
        'in prose is not counted (comment-line filter)',
        () async {
          fixtureFile.writeAsStringSync('''
/// Story 2.6 fixture — a comment mentioning FirebaseFirestore.instance and
/// FirebaseAuth.instance in prose only, never in code. Must NOT trip the
/// ratchet. Deleted by the test's tearDown; must never be committed.
library;

// This file intentionally does not call FirebaseFirestore.instance or
// FirebaseAuth.instance directly.
class StoryTwoSixCommentOnlyFixture {
  const StoryTwoSixCommentOnlyFixture();
}
''');

          final result = await runCheck();
          expect(
            result.exitCode,
            0,
            reason:
                'a comment-only mention must not trip the ratchet.\n'
                'stdout=${result.stdout}\nstderr=${result.stderr}',
          );
        },
      );

      test(
        'AC (red-demo, "the grep must have teeth"): a fixture planting a bare '
        'FirebaseFirestore.instance touch outside the registry flips the '
        'checker from clean to FAILED; deleting the fixture restores a clean '
        'pass',
        () async {
          fixtureFile.writeAsStringSync('''
/// Story 2.6 red-demo fixture — deliberately reintroduces the AD-2
/// bare-instance landmine (a direct FirebaseFirestore.instance touch)
/// outside the AccountFirebase registry. Deleted by the test's tearDown;
/// must never be committed.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class StoryTwoSixBareInstanceFixture {
  FirebaseFirestore get db => FirebaseFirestore.instance;
}
''');

          final withFixture = await runCheck();
          expect(
            withFixture.exitCode,
            1,
            reason:
                'a fresh bare FirebaseFirestore.instance fixture outside the '
                'registry must fail the ratchet.\n'
                'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
          );
          expect(
            withFixture.stderr.toString(),
            allOf(
              contains('Bare-Firebase-instance ratchet FAILED'),
              contains('_story_2_6_bare_instance_fixture.dart'),
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
          expect(
            clean.stdout.toString(),
            contains('Bare-Firebase-instance ratchet passed'),
          );
        },
      );
    },
  );
}
