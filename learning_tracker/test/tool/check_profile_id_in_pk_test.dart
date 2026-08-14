// Tests for `tool/check_profile_id_in_pk.dart` (AUD-t-cross-06).
//
// These tests build small fixture directories containing fake Drift table
// declarations plus a fake `user_database.dart`-shaped `tables: [...]`
// list, invoke the script as a subprocess, and assert the exit code +
// stderr output. This is an integration-style test: it shells out to
// `dart run` so we catch real CLI behaviour (exit codes, stderr) — same
// approach as `schema_check_test.dart`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const dart = '/home/daniel/flutter/bin/dart';

  // `flutter test` runs with cwd = the package dir (`learning_tracker/`).
  final repoRoot = Directory.current.path;
  final scriptPath = '$repoRoot/tool/check_profile_id_in_pk.dart';

  late Directory fixtureDir;
  late Directory tablesDir;
  late File userDbFile;

  setUp(() {
    fixtureDir = Directory.systemTemp.createTempSync(
      'check_profile_id_in_pk_test_',
    );
    tablesDir = Directory('${fixtureDir.path}/tables')..createSync();
    userDbFile = File('${fixtureDir.path}/user_database.dart');
  });

  tearDown(() {
    if (fixtureDir.existsSync()) {
      fixtureDir.deleteSync(recursive: true);
    }
  });

  void writeUserDb(String tablesListBody) {
    userDbFile.writeAsStringSync('''
@DriftDatabase(
  tables: [
$tablesListBody
  ],
)
class UserDatabase extends _\$UserDatabase {}
''');
  }

  void writeTable(String fileName, String body) {
    File('${tablesDir.path}/$fileName').writeAsStringSync(body);
  }

  Future<ProcessResult> runCheck({String? exempt}) => Process.run(dart, [
    'run',
    scriptPath,
    '--user-database-file',
    userDbFile.path,
    '--tables-dir',
    tablesDir.path,
    if (exempt != null) ...['--exempt', exempt],
  ], workingDirectory: repoRoot);

  test('exits 0 when every non-exempt table has a profileId column', () async {
    writeUserDb('    Bookmarks,\n    Goals,');
    writeTable('bookmarks.dart', '''
import 'package:drift/drift.dart';

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
}
''');
    writeTable('goals.dart', '''
import 'package:drift/drift.dart';

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
}
''');

    final result = await runCheck();

    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    expect(result.stdout.toString(), contains('check_profile_id_in_pk OK'));
  });

  test('AC: a table with no profileId column and no exemption flips the '
      'checker from clean to FAILED — this is the exact AUD-t-cross-06 shape '
      '(TrackLearningOrder before the fix)', () async {
    writeUserDb('    Bookmarks,\n    TrackLearningOrder,');
    writeTable('bookmarks.dart', '''
import 'package:drift/drift.dart';

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
}
''');
    // The exact pre-fix shape: bare autoIncrement id, trackId/sefariaRef/
    // sortOrder, no profileId column at all.
    writeTable('track_learning_order.dart', '''
import 'package:drift/drift.dart';

class TrackLearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId => integer()();
  TextColumn get sefariaRef => text()();
  IntColumn get sortOrder => integer()();
}
''');

    final broken = await runCheck();
    expect(broken.exitCode, isNonZero);
    expect(broken.stderr.toString(), contains('TrackLearningOrder'));
    expect(
      broken.stderr.toString(),
      contains('profileId'),
      reason: 'failure output should name the missing concept',
    );

    // Restoring the profile-scoping column makes it clean again.
    writeTable('track_learning_order.dart', '''
import 'package:drift/drift.dart';

class TrackLearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId => integer()();
  TextColumn get sefariaRef => text()();
  IntColumn get sortOrder => integer()();
}
''');
    final fixed = await runCheck();
    expect(
      fixed.exitCode,
      0,
      reason: 'stdout=${fixed.stdout}\nstderr=${fixed.stderr}',
    );
  });

  test('exits 0 when a table with no profileId column IS on the exempt '
      'list', () async {
    writeUserDb('    TextDownloadStatuses,');
    writeTable('text_download_statuses.dart', '''
import 'package:drift/drift.dart';

class TextDownloadStatuses extends Table {
  TextColumn get curriculumId => text()();
}
''');

    final result = await runCheck(exempt: 'TextDownloadStatuses');

    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
  });

  test('exits 2 when a table named in tables: [...] has no source file '
      'under --tables-dir', () async {
    writeUserDb('    Ghost,');

    final result = await runCheck();

    expect(result.exitCode, 2);
    expect(result.stderr.toString(), contains('Ghost'));
  });

  test('returns 2 when --tables-dir does not exist', () async {
    writeUserDb('    Bookmarks,');
    final result = await Process.run(dart, [
      'run',
      scriptPath,
      '--user-database-file',
      userDbFile.path,
      '--tables-dir',
      '${fixtureDir.path}/does_not_exist',
    ], workingDirectory: repoRoot);
    expect(result.exitCode, 2);
    expect(result.stderr.toString(), contains('not found'));
  });

  test('the retired UserDatabase default is reported as unavailable', () async {
    // The live app now has only the content DB and device registry DB. The
    // old user-DB checker has no default target, so this obsolete premise is
    // asserted explicitly rather than pretending a user schema still exists.
    final result = await Process.run(dart, [
      'run',
      scriptPath,
    ], workingDirectory: repoRoot);
    expect(
      result.exitCode,
      2,
      reason:
          'the retired user-DB checker should report its missing target.\n'
          'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    expect(result.stderr.toString(), contains('user_database.dart not found'));
    expect(
      File('lib/core/database/content/content_database.dart').existsSync(),
      isTrue,
    );
    expect(
      File(
        'lib/core/database/registry/device_registry_database.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
