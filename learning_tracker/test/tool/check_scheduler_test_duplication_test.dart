// Tests for `tool/check_scheduler_test_duplication.dart`
// (AUD-t-scheduler-01).
//
// Mirrors the fixture-based approach in
// `check_notifications_duplicate_test_classes_test.dart`: write disposable
// fixture files into the checker's scanned directory, run the script,
// assert it fires, delete the fixtures, assert a clean pass. This is the
// Rule-0 "demonstrate it fires on a deliberately-broken fixture then
// passes clean" evidence, captured as a durable regression test rather
// than a one-off manual run.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (learning_tracker/).
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_scheduler_test_duplication.dart';
  final fixtureA = File(
    '$packageDir/test/features/scheduler/domain/models/'
    '_tmp_aud_scheduler_01_fixture_a_test.dart',
  );
  final fixtureB = File(
    '$packageDir/test/features/scheduler/domain/models/'
    '_tmp_aud_scheduler_01_fixture_b_test.dart',
  );

  Future<ProcessResult> runCheck() =>
      Process.run('dart', ['run', scriptPath], workingDirectory: packageDir);

  group('tool/check_scheduler_test_duplication.dart (AUD-t-scheduler-01)', () {
    test('exits 0 on the real (fixed) tree — none of the three '
        'AUD-t-scheduler-01 duplicate pairs remain '
        '(goal_entity_extended/extra, scheduler_content_repository '
        'impl/domain, daily_task_generator extended/generate_all)', () async {
      expect(
        fixtureA.existsSync() || fixtureB.existsSync(),
        isFalse,
        reason: 'fixtures must not already exist before this test runs',
      );
      final result = await runCheck();
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('check passed'));
    });

    test('AC: two files independently landing an identical test name under '
        'the same group name flips the checker from clean to FAILED, and '
        'deleting the fixtures restores clean', () async {
      try {
        // Same group name, same test NAME, different local variable
        // names/values — the exact shape of this finding's
        // daily_task_generator 'returns empty list for empty curricula
        // list' evidence.
        fixtureA.writeAsStringSync('''
void main() {
  group('FixtureThing.exactNameDup', () {
    test('returns doubled value for positive input', () {
      final x = 21;
      final result = x * 2;
      expect(result, 42);
      expect(result, greaterThan(0));
      expect(result, isA<int>());
    });
  });
}
''');
        fixtureB.writeAsStringSync('''
void main() {
  group('FixtureThing.exactNameDup', () {
    test('returns doubled value for positive input', () {
      final y = 21;
      final outcome = y * 2;
      expect(outcome, 42);
    });
  });
}
''');

        final withFixtures = await runCheck();
        expect(
          withFixtures.exitCode,
          1,
          reason:
              'an identical test name under the same group name in two '
              'files must fail the checker.\n'
              'stdout=${withFixtures.stdout}\nstderr=${withFixtures.stderr}',
        );
        expect(
          withFixtures.stderr.toString(),
          allOf(
            contains('fixturething.exactnamedup'),
            contains('identical test name'),
            contains('_tmp_aud_scheduler_01_fixture_a_test.dart'),
            contains('_tmp_aud_scheduler_01_fixture_b_test.dart'),
          ),
        );
      } finally {
        if (fixtureA.existsSync()) fixtureA.deleteSync();
        if (fixtureB.existsSync()) fixtureB.deleteSync();
      }

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'deleting the offending fixtures must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('AC: two files with differently-NAMED tests under the same group '
        'name but a >=80%-similar body also flips the checker from clean to '
        'FAILED — the exact shape of the goal_entity_extended/extra '
        '"firestoreId contains ..." pairs and the scheduler_content_repository '
        '"filters ..." pair this finding fixed', () async {
      try {
        fixtureA.writeAsStringSync('''
void main() {
  group('FixtureThing.bodySimilarDup', () {
    test('builds a widget with the expected label text', () {
      final config = FixtureConfig(label: 'Hello', count: 3);
      final widget = FixtureThing.build(config);
      expect(widget.label, 'Hello');
      expect(widget.count, 3);
      expect(widget.isValid, isTrue);
    });
  });
}
''');
        fixtureB.writeAsStringSync('''
void main() {
  group('FixtureThing.bodySimilarDup', () {
    test('produces a widget whose label matches the input', () {
      final cfg = FixtureConfig(label: 'Hello', count: 3);
      final w = FixtureThing.build(cfg);
      expect(w.label, 'Hello');
      expect(w.count, 3);
      expect(w.isValid, isTrue);
    });
  });
}
''');

        final withFixtures = await runCheck();
        expect(
          withFixtures.exitCode,
          1,
          reason:
              'a >=80%-similar test body under the same group name in two '
              'files must fail the checker.\n'
              'stdout=${withFixtures.stdout}\nstderr=${withFixtures.stderr}',
        );
        expect(
          withFixtures.stderr.toString(),
          allOf(
            contains('fixturething.bodysimilardup'),
            contains('similar body'),
          ),
        );
      } finally {
        if (fixtureA.existsSync()) fixtureA.deleteSync();
        if (fixtureB.existsSync()) fixtureB.deleteSync();
      }

      final clean = await runCheck();
      expect(
        clean.exitCode,
        0,
        reason:
            'deleting the offending fixtures must restore a clean pass.\n'
            'stdout=${clean.stdout}\nstderr=${clean.stderr}',
      );
    });

    test('a fixture pair with genuinely DIFFERENT test names and bodies under '
        'the same group name does NOT trip the checker — sharing a group '
        'name alone is not a violation', () async {
      try {
        fixtureA.writeAsStringSync('''
void main() {
  group('FixtureThing.distinctBehavior', () {
    test('rejects a negative count', () {
      expect(() => FixtureConfig(label: 'x', count: -1), throwsArgumentError);
    });
  });
}
''');
        fixtureB.writeAsStringSync('''
void main() {
  group('FixtureThing.distinctBehavior', () {
    test('accepts a zero count as valid', () {
      final cfg = FixtureConfig(label: 'zero-count', count: 0);
      final widget = FixtureThing.build(cfg);
      expect(widget.isValid, isTrue);
      expect(widget.count, 0);
    });
  });
}
''');

        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        if (fixtureA.existsSync()) fixtureA.deleteSync();
        if (fixtureB.existsSync()) fixtureB.deleteSync();
      }
    });
  });
}
