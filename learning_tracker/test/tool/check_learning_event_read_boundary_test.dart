// Tests for `tool/check_learning_event_read_boundary.dart` (DNI-474 AC-2:
// a `learning_events` query is accepted only below lib/data/repositories/;
// LearnerState consumers do not import the query implementation).
//
// Each case runs the checker as a subprocess against a disposable FIXTURE
// ROOT (`--root`) in the system temp dir, so nothing is written into the
// real lib/ tree; one case runs it on the real tree.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final script = '$packageDir/tool/check_learning_event_read_boundary.dart';
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('le_boundary_'));
  tearDown(() => root.deleteSync(recursive: true));

  void plant(String path, String source) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(source);
  }

  Future<ProcessResult> run([String? dir]) => Process.run('dart', [
    'run',
    script,
    '--root',
    dir ?? root.path,
  ], workingDirectory: packageDir);

  test('the real tree is clean', () async {
    final result = await run(packageDir);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('a query below lib/data/repositories/ is accepted', () async {
    plant(
      'lib/data/repositories/firestore_learning_event_repository.dart',
      "const kLearningEventsCollection = 'learning_events';\n"
          "String path(String p) => 'users/u/learner_profiles/\$p/learning_events';\n",
    );
    plant(
      'lib/data/firestore/providers.dart',
      "import 'package:x/data/repositories/firestore_learning_event_repository.dart';\n",
    );
    final result = await run();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('Q1: a collection literal or path segment outside the repository '
      'layer fails', () async {
    plant(
      'lib/features/progress/presentation/providers/bad.dart',
      "final a = 'learning_events';\n"
          "final b = 'users/u/learner_profiles/p/learning_events';\n",
    );
    final result = await run();
    expect(result.exitCode, 1);
    expect(result.stderr, contains('[Q1] lib/features/progress'));
    expect('[Q1]'.allMatches(result.stderr as String), hasLength(2));
  });

  test('Q2: the collection constant outside the repository layer '
      'fails', () async {
    plant(
      'lib/features/learner_state/data/bad.dart',
      'final c = kLearningEventsCollection;\n',
    );
    final result = await run();
    expect(result.exitCode, 1);
    expect(result.stderr, contains('[Q2]'));
  });

  test('Q3: importing the Firestore implementation outside lib/data/ '
      'fails', () async {
    plant(
      'lib/features/progress/domain/bad.dart',
      "import 'package:learning_tracker/data/repositories/"
          "firestore_learning_event_repository.dart';\n",
    );
    final result = await run();
    expect(result.exitCode, 1);
    expect(result.stderr, contains('[Q3]'));
  });

  test('comments and prose strings that merely mention the collection are '
      'not queries', () async {
    plant(
      'lib/domain/learner_state/ok.dart',
      '// queries learning_events\n'
          "/* 'learning_events' */\n"
          "String m(String id) => 'learning_events/\$id already exists';\n"
          "final log = 'learning_events [3 rows]';\n",
    );
    final result = await run();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('bad arguments exit 2', () async {
    final result = await Process.run('dart', [
      'run',
      script,
      '--bogus',
    ], workingDirectory: packageDir);
    expect(result.exitCode, 2);
  });
}
