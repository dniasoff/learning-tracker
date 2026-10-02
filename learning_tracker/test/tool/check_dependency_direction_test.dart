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
//
// Sub-tracks story 1.1 (DNI-463, AD-35) extends this file with the
// pure-domain guard: one allowed and one forbidden fixture per forbidden
// import family under lib/domain/**, the edge cases (nested and generated
// files, relative/export/conditional spellings, no data/repositories/
// exemption inside lib/domain/), and the AC-4 wiring checks (make ci /
// GitHub Actions run the checker and propagate its nonzero exit). Domain
// fixtures live in a test-owned directory that tearDown deletes
// recursively, so a failing subprocess or assertion never leaves one
// behind.

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

  // Test-owned fixture root for the AD-35 domain-purity cases. Nested two
  // levels below an existing lib/domain/** directory so every case also
  // exercises the recursive scan. Deleted wholesale in setUp/tearDown.
  final domainFixtureRoot = Directory(
    '$packageDir/lib/domain/learner_state/_dni_463_purity_fixture',
  );

  void cleanDomainFixtures() {
    if (domainFixtureRoot.existsSync()) {
      domainFixtureRoot.deleteSync(recursive: true);
    }
  }

  /// Writes a domain fixture at [relPath] (relative to
  /// [domainFixtureRoot]) whose only directive is [directive].
  File plantDomainFixture(String relPath, String directive) {
    final file = File('${domainFixtureRoot.path}/$relPath')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
/// DNI-463 domain-purity fixture. Deleted by the test's tearDown; must
/// never be committed.
library;

$directive

class Dni463PurityFixture {}
''');
    return file;
  }

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

  group('tool/check_dependency_direction.dart — AD-35 pure-domain guard '
      '(sub-tracks story 1.1, DNI-463)', () {
    setUp(cleanDomainFixtures);
    tearDown(cleanDomainFixtures);

    // (family label, allowed near-miss import, forbidden import). Each
    // allowed import sits right next to its family's prefix so the
    // passing fixture proves the matcher is not over-broad.
    const families = <(String, String, String)>[
      (
        'cloud_firestore',
        "import 'package:learning_tracker/domain/learner_state/ports/"
            "ports.dart';",
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      ),
      (
        'firebase_*',
        "import 'package:collection/collection.dart';",
        "import 'package:firebase_auth/firebase_auth.dart';",
      ),
      (
        'flutter/',
        "import 'package:meta/meta.dart';",
        "import 'package:flutter/foundation.dart';",
      ),
      (
        'flutter_riverpod',
        "import 'dart:async';",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      ),
      (
        'riverpod*',
        "import 'dart:collection';",
        "import 'package:riverpod_annotation/riverpod_annotation.dart';",
      ),
      (
        'learning_tracker/data/**',
        "import 'package:learning_tracker/domain/learner_state/"
            "learner_state.dart';",
        "import 'package:learning_tracker/data/repositories/"
            "firestore_completion_repository.dart';",
      ),
    ];

    test('AC-4: the checker passes on the tree with both placeholder '
        'libraries present', () async {
      expect(
        File(
          '$packageDir/lib/domain/learner_state/learner_state.dart',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '$packageDir/lib/domain/learner_state/ports/ports.dart',
        ).existsSync(),
        isTrue,
      );
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

    for (final (family, allowed, forbidden) in families) {
      test('AC-3 [$family]: an allowed import passes; a forbidden '
          'import fails naming the family', () async {
        final slug = family.replaceAll(RegExp('[^a-z]+'), '_');

        final passing = plantDomainFixture('nested/${slug}_ok.dart', allowed);
        final ok = await runCheck();
        expect(
          ok.exitCode,
          0,
          reason:
              'allowed import "$allowed" must pass.\n'
              'stdout=${ok.stdout}\nstderr=${ok.stderr}',
        );
        passing.deleteSync();

        plantDomainFixture('nested/${slug}_bad.dart', forbidden);
        final bad = await runCheck();
        expect(
          bad.exitCode,
          1,
          reason:
              'forbidden import "$forbidden" must fail.\n'
              'stdout=${bad.stdout}\nstderr=${bad.stderr}',
        );
        expect(
          bad.stderr.toString(),
          allOf(
            contains('Dependency-direction check FAILED'),
            contains('[AD-35 domain purity: $family]'),
            contains('${slug}_bad.dart'),
          ),
        );
      });
    }

    test('edge: flutter_riverpod is its own family, not swallowed by the '
        'flutter/ prefix (and flutter/ does not match flutter_*)', () async {
      plantDomainFixture(
        'fr.dart',
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      );
      final result = await runReport();
      final out = result.stdout.toString();
      expect(out, contains('[AD-35 domain purity: flutter_riverpod]'));
      expect(out, isNot(contains('[AD-35 domain purity: flutter/]')));
    });

    test('edge: core riverpod, nested and generated files, relative, export '
        'and conditional spellings, and a domain data/repositories/ dir are '
        'all caught — nothing is exempt under lib/domain/**', () async {
      plantDomainFixture(
        'core_riverpod.dart',
        "import 'package:riverpod/riverpod.dart';",
      );
      plantDomainFixture(
        'a/b/c/deeply_nested.dart',
        "import 'package:cloud_firestore/cloud_firestore.dart';",
      );
      plantDomainFixture(
        'generated.g.dart',
        "import 'package:firebase_core/firebase_core.dart';",
      );
      plantDomainFixture(
        'generated.freezed.dart',
        "import 'package:flutter/widgets.dart';",
      );
      // lib/domain/learner_state/_dni_463_purity_fixture/relative.dart
      // -> ../../../data/firestore/doc_ids.dart == lib/data/firestore/...
      plantDomainFixture(
        'relative.dart',
        "import '../../../data/firestore/doc_ids.dart';",
      );
      plantDomainFixture(
        're_export.dart',
        "export 'package:firebase_analytics/firebase_analytics.dart';",
      );
      plantDomainFixture(
        'multiline_conditional.dart',
        "import 'dart:core'\n"
            "    if (dart.library.ui) 'package:flutter/painting.dart';",
      );
      plantDomainFixture(
        'data/repositories/not_exempt.dart',
        "import 'package:learning_tracker/data/firestore/conflict.dart';",
      );

      final result = await runReport();
      final out = result.stdout.toString();
      for (final (file, family) in const [
        ('core_riverpod.dart', 'riverpod*'),
        ('deeply_nested.dart', 'cloud_firestore'),
        ('generated.g.dart', 'firebase_*'),
        ('generated.freezed.dart', 'flutter/'),
        ('relative.dart', 'learning_tracker/data/**'),
        ('re_export.dart', 'firebase_*'),
        ('multiline_conditional.dart', 'flutter/'),
        ('not_exempt.dart', 'learning_tracker/data/**'),
      ]) {
        expect(
          out
              .split('\n')
              .where(
                (l) =>
                    l.contains(file) &&
                    l.contains('[AD-35 domain purity: $family]'),
              ),
          isNotEmpty,
          reason: '$file must be flagged as $family.\nstdout=$out',
        );
      }
      expect(out, contains('--- 8 dependency-direction violation(s)'));
    });

    test('edge: commented-out forbidden imports (line, block, nested '
        'block) are not directives and pass; a "/*" inside a string does not '
        'swallow the allowed import after it', () async {
      plantDomainFixture(
        'commented.dart',
        "// import 'package:flutter/foundation.dart';\n"
            "/*\nimport 'package:cloud_firestore/cloud_firestore.dart';\n"
            "/* nested */ import 'package:riverpod/riverpod.dart';\n*/\n"
            "import 'dart:async'; // see lib/domain/**/*.dart\n"
            "const glob = 'lib/domain/**';",
      );
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
    });

    test('edge: an inline block comment before a forbidden import, or a '
        '"/*" inside an earlier string, cannot hide it', () async {
      plantDomainFixture(
        'inline_comment.dart',
        "/* pure? */ import 'package:flutter_riverpod/flutter_riverpod.dart';",
      );
      plantDomainFixture(
        'string_then_import.dart',
        "import 'dart:core' show String;\n"
            "@Deprecated('unterminated /* inside a string')\n"
            "import 'package:firebase_core/firebase_core.dart';",
      );
      final result = await runReport();
      final out = result.stdout.toString();
      expect(
        out,
        allOf(
          contains('inline_comment.dart'),
          contains('[AD-35 domain purity: flutter_riverpod]'),
          contains('string_then_import.dart'),
          contains('[AD-35 domain purity: firebase_*]'),
        ),
      );
    });
  });

  group('AC-4: the pure-domain gate is wired into make ci and GitHub Actions '
      'CI as a hard gate (DNI-463)', () {
    setUp(cleanDomainFixtures);
    tearDown(cleanDomainFixtures);

    test('make ci depends on check-dependency-direction, and that target '
        'propagates the checker\'s nonzero exit', () async {
      final dryRun = await Process.run('make', [
        '-n',
        'ci',
      ], workingDirectory: packageDir);
      expect(
        dryRun.stdout.toString(),
        contains('dart run tool/check_dependency_direction.dart'),
        reason:
            'make -n ci must include the checker.\n'
            'stderr=${dryRun.stderr}',
      );

      plantDomainFixture(
        'make_gate.dart',
        "import 'package:flutter/foundation.dart';",
      );
      final failing = await Process.run('make', [
        'check-dependency-direction',
      ], workingDirectory: packageDir);
      expect(
        failing.exitCode,
        isNot(0),
        reason:
            'a domain violation must fail the make target.\n'
            'stdout=${failing.stdout}\nstderr=${failing.stderr}',
      );

      cleanDomainFixtures();
      final passing = await Process.run('make', [
        'check-dependency-direction',
      ], workingDirectory: packageDir);
      expect(
        passing.exitCode,
        0,
        reason: 'stdout=${passing.stdout}\nstderr=${passing.stderr}',
      );
    });

    test('the GitHub Actions CI workflow runs the checker in a step that '
        'cannot swallow its exit code', () {
      final workflow = File(
        '$packageDir/../.github/workflows/ci.yml',
      ).readAsStringSync();
      final steps = workflow.split(RegExp(r'\n\s*- name: '));
      final gateSteps = steps
          .where(
            (s) => s.contains('dart run tool/check_dependency_direction.dart'),
          )
          .toList();
      expect(gateSteps, isNotEmpty, reason: 'no CI step runs the checker');
      for (final step in gateSteps) {
        expect(step, isNot(contains('continue-on-error: true')));
        expect(step, isNot(contains('|| true')));
        expect(step, contains('working-directory: learning_tracker'));
      }
    });
  });
}
