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

  test('default invocation passes against the live v1 schema '
      '(PK/composite-index + FK-cascade, AUD-core-database-01)', () async {
    // No --tables-dir / --whitelist / --check-fk-cascade: exercise the
    // real defaults so the tool is wired to actually check the repo —
    // this covers both the PK/composite-index invariant AND the
    // FK-cascade invariant, since the latter defaults to ON.
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
    expect(result.stdout.toString(), contains('FK-cascade check clean'));
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
      'exits 0 when a profileId column declares the LearnerProfiles FK',
      () async {
        writeTable('has_fk.dart', '''
import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

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
      'the live v1 schema exemption list is exactly the AUD-core-database-01 '
      '6 tables — a new violator must fail even without touching the '
      'whitelist',
      () async {
        // Real tables dir, but shrink the fk-exempt list to empty so ANY
        // real table missing the FK fails. This proves the 6 known-gap
        // tables are the ONLY ones currently relying on the exemption —
        // if a 7th ever appears, this test starts failing until it's
        // deliberately added to `_fkCascadeExemptTables`.
        final result = await Process.run('dart', [
          'run',
          scriptPath,
          '--check-fk-cascade',
          'true',
          '--fk-exempt',
          '',
        ], workingDirectory: repoRoot);

        expect(result.exitCode, isNonZero);
        for (final table in [
          'CurriculumTracks',
          'DailyPlans',
          'Outbox',
          'PointConfigs',
          'ProfilePrograms',
          'StudyDayConfigs',
        ]) {
          expect(
            result.stderr.toString(),
            contains(table),
            reason:
                '$table is a known FK-cascade gap (AUD-core-database-01) and '
                'must be reported when the exemption list is emptied',
          );
        }
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
