// Tests for `tool/check_firebase_confinement.dart` (Story 2.6,
// docs/planning/epics-firestore-migration-phase0.md — AD-3/AD-28 retargeted
// no-firebase-outside-core gate, backing `make audit` checks 1/15 and
// 2/15).
//
// Mirrors the fixture-based approach used by the other Story 2.6/2.4
// checker tests: write a disposable fixture file directly into the
// checker's scanned directory (lib/features/, well outside the allow-list
// — the AC's exact "red-demo" requirement (a): "a cloud_firestore import in
// a feature file"), run the script as a subprocess, assert it flags the
// planted violation, then delete the fixture and assert a clean pass
// again. Checker-INVOKING test (Process.run + exit code/output
// assertions) — never reads a lib/ file's source text into a Dart string
// itself, so it does not consume R7 ratchet headroom.
//
// setUp also guards against a prior killed run leaving the fixture behind.

@Tags(['serial-tools'])
// serial-tools: this file's --storage checker scans the WHOLE lib/ tree,
// and this file's own red-demo fixture plants a literal
// `FirebaseFirestore.instance` — the exact token
// `check_bare_firebase_instance_ratchet_test.dart`'s checker also scans
// for. Under the parallel main lane, a transient fixture from ONE of these
// files can be alive while the OTHER file's checker subprocess scans
// lib/, corrupting its match count (verified: a flaky cross-file
// count-off-by-one). Serializing these alongside
// `audit_and_arb_parity_test.dart` (--concurrency=1, via `make
// test-serial-tools`) removes the race entirely.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_firebase_confinement.dart';
  final fixtureFile = File(
    '$packageDir/lib/features/scheduler/domain/models/'
    '_story_2_6_firebase_confinement_fixture.dart',
  );

  Future<ProcessResult> runCheck(String mode) => Process.run('dart', [
    'run',
    scriptPath,
    mode,
  ], workingDirectory: packageDir);

  Future<ProcessResult> runReport(String mode) => Process.run('dart', [
    'run',
    scriptPath,
    mode,
    '--report',
  ], workingDirectory: packageDir);

  group('tool/check_firebase_confinement.dart (Story 2.6, AD-3/AD-28)', () {
    setUp(() {
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
    });

    tearDown(() {
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
    });

    test('--auth exits 0 on the real (fixed) tree', () async {
      final result = await runCheck('--auth');
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stdout.toString(),
        contains('Firebase-confinement check (firebase_auth import) passed'),
      );
    });

    test('--storage exits 0 on the real (fixed) tree', () async {
      final result = await runCheck('--storage');
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stdout.toString(),
        contains(
          'Firebase-confinement check (FirebaseFirestore/FirebaseStorage/cloud_firestore symbol) passed',
        ),
      );
    });

    test(
      'the known pre-existing offender (lib/core/providers/firebase_providers.dart, '
      'surfaced by retiring the lib/core/providers/ carve-out) is narrowly '
      'whitelisted and never reported by --storage',
      () async {
        final result = await runReport('--storage');
        expect(
          result.stdout.toString(),
          isNot(contains('firebase_providers.dart')),
          reason:
              'the documented narrow whitelist entry must suppress this '
              'one file — stdout=${result.stdout}',
        );
      },
    );

    test('a doc-comment merely mentioning cloud_firestore/FirebaseFirestore in '
        'prose is not counted by --storage (comment-line filter)', () async {
      fixtureFile.writeAsStringSync('''
/// Story 2.6 fixture — a comment mentioning cloud_firestore and
/// FirebaseFirestore in prose only, never in code. Must NOT trip the
/// --storage check. Deleted by the test's tearDown; must never be
/// committed.
library;

// This file intentionally does not import cloud_firestore directly.
class StoryTwoSixCommentOnlyFixture {
  const StoryTwoSixCommentOnlyFixture();
}
''');

      final result = await runCheck('--storage');
      expect(
        result.exitCode,
        0,
        reason:
            'a comment-only mention must not trip the check.\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
    });

    test('AC (red-demo, "the grep must have teeth"): fixture (a) — a '
        'cloud_firestore import in a feature file — flips --storage from '
        'clean to FAILED; deleting the fixture restores a clean pass', () async {
      fixtureFile.writeAsStringSync('''
/// Story 2.6 red-demo fixture — deliberately reintroduces the AD-3
/// Firebase-confinement landmine: a lib/features/** file importing
/// cloud_firestore directly. Deleted by the test's tearDown; must never be
/// committed.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class StoryTwoSixFirebaseConfinementFixture {
  FirebaseFirestore get db => FirebaseFirestore.instance;
}
''');

      final withFixture = await runCheck('--storage');
      expect(
        withFixture.exitCode,
        1,
        reason:
            'a fresh cloud_firestore import in a feature file must fail '
            'the check.\n'
            'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
      );
      expect(
        withFixture.stderr.toString(),
        allOf(
          contains('Firebase-confinement check FAILED'),
          contains('_story_2_6_firebase_confinement_fixture.dart'),
        ),
      );

      fixtureFile.deleteSync();

      final clean = await runCheck('--storage');
      expect(
        clean.exitCode,
        0,
        reason:
            'deleting the fixture must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
      expect(
        clean.stdout.toString(),
        contains(
          'Firebase-confinement check (FirebaseFirestore/FirebaseStorage/cloud_firestore symbol) passed',
        ),
      );
    });
  });
}
