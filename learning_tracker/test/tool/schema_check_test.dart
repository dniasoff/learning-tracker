// Tests for `tool/schema_check.dart` (DNI-327 / Story 25.6).
//
// These tests build small fixture directories containing fake Drift table
// declarations, invoke the script as a subprocess, and assert the exit
// code + stderr output. This is an integration-style test: it shells out
// to `dart run` so we catch real CLI behaviour (exit codes, stderr).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Resolved via FLUTTER_ROOT (set by `flutter test` for every child test
  // process) instead of a path hardcoded to one developer's machine/FVM
  // install (TQ-5) — see test/helpers/golden_font_loader.dart's
  // materialFontsDir() for the same pattern.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final dart = flutterRoot != null && flutterRoot.isNotEmpty
      ? '$flutterRoot/bin/cache/dart-sdk/bin/dart'
      : 'dart';

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

  Future<ProcessResult> runCheck({
    String? tablesDir,
    String? whitelist,
    // AUD-core-database-01: the FK-cascade check is ON by default (it must
    // be, so the bare `dart run tool/schema_check.dart` invocation used by
    // the Makefile/CI actually checks it). These PK/composite-index tests
    // use synthetic single-table fixtures that don't declare a real
    // `LearnerProfiles` FK and aren't exercising that invariant, so they opt
    // out explicitly — see the dedicated 'FK-cascade check' group below for
    // FK-cascade coverage.
    bool checkFkCascade = false,
    String? fkExempt,
  }) async {
    final args = <String>[
      'run',
      scriptPath,
      if (tablesDir != null) ...['--tables-dir', tablesDir],
      if (whitelist != null) ...['--whitelist', whitelist],
      '--check-fk-cascade',
      checkFkCascade.toString(),
      if (fkExempt != null) ...['--fk-exempt', fkExempt],
    ];
    return Process.run(dart, args, workingDirectory: repoRoot);
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

  test('current content tables can be checked explicitly', () async {
    // The old v1 user-table defaults are obsolete. Exercise the checker
    // against the current database boundary with an explicit empty profile
    // whitelist.
    final result = await Process.run(dart, [
      'run',
      scriptPath,
      '--tables-dir',
      'learning_tracker/lib/core/database/tables',
      '--whitelist',
      '',
      '--check-fk-cascade',
      'false',
    ], workingDirectory: repoRoot);
    expect(
      result.exitCode,
      0,
      reason:
          'current content tables should satisfy the checker invocation.\n'
          'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    expect(result.stdout.toString(), contains('schema_check OK'));
  });

  // ── AUD-core-database-01: FK-cascade check ─────────────────────────────
  //
  // A profile-scoped table's `profileId` column must carry an
  // `.references(LearnerProfiles, ...)` FK, UNLESS it is named in
  // `_fkCascadeExemptTables` — a deny-by-default check that scans every
  // parsed table, not just ones on the PK/composite-index whitelist. This
  // is what would have caught curriculum_tracks/daily_plans/outbox/
  // point_configs/profile_programs/study_day_configs missing the FK before
  // it became a silent tutored-mirror data-retention gap.

  group('FK-cascade check (AUD-core-database-01)', () {
    test('exits non-zero when a profileId column has no LearnerProfiles FK '
        'and is not exempt', () async {
      writeTable('missing_fk.dart', '''
import 'package:drift/drift.dart';

class MissingFk extends Table {
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
        whitelist: 'MissingFk',
        checkFkCascade: true,
      );

      expect(result.exitCode, isNonZero);
      expect(result.stderr.toString(), contains('MissingFk'));
      expect(
        result.stderr.toString(),
        contains('FK-cascade'),
        reason: 'failure output should name the FK-cascade invariant',
      );
      expect(
        result.stderr.toString(),
        contains('AUD-core-database-01'),
        reason: 'failure output should point at the remediation doc',
      );
    });

    test(
      'exits 0 when a profileId column declares the required cascade FK',
      () async {
        writeTable('has_fk.dart', '''
import 'package:drift/drift.dart';

// Synthetic reference target: the live app no longer has a user Drift DB,
// but the checker still needs to validate this FK shape in fixture tests.
class LearnerProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
}

class HasFk extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, name},
  ];
}
''');

        final result = await runCheck(
          tablesDir: fixtureDir.path,
          whitelist: 'HasFk',
          checkFkCascade: true,
        );

        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      },
    );

    test('exits 0 when a profileId column has no FK but the table is listed '
        'in --fk-exempt', () async {
      writeTable('exempted.dart', '''
import 'package:drift/drift.dart';

class Exempted extends Table {
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
        whitelist: 'Exempted',
        checkFkCascade: true,
        fkExempt: 'Exempted',
      );

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
    });

    test(
      'a table WITHOUT a profileId column is never flagged, exempt or not',
      () async {
        writeTable('no_profile_id.dart', '''
import 'package:drift/drift.dart';

class NoProfileId extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}
''');

        final result = await runCheck(
          tablesDir: fixtureDir.path,
          // Empty whitelist: this test targets ONLY the FK-cascade check —
          // NoProfileId would also fail the (unrelated) PK/composite-index
          // check if whitelisted for it, which is not what this test is
          // about.
          whitelist: '',
          checkFkCascade: true,
        );

        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      },
    );

    test(
      'the checker runs against the current content-table directory',
      () async {
        // The old v1 user-table exemption list is obsolete. Exercise the
        // checker against the current database boundary explicitly instead.
        final result = await Process.run(dart, [
          'run',
          scriptPath,
          '--tables-dir',
          'learning_tracker/lib/core/database/tables',
          '--whitelist',
          '',
        ], workingDirectory: repoRoot);

        expect(
          result.exitCode,
          0,
          reason:
              'current content-table directory should be a valid checker input.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stdout.toString(), contains('schema_check OK'));
      },
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
