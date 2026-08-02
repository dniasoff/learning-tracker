// Tests for `tool/check_dependency_direction.dart` (Story 2.6,
// docs/planning/epics-firestore-migration-phase0.md — AD-23/AD-28
// dependency-direction gate: no lib/features/**|lib/domain/** file imports
// the data-access ring past a repository interface).
//
// Mirrors the fixture-based approach used by the other Story 2.6/2.4
// checker tests: write a disposable fixture file directly into the
// checker's scanned directory (lib/features/, outside any
// data/repositories/ implementation dir — the AC's exact "red-demo"
// requirement (c)), run the script as a subprocess, assert it flags the
// planted violation, then delete the fixture and assert a clean pass
// again. Checker-INVOKING test (Process.run + exit code/output
// assertions) — never reads a lib/ file's source text into a Dart string
// itself, so it does not consume R7 ratchet headroom.
//
// setUp also guards against a prior killed run leaving the fixture behind.

@Tags(['serial-tools'])
// serial-tools: this test writes/deletes fixture files under lib/features/
// while other checkers in the suite (e.g. the pre-existing Story 2.4
// tool/check_mcf11_autoincrement_id_in_payload_ratchet.dart, out of this
// story's scope to modify) recursively list + read the WHOLE lib/ tree
// without tolerating a path vanishing mid-scan (TOCTOU) — observed as a
// flaky cross-file crash under the parallel main lane. Serializing this
// file alongside `audit_and_arb_parity_test.dart` (--concurrency=1, via
// `make test-serial-tools`) removes the race entirely.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_dependency_direction.dart';
  final fixtureFile = File(
    '$packageDir/lib/features/scheduler/domain/models/'
    '_story_2_6_dependency_direction_fixture.dart',
  );
  final repositoryFixtureFile = File(
    '$packageDir/lib/features/scheduler/data/repositories/'
    '_story_2_6_repository_layer_fixture.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  Future<ProcessResult> runReport() => Process.run('dart', [
    'run',
    scriptPath,
    '--report',
  ], workingDirectory: packageDir);

  group('tool/check_dependency_direction.dart (Story 2.6, AD-23/AD-28)', () {
    setUp(() {
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      if (repositoryFixtureFile.existsSync()) {
        repositoryFixtureFile.deleteSync();
      }
    });

    tearDown(() {
      if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      if (repositoryFixtureFile.existsSync()) {
        repositoryFixtureFile.deleteSync();
      }
    });

    test('exits 0 on the real (fixed) tree — zero violations today', () async {
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        result.stdout.toString(),
        contains('Dependency-direction check passed'),
      );
    });

    test('a repository-implementation file (under data/repositories/) IS '
        'permitted to import the data-access ring directly (AD-23: R --> A '
        'is an allowed edge) — never flagged', () async {
      repositoryFixtureFile.createSync(recursive: true);
      repositoryFixtureFile.writeAsStringSync('''
/// Story 2.6 fixture — a repository-implementation file, permitted by
/// AD-23 to depend on the data-access ring directly. Deleted by the test's
/// tearDown; must never be committed.
library;

import 'package:learning_tracker/data/firestore/doc_ids.dart';

class StoryTwoSixRepositoryLayerFixture {
  String mintProfileId() => DocIds.mintProfileUlid();
}
''');

      final result = await runReport();
      expect(
        result.stdout.toString(),
        isNot(contains('_story_2_6_repository_layer_fixture.dart')),
        reason:
            'a data/repositories/ file must be exempt — '
            'stdout=${result.stdout}',
      );
    });

    test('AC (red-demo, "the grep must have teeth"): a fixture planting a '
        'lib/features/** import of the data-access ring, reaching past a '
        'repository interface, flips the checker from clean to FAILED; '
        'deleting the fixture restores a clean pass', () async {
      fixtureFile.writeAsStringSync('''
/// Story 2.6 red-demo fixture — deliberately reintroduces the AD-23
/// dependency-direction landmine: a lib/features/** file importing the
/// data-access ring directly, bypassing the repository interface.
/// Deleted by the test's tearDown; must never be committed.
library;

import 'package:learning_tracker/data/firestore/doc_ids.dart';

class StoryTwoSixDependencyDirectionFixture {
  String mintProfileId() => DocIds.mintProfileUlid();
}
''');

      final withFixture = await runCheck();
      expect(
        withFixture.exitCode,
        1,
        reason:
            'a fresh lib/features/ import of the data-access ring must '
            'fail the check.\n'
            'stdout=${withFixture.stdout}\nstderr=${withFixture.stderr}',
      );
      expect(
        withFixture.stderr.toString(),
        allOf(
          contains('Dependency-direction check FAILED'),
          contains('_story_2_6_dependency_direction_fixture.dart'),
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
        contains('Dependency-direction check passed'),
      );
    });
  });
}
