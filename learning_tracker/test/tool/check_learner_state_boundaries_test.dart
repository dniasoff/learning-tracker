// AC-8 (DNI-464): the new repository stays in the data ring and the domain
// ports stay pure. Runs the two structural gates as processes on the real
// tree (which now contains lib/domain/learner_state/** and the two new
// lib/data/repositories/** files), then plants one disposable fixture per
// boundary under lib/domain/learner_state/ to prove each gate has teeth
// for this exact new directory. Checker-INVOKING test (Process.run + exit
// code), never a source-text assertion.

@Tags(['serial-tools'])
// serial-tools: plants fixture files under lib/ while other checkers may be
// scanning lib/ — run serially (`make test-serial-tools`), like the other
// fixture-planting checker tests.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final dependencyScript = '$packageDir/tool/check_dependency_direction.dart';
  final confinementScript = '$packageDir/tool/check_firebase_confinement.dart';
  final fixture = File(
    '$packageDir/lib/domain/learner_state/ports/'
    '_dni464_boundary_fixture.dart',
  );

  Future<ProcessResult> run(String script, [List<String> args = const []]) =>
      Process.run('dart', [
        'run',
        script,
        ...args,
      ], workingDirectory: packageDir);

  void clean() {
    if (fixture.existsSync()) fixture.deleteSync();
  }

  setUp(clean);
  tearDown(clean);

  group('new repository stays in data ring and domain ports stay pure', () {
    test('both checkers pass on the real tree', () async {
      for (final (script, args) in [
        (dependencyScript, const <String>[]),
        (confinementScript, const ['--storage']),
        (confinementScript, const ['--auth']),
      ]) {
        final result = await run(script, args);
        expect(
          result.exitCode,
          0,
          reason: '$script $args\n${result.stdout}\n${result.stderr}',
        );
      }
    });

    test('a learner_state port importing the data-access ring fails the '
        'dependency-direction gate', () async {
      fixture.writeAsStringSync(
        "import 'package:learning_tracker/data/firestore/doc_ids.dart';\n"
        'void fixture() => DocIds;\n',
      );
      final result = await run(dependencyScript);
      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect(
        '${result.stdout}${result.stderr}',
        contains('_dni464_boundary_fixture.dart'),
      );
    });

    test('a learner_state file importing cloud_firestore fails the '
        'Firebase-confinement gate', () async {
      fixture.writeAsStringSync(
        "import 'package:cloud_firestore/cloud_firestore.dart';\n"
        'FieldValue fixture() => FieldValue.serverTimestamp();\n',
      );
      final result = await run(confinementScript, const ['--storage']);
      expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
      expect(
        '${result.stdout}${result.stderr}',
        contains('_dni464_boundary_fixture.dart'),
      );
    });
  });
}
