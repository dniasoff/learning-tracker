// Tests for `tool/schema_check.dart` (DNI-327 / Story 25.6).
//
// These tests build small fixture directories containing fake Drift table
// declarations, invoke the script as a subprocess, and assert the exit
// code + stderr output. This is an integration-style test: it shells out
// to `dart run` so we catch real CLI behaviour (exit codes, stderr).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `flutter test` runs with cwd = the package dir (`learning_tracker/`).
  // The repo root is one level up; the tool lives there.
  final repoRoot = Directory.current.parent.path;
  final scriptPath = '$repoRoot/tool/schema_check.dart';

  late Directory fixtureDir;

  setUp(() {
    fixtureDir = Directory.systemTemp.createTempSync('schema_check_test_');
  });

  tearDown(() {
    if (fixtureDir.existsSync()) {
      fixtureDir.deleteSync(recursive: true);
    }
  });

  Future<ProcessResult> runCheck({String? tablesDir, String? whitelist}) async {
    final args = <String>[
      'run',
      scriptPath,
      if (tablesDir != null) ...['--tables-dir', tablesDir],
      if (whitelist != null) ...['--whitelist', whitelist],
    ];
    return Process.run('dart', args, workingDirectory: repoRoot);
  }

  void writeTable(String fileName, String body) {
    File('${fixtureDir.path}/$fileName').writeAsStringSync(body);
  }

  test('exits 0 when whitelisted table satisfies both invariants', () async {
    writeTable('good.dart', '''
import 'package:drift/drift.dart';

class Good extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get name => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, name},
  ];
}
''');

    final result = await runCheck(
      tablesDir: fixtureDir.path,
      whitelist: 'Good',
    );

    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    expect(result.stdout.toString(), contains('schema_check OK'));
  });

  test('exits non-zero when profileId is missing from any key', () async {
    writeTable('bad_no_key.dart', '''
import 'package:drift/drift.dart';

class BadNoKey extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get name => text()();
  // NOTE: profileId is a plain column but appears in no PK / unique / index.
}
''');

    final result = await runCheck(
      tablesDir: fixtureDir.path,
      whitelist: 'BadNoKey',
    );

    expect(result.exitCode, isNonZero);
    expect(result.stderr.toString(), contains('BadNoKey'));
    expect(
      result.stderr.toString(),
      contains('profileId'),
      reason: 'stderr should name the missing concept',
    );
    expect(
      result.stderr.toString(),
      contains('Remediation:'),
      reason: 'failure output should include a remediation hint',
    );
  });

  test('exits non-zero when whitelisted table lacks a composite key', () async {
    writeTable('bad_no_composite.dart', '''
import 'package:drift/drift.dart';

class BadNoComposite extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId},
  ];
}
''');

    final result = await runCheck(
      tablesDir: fixtureDir.path,
      whitelist: 'BadNoComposite',
    );

    expect(result.exitCode, isNonZero);
    expect(result.stderr.toString(), contains('BadNoComposite'));
    expect(
      result.stderr.toString(),
      contains('composite'),
      reason: 'failure must point at the composite-index requirement',
    );
  });

  test('exits non-zero when a whitelisted table is missing', () async {
    // No fixture files — fixtureDir is empty.
    final result = await runCheck(
      tablesDir: fixtureDir.path,
      whitelist: 'ExpectedButMissing',
    );

    expect(result.exitCode, isNonZero);
    expect(result.stderr.toString(), contains('ExpectedButMissing'));
    expect(result.stderr.toString(), contains('<missing>'));
  });

  test(
    'explicit primaryKey containing profileId satisfies key check',
    () async {
      writeTable('explicit_pk.dart', '''
import 'package:drift/drift.dart';

class ExplicitPk extends Table {
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();
  IntColumn get dayOfWeek => integer()();

  @override
  Set<Column> get primaryKey => {profileId, curriculumId, dayOfWeek};
}
''');

      final result = await runCheck(
        tablesDir: fixtureDir.path,
        whitelist: 'ExplicitPk',
      );

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
    },
  );

  test('@TableIndex with profileId satisfies key check', () async {
    writeTable('outbox_like.dart', '''
import 'package:drift/drift.dart';

@TableIndex(name: 'outbox_profile_kind', columns: {#profileId, #entityKind})
class OutboxLike extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get entityKind => text()();
}
''');

    final result = await runCheck(
      tablesDir: fixtureDir.path,
      whitelist: 'OutboxLike',
    );

    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
  });

  test('default invocation passes against the live v1 schema', () async {
    // No --tables-dir / --whitelist: exercise the real defaults so the
    // tool is wired to actually check the repo.
    final result = await Process.run('dart', [
      'run',
      scriptPath,
    ], workingDirectory: repoRoot);
    expect(
      result.exitCode,
      0,
      reason:
          'live v1 schema must satisfy invariants.\n'
          'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
  });

  test('returns 2 when --tables-dir does not exist', () async {
    final result = await runCheck(
      tablesDir: '${fixtureDir.path}/does_not_exist',
      whitelist: 'Anything',
    );
    expect(result.exitCode, 2);
    expect(result.stderr.toString(), contains('not found'));
  });
}
