// Tests for `tool/check_retired_symbols.dart` (DNI-521, "R0"; AD-49
// retired-symbols gate, orchestrator ruling B3).
//
// Every behavioural case runs the checker as a subprocess against a
// disposable FIXTURE ROOT (`--root`) in the system temp dir: a miniature
// learning_tracker/ with its own lib/, functions/src/, firestore.rules,
// firestore.indexes.json and tool/retired_symbols/ inventory. Nothing is
// ever written into the real lib/ tree, so this file needs no serial-tools
// tag and cannot race other checkers. One case runs the checker against
// the real tree to prove the seeded inventory is well-formed and the gate
// is green.
//
// The checker is compiled once to a kernel file in setUpAll so each case
// costs a VM start, not a compile.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

typedef _Json = Map<String, Object?>;

_Json _entry(
  String symbol, {
  String kind = 'type',
  String state = 'retired',
  String owner = 'DNI-483',
  _Json? paths,
  String? match,
}) => {
  'symbol': symbol,
  'kind': kind,
  'state': state,
  'owner': owner,
  if (paths != null) 'paths': paths,
  if (match != null) 'match': match,
};

_Json _allow(String symbol, String path, int count) => {
  'symbol': symbol,
  'path': path,
  'count': count,
  'reason': 'AD-49 cutover remnant (test)',
};

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_retired_symbols.dart';
  late Directory scratch;
  late String kernelPath;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('retired_symbols_test_');
    kernelPath = '${scratch.path}/check_retired_symbols.dill';
    final compiled = await Process.run('dart', [
      'compile',
      'kernel',
      scriptPath,
      '-o',
      kernelPath,
    ], workingDirectory: packageDir);
    expect(
      compiled.exitCode,
      0,
      reason: 'compile failed: ${compiled.stdout}\n${compiled.stderr}',
    );
  });

  tearDownAll(() {
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  /// Builds a fixture root. [groups] maps a group (e.g. `R1`) to its
  /// entries; every other group file is written empty. [rawGroups]
  /// overrides a group file's whole text (for malformed-JSON cases).
  Future<String> fixtureRoot({
    Map<String, String> files = const {},
    Map<String, List<Object?>> groups = const {},
    Map<String, String> rawGroups = const {},
    List<Object?> allow = const [],
    String? rawAllowlist,
    Set<String> omitGroups = const {},
  }) async {
    final root = await scratch.createTemp('root_');
    final inv = Directory('${root.path}/tool/retired_symbols')
      ..createSync(recursive: true);
    for (var n = 1; n <= 16; n++) {
      final g = 'R$n';
      if (omitGroups.contains(g)) continue;
      final text =
          rawGroups[g] ??
          const JsonEncoder.withIndent('  ').convert({
            'group': g,
            'title': 'Fixture group $g',
            'entries': groups[g] ?? const <Object?>[],
          });
      File('${inv.path}/$g.json').writeAsStringSync(text);
    }
    File(
      '${inv.path}/allowlist.json',
    ).writeAsStringSync(rawAllowlist ?? jsonEncode({'entries': allow}));
    files.forEach((path, content) {
      File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    });
    return root.path;
  }

  Future<ProcessResult> run(String root, [List<String> args = const []]) =>
      Process.run('dart', [
        kernelPath,
        '--root',
        root,
        ...args,
      ], workingDirectory: packageDir);

  String out(ProcessResult r) => 'stdout=${r.stdout}\nstderr=${r.stderr}';

  group('real tree', () {
    test('the seeded inventory is well-formed and the gate is green '
        '(every group R1-R16 reported)', () async {
      final result = await Process.run('dart', [
        kernelPath,
      ], workingDirectory: packageDir);
      expect(result.exitCode, 0, reason: out(result));
      final stdout = result.stdout.toString();
      expect(stdout, contains('Retired-symbols check OK (AD-49).'));
      for (var n = 1; n <= 16; n++) {
        expect(stdout, contains('  R$n: '), reason: 'group R$n missing');
      }
    });

    test('every seeded entry names an owner story and the allowlist starts '
        'empty (DNI-490 fills it at the cutover)', () {
      final dir = Directory('$packageDir/tool/retired_symbols');
      for (var n = 1; n <= 16; n++) {
        final data =
            jsonDecode(File('${dir.path}/R$n.json').readAsStringSync())
                as _Json;
        expect(data['group'], 'R$n');
        for (final e in data['entries']! as List<Object?>) {
          expect((e! as _Json)['owner'], matches(RegExp(r'^DNI-\d+$')));
        }
      }
      final allow =
          jsonDecode(File('${dir.path}/allowlist.json').readAsStringSync())
              as _Json;
      expect(allow['entries'], isEmpty);
    });

    test('the gate is wired into make audit, make ci and the ci.yml '
        'workflow', () {
      final makefile = File('$packageDir/Makefile').readAsStringSync();
      expect(makefile, contains('dart run tool/check_retired_symbols.dart'));
      expect(makefile, contains('105/105 — AD-49 RETIRED-SYMBOLS'));
      expect(
        RegExp(
          '^ci:.*check-retired-symbols',
          multiLine: true,
        ).hasMatch(makefile),
        isTrue,
        reason: 'the ci: target must depend on check-retired-symbols',
      );
      final ci = File(
        '${Directory(packageDir).parent.path}/.github/workflows/ci.yml',
      ).readAsStringSync();
      expect(ci, contains('dart run tool/check_retired_symbols.dart'));
    });
  });

  group('matching', () {
    test('identifier word boundaries: exact token hits, longer identifiers '
        'and comments do not', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('CompletionEntity')],
        },
        files: {
          'lib/a.dart': r'''
// CompletionEntity in a line comment
/// CompletionEntity in a doc comment
/* CompletionEntity in a block /* nested CompletionEntity */ still comment CompletionEntity */
class MyCompletionEntity {}
class CompletionEntityFoo {}
final $CompletionEntity = 1;
CompletionEntity? hit;
''',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('lib/a.dart:7:1: CompletionEntity? hit;'));
      expect(stderr, contains('1 hit(s) in lib/a.dart'));
    });

    test('kind "type" also matches inside string literals', () async {
      final root = await fixtureRoot(
        groups: {
          'R12': [_entry('tutorResetCompletion', kind: 'callable')],
        },
        files: {
          'lib/a.dart': "final c = call('tutorResetCompletion');\n",
          'functions/src/x.ts': 'export const tutorResetCompletion = 1;\n',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      expect(result.stderr.toString(), contains('lib/a.dart:1:'));
      expect(result.stderr.toString(), contains('functions/src/x.ts:1:'));
    });

    test('kind "collection" matches key-like string literals and rules/index '
        'paths, never local variables, interpolated code or prose', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('completions', kind: 'collection')],
        },
        files: {
          'lib/a.dart': r'''
final completions = <int>[];
final a = '${completions.length}';
final b = '$completions';
final c = 'Tutors cannot mark live completions. ';
final d = db.collection('completions');
final e = 'learner_profiles/$id/completions';
final f = """completions""";
final g = r'completions';
''',
          'functions/src/x.ts': r'''
// .collection("completions") in a comment
const p = `completions/${doc.id}`;
const completions = 3;
''',
          'firestore.rules': '''
// match /completions/{id} commented out
match /completions/{id} { allow write: if false; }
''',
          'firestore.indexes.json': '{"collectionGroup": "completions"}\n',
        },
      );
      final result = await run(root, ['--report']);
      expect(result.exitCode, 1, reason: out(result));
      final stderr = result.stderr.toString();
      for (final line in const [5, 6, 7, 8]) {
        expect(stderr, contains('lib/a.dart:$line:'), reason: 'line $line');
      }
      for (final line in const [1, 2, 3, 4]) {
        expect(
          stderr,
          isNot(contains('lib/a.dart:$line:')),
          reason: 'line $line',
        );
      }
      expect(stderr, contains('functions/src/x.ts:2:'));
      expect(stderr, isNot(contains('functions/src/x.ts:1:')));
      expect(stderr, isNot(contains('functions/src/x.ts:3:')));
      expect(stderr, contains('firestore.rules:2:'));
      expect(stderr, isNot(contains('firestore.rules:1:')));
      expect(stderr, contains('firestore.indexes.json:1:'));
    });

    test('"match": "any" widens a field to identifiers', () async {
      final root = await fixtureRoot(
        groups: {
          'R16': [
            _entry(
              'targetPercent',
              kind: 'field',
              owner: 'DNI-484',
              match: 'any',
            ),
          ],
        },
        files: {'lib/a.dart': 'final targetPercent = 3;\n'},
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      expect(result.stderr.toString(), contains('lib/a.dart:1:'));
    });

    test('only lib/**.dart, functions/src/**.ts, firestore.rules and '
        'firestore.indexes.json are scanned', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('CompletionEntity')],
        },
        files: {
          'test/a_test.dart': 'CompletionEntity? x;\n',
          'functions/test/a.test.ts': 'const CompletionEntity = 1;\n',
          'lib/notes.md': 'CompletionEntity\n',
          'tool/x.dart': 'CompletionEntity? x;\n',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });
  });

  group('path scoping', () {
    test(
      'include/exclude globs confine an entry (R16 governed updated_at)',
      () async {
        final root = await fixtureRoot(
          groups: {
            'R16': [
              _entry(
                'updated_at',
                kind: 'field',
                owner: 'DNI-484',
                paths: {
                  'include': [
                    'lib/data/repositories/firestore_{goal,stage_definition}_repository.dart',
                    'lib/features/**/models/*.dart',
                  ],
                  'exclude': ['lib/features/account/**'],
                },
              ),
            ],
          },
          files: {
            'lib/data/repositories/firestore_goal_repository.dart':
                "final k = 'updated_at';\n",
            'lib/data/repositories/firestore_profile_repository.dart':
                "final k = 'updated_at';\n",
            'lib/features/scheduler/domain/models/goal_entity.dart':
                "final k = 'updated_at';\n",
            'lib/features/account/domain/models/account_entity.dart':
                "final k = 'updated_at';\n",
            'lib/features/scheduler/domain/models/nested/deep.dart':
                "final k = 'updated_at';\n",
          },
        );
        final result = await run(root);
        expect(result.exitCode, 1, reason: out(result));
        final stderr = result.stderr.toString();
        expect(stderr, contains('firestore_goal_repository.dart:1:'));
        expect(stderr, contains('models/goal_entity.dart:1:'));
        expect(stderr, isNot(contains('firestore_profile_repository.dart')));
        expect(stderr, isNot(contains('account_entity.dart')));
        expect(stderr, isNot(contains('nested/deep.dart')));
      },
    );

    test('the same symbol may have two owners with different scopes '
        '(R1 lib/ vs R14 remnants); each flips independently', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [
            _entry(
              'completions',
              kind: 'collection',
              paths: {
                'include': ['lib/**'],
              },
            ),
          ],
          'R14': [
            _entry(
              'completions',
              kind: 'collection',
              state: 'pending',
              owner: 'DNI-490',
              paths: {
                'include': ['firestore.rules'],
              },
            ),
          ],
        },
        files: {
          'lib/a.dart': "final c = 'x';\n",
          'firestore.rules': 'match /completions/{id} {}\n',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
      expect(result.stdout.toString(), contains('R14: 1 pending (1 hit(s)'));
    });
  });

  group('pending vs retired', () {
    test('a pending symbol is reported and never fails', () async {
      final root = await fixtureRoot(
        groups: {
          'R2': [
            _entry(
              'CompletionOrchestrator',
              state: 'pending',
              owner: 'DNI-473',
            ),
          ],
        },
        files: {
          'lib/a.dart':
              'CompletionOrchestrator? a;\nCompletionOrchestrator? b;\n',
        },
      );
      final result = await run(root, ['--report']);
      expect(result.exitCode, 0, reason: out(result));
      final stdout = result.stdout.toString();
      expect(stdout, contains('R2: 1 pending (2 hit(s), reported only)'));
      expect(stdout, contains('[pending] CompletionOrchestrator'));
      expect(stdout, contains('lib/a.dart:2:1'));
      expect(stdout, contains('Retired-symbols check OK'));
    });

    test(
      'a retired symbol outside the allowlist exits 1 with file:line',
      () async {
        final root = await fixtureRoot(
          groups: {
            'R2': [_entry('CompletionOrchestrator', owner: 'DNI-473')],
          },
          files: {'lib/x/a.dart': '\n\nCompletionOrchestrator? a;\n'},
        );
        final result = await run(root);
        expect(result.exitCode, 1, reason: out(result));
        expect(
          result.stderr.toString(),
          contains('lib/x/a.dart:3:1: CompletionOrchestrator? a;'),
        );
      },
    );

    test('a retired symbol with no remaining reference passes', () async {
      final root = await fixtureRoot(
        groups: {
          'R2': [_entry('CompletionOrchestrator', owner: 'DNI-473')],
        },
        files: {'lib/a.dart': 'class LearningCommands {}\n'},
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
      expect(result.stdout.toString(), contains('R2: 0 pending'));
      expect(result.stdout.toString(), contains('1 retired'));
    });

    test('with everything pending the gate is green on day one', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('CompletionEntity', state: 'pending')],
        },
        files: {'lib/a.dart': 'CompletionEntity? a;\n'},
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });
  });

  group('allowlist', () {
    const rules =
        'match /completions/{id} { allow write: if false; }\n'
        'match /streak_events/{id} { allow write: if false; }\n';
    final remnants = {
      'R14': [
        for (final c in ['completions', 'streak_events'])
          _entry(
            c,
            kind: 'collection',
            owner: 'DNI-490',
            paths: {
              'include': ['firestore.rules', 'functions/src/deletes.ts'],
            },
          ),
      ],
    };

    test('retired hits exactly allowlisted pass', () async {
      final root = await fixtureRoot(
        groups: remnants,
        files: {'firestore.rules': rules},
        allow: [
          _allow('completions', 'firestore.rules', 1),
          _allow('streak_events', 'firestore.rules', 1),
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });

    test('a hit beyond the allowlisted count fails', () async {
      final root = await fixtureRoot(
        groups: remnants,
        files: {
          'firestore.rules': rules,
          'functions/src/deletes.ts': 'const c = ["completions"];\n',
        },
        allow: [
          _allow('completions', 'firestore.rules', 1),
          _allow('streak_events', 'firestore.rules', 1),
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      expect(
        result.stderr.toString(),
        contains('"completions" — 1 hit(s) in functions/src/deletes.ts'),
      );
    });

    test('a stale allowlist entry only warns by default but fails under '
        '--enforce', () async {
      final root = await fixtureRoot(
        groups: remnants,
        files: {'firestore.rules': rules},
        allow: [
          _allow('completions', 'firestore.rules', 1),
          _allow('streak_events', 'firestore.rules', 1),
          _allow('completions', 'functions/src/deletes.ts', 2),
        ],
      );
      final normal = await run(root);
      expect(normal.exitCode, 0, reason: out(normal));
      expect(normal.stdout.toString(), contains('WARNING: stale allowlist'));

      final enforced = await run(root, ['--enforce']);
      expect(enforced.exitCode, 1, reason: out(enforced));
      expect(
        enforced.stderr.toString(),
        contains('allowlist entry "completions" in functions/src/deletes.ts'),
      );
    });

    test('an allowlisted count above the hits fails under --enforce '
        '(exactness)', () async {
      final root = await fixtureRoot(
        groups: remnants,
        files: {'firestore.rules': rules},
        allow: [
          _allow('completions', 'firestore.rules', 2),
          _allow('streak_events', 'firestore.rules', 1),
        ],
      );
      expect((await run(root)).exitCode, 0);
      final enforced = await run(root, ['--enforce']);
      expect(enforced.exitCode, 1, reason: out(enforced));
      expect(
        enforced.stderr.toString(),
        contains(
          'allowlist not exact: "completions" in firestore.rules allows 2, '
          'found 1',
        ),
      );
    });

    test('--enforce treats every pending entry as retired', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('CompletionEntity', state: 'pending')],
        },
        files: {'lib/a.dart': 'CompletionEntity? a;\n'},
      );
      expect((await run(root)).exitCode, 0);
      final enforced = await run(root, ['--enforce']);
      expect(enforced.exitCode, 1, reason: out(enforced));
      expect(enforced.stderr.toString(), contains('lib/a.dart:1:1'));
    });

    test('--enforce passes when only the exact remnants remain', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('CompletionEntity', state: 'pending')],
          ...remnants,
        },
        files: {'lib/a.dart': 'class Clean {}\n', 'firestore.rules': rules},
        allow: [
          _allow('completions', 'firestore.rules', 1),
          _allow('streak_events', 'firestore.rules', 1),
        ],
      );
      final enforced = await run(root, ['--enforce']);
      expect(enforced.exitCode, 0, reason: out(enforced));
    });
  });

  group('schema (malformed or duplicate entries fail with exit 2)', () {
    Future<void> expectMalformed(String root, String message) async {
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(result.stderr.toString(), contains(message));
    }

    test('invalid JSON', () async {
      await expectMalformed(
        await fixtureRoot(rawGroups: {'R3': '{"group": "R3", '}),
        'R3.json: invalid JSON',
      );
    });

    test('missing group file', () async {
      await expectMalformed(
        await fixtureRoot(omitGroups: {'R7'}),
        'R7.json: missing',
      );
    });

    test('unexpected inventory file', () async {
      final root = await fixtureRoot();
      File(
        '$root/tool/retired_symbols/R17.json',
      ).writeAsStringSync('{"group":"R17","title":"x","entries":[]}');
      await expectMalformed(root, 'R17.json: unexpected file');
    });

    test('group field mismatch', () async {
      await expectMalformed(
        await fixtureRoot(
          rawGroups: {'R2': '{"group": "R3", "title": "x", "entries": []}'},
        ),
        'R2.json: "group" must be "R2"',
      );
    });

    test('unknown entry key (typo)', () async {
      await expectMalformed(
        await fixtureRoot(
          groups: {
            'R1': [
              {..._entry('CompletionEntity'), 'sate': 'retired'},
            ],
          },
        ),
        'unknown key "sate"',
      );
    });

    test('bad kind, state, owner, match and paths', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [
            _entry('A', kind: 'widget'),
            _entry('B', state: 'gone'),
            _entry('C', owner: 'story-1'),
            _entry('D', match: 'regex'),
            _entry(
              'E',
              paths: {
                'include': ['/abs/**'],
              },
            ),
            _entry('F', paths: {'only': <String>[]}),
            _entry(' G '),
          ],
        },
      );
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('entries[0]: "kind" must be one of'));
      expect(stderr, contains('entries[1]: "state" must be one of'));
      expect(stderr, contains('entries[2]: "owner" must be'));
      expect(stderr, contains('entries[3]: "match" must be one of'));
      expect(stderr, contains('entries[4] paths.include: invalid glob'));
      expect(stderr, contains('entries[5]: "paths" must be an object'));
      expect(stderr, contains('entries[6]: "symbol" must be'));
    });

    test('duplicate entry across groups (same symbol, same scope)', () async {
      await expectMalformed(
        await fixtureRoot(
          groups: {
            'R1': [_entry('CompletionEntity')],
            'R3': [_entry('CompletionEntity', owner: 'DNI-474')],
          },
        ),
        'R3.json entries[0]: duplicate of tool/retired_symbols/R1.json '
        'entries[0]',
      );
    });

    test('allowlist: unknown symbol, bad path, bad count, missing reason, '
        'unknown key', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('CompletionEntity')],
        },
        allow: [
          _allow('NotInInventory', 'firestore.rules', 1),
          _allow('CompletionEntity', 'test/a_test.dart', 1),
          _allow('CompletionEntity', 'firestore.rules', 0),
          {'symbol': 'CompletionEntity', 'path': 'lib/a.dart', 'count': 1},
          {..._allow('CompletionEntity', 'lib/b.dart', 1), 'line': 3},
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('entries[0]: "symbol" "NotInInventory"'));
      expect(stderr, contains('entries[1]: "path" must be a scanned file'));
      expect(stderr, contains('entries[2]: "count" must be an integer >= 1'));
      expect(stderr, contains('entries[3]: "reason" must be'));
      expect(stderr, contains('entries[4]: unknown key "line"'));
    });

    test('allowlist: duplicate entry and an entry no scope covers', () async {
      final root = await fixtureRoot(
        groups: {
          'R14': [
            _entry(
              'completions',
              kind: 'collection',
              owner: 'DNI-490',
              paths: {
                'include': ['firestore.rules'],
              },
            ),
          ],
        },
        allow: [
          _allow('completions', 'firestore.rules', 1),
          _allow('completions', 'firestore.rules', 1),
          _allow('completions', 'functions/src/deletes.ts', 1),
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('entries[1]: duplicate allowlist entry'));
      expect(stderr, contains('entries[2]: no inventory entry'));
    });

    test('allowlist: malformed top level', () async {
      await expectMalformed(
        await fixtureRoot(rawAllowlist: '[]'),
        'allowlist.json: top level must be an object',
      );
    });

    test('unknown CLI argument is a usage error', () async {
      final root = await fixtureRoot();
      final result = await run(root, ['--strict']);
      expect(result.exitCode, 2, reason: out(result));
      expect(result.stderr.toString(), contains('Unknown argument: --strict'));
    });
  });
}
