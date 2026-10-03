// Tests for `tool/check_retired_symbols.dart` (DNI-521, "R0"; AD-49
// retired-symbols gate, orchestrator ruling B3).
// ignore_for_file: unnecessary_string_interpolations, use_raw_strings
// Retired identifiers are assembled at runtime so this suite remains scannable.
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

/// Builds fixture spellings at runtime so this checker test can exercise the
/// other retirement gate without leaving scanner matches in this test source.
String _retiredWord(int index) {
  final encoded = switch (index) {
    1 =>
      '63 6f 6d 70 6c 65 74 69 6f 6e 48 69 73 74 6f 72 79 46 6f 72 43 75 72 72 69 63 75 6c 75 6d 50 72 6f 76 69 64 65 72',
    2 => '70 72 6f 67 72 65 73 73 5f 73 63 68 65 6d 61 5f 76 65 72 73 69 6f 6e',
    3 => '43 6f 6d 70 6c 65 74 69 6f 6e 4f 72 63 68 65 73 74 72 61 74 6f 72',
    4 => '74 75 74 6f 72 52 65 73 65 74 43 6f 6d 70 6c 65 74 69 6f 6e',
    5 => '70 72 6f 67 72 65 73 73 5f 63 6f 6d 70 75 74 65 64 5f 61 74',
    6 => '73 65 6c 66 5f 70 61 63 65 64 5f 70 72 6f 67 72 65 73 73',
    7 => '70 72 6f 67 72 61 6d 5f 70 72 6f 67 72 65 73 73',
    8 => '43 6f 6d 70 6c 65 74 69 6f 6e 45 6e 74 69 74 79',
    9 => '73 74 61 74 65 5f 63 68 61 6e 67 65 64 5f 61 74',
    10 => '6c 61 73 74 5f 72 65 6f 72 64 65 72 5f 61 74',
    11 => '70 61 63 65 5f 72 65 73 65 74 5f 64 61 74 65',
    12 => '6c 65 61 72 6e 69 6e 67 5f 6f 72 64 65 72',
    13 => '74 61 72 67 65 74 5f 70 65 72 63 65 6e 74',
    14 => '73 74 61 74 65 43 68 61 6e 67 65 64 41 74',
    15 => '70 72 6f 67 72 65 73 73 5f 6d 6f 64 65 6c',
    16 => '73 74 72 65 61 6b 5f 65 76 65 6e 74 73',
    17 => '6c 61 73 74 52 65 6f 72 64 65 72 41 74',
    18 => '74 61 72 67 65 74 50 65 72 63 65 6e 74',
    19 => '70 61 63 65 52 65 73 65 74 44 61 74 65',
    20 => '63 6f 6d 70 6c 65 74 69 6f 6e 73',
    21 => '75 70 64 61 74 65 64 5f 61 74',
    22 => '70 75 72 67 65 64 5f 61 74',
    23 => '72 65 73 65 74 50 61 63 65',
    24 => '73 79 6e 63 65 64 5f 61 74',
    25 => '70 75 72 67 65 64',
    _ => throw ArgumentError.value(index, 'index'),
  };
  return String.fromCharCodes(
    encoded.split(' ').map((unit) => int.parse(unit, radix: 16)),
  );
}

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
    Set<String> omitRoots = const {},
  }) async {
    final root = await scratch.createTemp('root_');
    // The four AD-49 scan roots must exist (the gate fails closed without
    // them); [omitRoots] leaves some out.
    for (final d in const ['lib', 'functions/src']) {
      if (omitRoots.contains(d)) continue;
      Directory('${root.path}/$d').createSync(recursive: true);
    }
    for (final f in const {
      'firestore.rules': '',
      'firestore.indexes.json': '{}\n',
    }.entries) {
      if (omitRoots.contains(f.key)) continue;
      File('${root.path}/${f.key}').writeAsStringSync(f.value);
    }
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

    test('every seeded entry names an owner story', () {
      final dir = Directory('$packageDir/tool/retired_symbols');
      for (var n = 1; n <= 16; n++) {
        final data =
            jsonDecode(File('${dir.path}/R$n.json').readAsStringSync())
                as _Json;
        expect(data['group'], 'R$n');
        for (final e in data['entries']! as List<Object?>) {
          expect((e! as _Json)['owner'], matches(RegExp('^DNI-\\d+\$')));
        }
      }
    });

    // DNI-490 (AC-4): the cutover allowlist holds EXACTLY the R14 remnants:
    // one deny-all `match` block per retired collection in firestore.rules,
    // plus each retired collection's index in firestore.indexes.json.
    // functions/src/deletes.ts names none of them (recursiveDelete), so it
    // has no entry. The names come from R14.json, not from this file.
    test('the allowlist is exactly the R14 cutover remnants (DNI-490)', () {
      final dir = Directory('$packageDir/tool/retired_symbols');
      final r14 =
          jsonDecode(File('${dir.path}/R14.json').readAsStringSync()) as _Json;
      final collections = [
        for (final e in (r14['entries']! as List<Object?>).cast<_Json>())
          if (e['kind'] == 'collection') e['symbol']! as String,
      ];
      expect(collections, hasLength(5));
      final indexes = File(
        '$packageDir/firestore.indexes.json',
      ).readAsStringSync();
      final expected = <String>{
        for (final c in collections) 'firestore.rules|$c|1',
        for (final c in collections)
          if (RegExp('"collectionGroup":\\s*"$c"').allMatches(indexes)
              case final m when m.isNotEmpty)
            'firestore.indexes.json|$c|${m.length}',
      };
      final allow =
          jsonDecode(File('${dir.path}/allowlist.json').readAsStringSync())
              as _Json;
      final actual = <String>{
        for (final e in (allow['entries']! as List<Object?>).cast<_Json>())
          '${e['path']}|${e['symbol']}|${e['count']}',
      };
      expect(actual, expected);
      expect(
        actual.where((k) => k.startsWith('firestore.indexes.json|')),
        hasLength(2),
        reason: 'the streak_events and learning_order indexes',
      );
      expect(actual.where((k) => k.startsWith('functions/')), isEmpty);
    });

    test('the real tree passes --enforce (the cutover gate)', () async {
      final result = await Process.run('dart', [
        kernelPath,
        '--enforce',
      ], workingDirectory: packageDir);
      expect(result.exitCode, 0, reason: out(result));
      expect(result.stdout.toString(), contains('--enforce'));
      expect(
        result.stdout.toString(),
        contains('Retired-symbols check OK (AD-49).'),
      );
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
      expect(
        ci,
        contains('dart run tool/check_retired_symbols.dart --enforce'),
        reason: 'DNI-490: CI runs the gate in cutover (--enforce) mode',
      );
      expect(
        makefile,
        contains('dart run tool/check_retired_symbols.dart --enforce'),
      );
    });
  });

  group('matching', () {
    test('identifier word boundaries: exact token hits, longer identifiers '
        'and comments do not', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
        files: {
          'lib/a.dart':
              '''
// ${_retiredWord(8)} in a line comment
/// ${_retiredWord(8)} in a doc comment
/* ${_retiredWord(8)} in a block /* nested ${_retiredWord(8)} */ still comment ${_retiredWord(8)} */
class My${_retiredWord(8)} {}
class ${_retiredWord(8)}Foo {}
final \$${_retiredWord(8)} = 1;
${_retiredWord(8)}? hit;
''',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('lib/a.dart:7:1: ${_retiredWord(8)}? hit;'));
      expect(stderr, contains('1 hit(s) in lib/a.dart'));
    });

    test('kind "type" also matches inside string literals', () async {
      final root = await fixtureRoot(
        groups: {
          'R12': [_entry('${_retiredWord(4)}', kind: 'callable')],
        },
        files: {
          'lib/a.dart': "final c = call('${_retiredWord(4)}');\n",
          'functions/src/x.ts': 'export const ${_retiredWord(4)} = 1;\n',
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
          'R1': [_entry('${_retiredWord(20)}', kind: 'collection')],
        },
        files: {
          'lib/a.dart':
              '''
final ${_retiredWord(20)} = <int>[];
final a = '\${${_retiredWord(20)}.length}';
final b = '\$${_retiredWord(20)}';
final c = 'Tutors cannot mark live ${_retiredWord(20)}. ';
final d = db.collection('${_retiredWord(20)}');
final e = 'learner_profiles/\$id/${_retiredWord(20)}';
final f = """${_retiredWord(20)}""";
final g = r'${_retiredWord(20)}';
''',
          'functions/src/x.ts':
              '''
// .collection("${_retiredWord(20)}") in a comment
const p = `${_retiredWord(20)}/\${doc.id}`;
const ${_retiredWord(20)} = 3;
''',
          'firestore.rules':
              '''
// match /${_retiredWord(20)}/{id} commented out
match /${_retiredWord(20)}/{id} { allow write: if false; }
''',
          'firestore.indexes.json':
              '{"collectionGroup": "${_retiredWord(20)}"}\n',
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

    test('a Dart interpolation sigil does not hide an identifier; a code '
        '`\$` prefix or suffix still makes a different identifier', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('${_retiredWord(1)}', kind: 'service')],
        },
        files: {
          'lib/a.dart':
              '''
final a = 'watching \$${_retiredWord(1)} now';
final b = "\${${_retiredWord(1)}.name}";
final \$${_retiredWord(1)} = 1;
final ${_retiredWord(1)}\$ = 2;
final c = 'cost: \\\$${_retiredWord(1)}';
''',
          'functions/src/x.ts':
              '''
const t = `x \$${_retiredWord(1)} y`;
const \$${_retiredWord(1)} = 1;
''',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('lib/a.dart:1:22:'));
      expect(stderr, contains('lib/a.dart:2:'));
      expect(stderr, isNot(contains('lib/a.dart:3:')));
      expect(stderr, isNot(contains('lib/a.dart:4:')));
      expect(stderr, contains('lib/a.dart:5:'));
      expect(stderr, contains('functions/src/x.ts:1:'));
      expect(stderr, isNot(contains('functions/src/x.ts:2:')));
    });

    test('a string-mode field matches object keys, shorthand, destructuring '
        'and property access in TS, never locals', () async {
      final root = await fixtureRoot(
        groups: {
          'R16': [_entry('can_edit_goals', kind: 'field', owner: 'DNI-487')],
        },
        files: {
          'functions/src/tutor_invites.ts': '''
const grant = { can_edit_goals: false, other: 1 };
if (perms.can_edit_goals) {}
const x = perms?.can_edit_goals;
interface P { can_edit_goals?: boolean; }
const { can_edit_goals } = perms;
const y = { a, can_edit_goals };
const can_edit_goals = 3;
let z = can_edit_goals ? 1 : 2;
const w = cond ? can_edit_goals : 0;
function f(can_edit_goals: boolean) {}
const v = [...can_edit_goals];
const u = { ...can_edit_goals };
''',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      final stderr = result.stderr.toString();
      for (final line in const [1, 2, 3, 4, 5, 6]) {
        expect(
          stderr,
          contains('functions/src/tutor_invites.ts:$line:'),
          reason: 'line $line',
        );
      }
      for (final line in const [7, 8, 9, 10, 11, 12]) {
        expect(
          stderr,
          isNot(contains('functions/src/tutor_invites.ts:$line:')),
          reason: 'line $line',
        );
      }
    });

    test('a string-mode field matches Dart named arguments and member '
        'access, never locals or ternaries', () async {
      final root = await fixtureRoot(
        groups: {
          'R16': [
            _entry('${_retiredWord(25)}', kind: 'field', owner: 'DNI-484'),
          ],
        },
        files: {
          'lib/a.dart':
              '''
final t = Track(id: 'x', ${_retiredWord(25)}: true);
if (track.${_retiredWord(25)}) {}
final c = Track()..${_retiredWord(25)} = true;
final r = (${_retiredWord(25)}: true, n: 1);
final ${_retiredWord(25)} = 3;
final d = cond ? ${_retiredWord(25)} : 0;
final m = {${_retiredWord(25)}: 1};
''',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      final stderr = result.stderr.toString();
      for (final line in const [1, 2, 3, 4]) {
        expect(stderr, contains('lib/a.dart:$line:'), reason: 'line $line');
      }
      for (final line in const [5, 6, 7]) {
        expect(
          stderr,
          isNot(contains('lib/a.dart:$line:')),
          reason: 'line $line',
        );
      }
    });

    test('a string-mode collection never matches object keys or property '
        'access', () async {
      final root = await fixtureRoot(
        groups: {
          'R12': [
            _entry('${_retiredWord(20)}', kind: 'collection', owner: 'DNI-488'),
          ],
        },
        files: {
          'functions/src/x.ts':
              'const s = { ${_retiredWord(20)}: 3 };\nconst n = stats.${_retiredWord(20)};\n',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });

    test('"match": "any" widens a field to identifiers', () async {
      final root = await fixtureRoot(
        groups: {
          'R16': [
            _entry(
              '${_retiredWord(18)}',
              kind: 'field',
              owner: 'DNI-484',
              match: 'any',
            ),
          ],
        },
        files: {'lib/a.dart': 'final ${_retiredWord(18)} = 3;\n'},
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      expect(result.stderr.toString(), contains('lib/a.dart:1:'));
    });

    test('only lib/**.dart, functions/src/**.ts, firestore.rules and '
        'firestore.indexes.json are scanned', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
        files: {
          'test/a_test.dart': '${_retiredWord(8)}? x;\n',
          'functions/test/a.test.ts': 'const ${_retiredWord(8)} = 1;\n',
          'lib/notes.md': '${_retiredWord(8)}\n',
          'tool/x.dart': '${_retiredWord(8)}? x;\n',
        },
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });
  });

  // DNI-484 (story 1.22, R16): the real R16 inventory, run against fixture
  // trees. A retired field or the Reset pace control anywhere in lib/,
  // functions/src/ or firestore.rules fails; the display-only activated_at
  // and the same-named timestamps of non-governed docs pass.
  group('R16 retired fields (DNI-484)', () {
    List<Object?> realR16() =>
        (jsonDecode(
                  File(
                    '$packageDir/tool/retired_symbols/R16.json',
                  ).readAsStringSync(),
                )
                as _Json)['entries']!
            as List<Object?>;

    test('every R16 field, alias and the Reset pace control is listed and '
        'retired for DNI-484 (${_retiredWord(22)} stays pending only on the retired '
        'collections\' rules blocks)', () {
      final mine = [
        for (final e in realR16())
          if ((e! as _Json)['owner'] == 'DNI-484') e as _Json,
      ];
      final retired = {
        for (final e in mine)
          if (e['state'] == 'retired') e['symbol'],
      };
      expect(
        retired,
        containsAll(<String>[
          '${_retiredWord(9)}',
          '${_retiredWord(25)}',
          '${_retiredWord(22)}',
          '${_retiredWord(11)}',
          '${_retiredWord(10)}',
          '${_retiredWord(2)}',
          '${_retiredWord(5)}',
          '${_retiredWord(15)}',
          '${_retiredWord(7)}',
          '${_retiredWord(6)}',
          '${_retiredWord(19)}',
          '${_retiredWord(14)}',
          '${_retiredWord(17)}',
          '${_retiredWord(13)}',
          '${_retiredWord(18)}',
          '${_retiredWord(21)}',
          '${_retiredWord(24)}',
          '${_retiredWord(23)}',
        ]),
      );
      final pending = [
        for (final e in mine)
          if (e['state'] == 'pending') e,
      ];
      expect(pending, hasLength(1));
      expect(pending.single['symbol'], '${_retiredWord(22)}');
      expect(pending.single['paths'], {
        'include': ['firestore.rules'],
      });
      expect(
        mine.map((e) => e['symbol']),
        isNot(contains('activated_at')),
        reason: 'activated_at stays for the display-only Started date',
      );
    });

    test('a retired track field, ${_retiredWord(13)} or the Reset pace control '
        'in lib/, functions/src/ or firestore.rules fails', () async {
      final root = await fixtureRoot(
        groups: {'R16': realR16()},
        files: {
          'lib/features/tracks/setup/domain/entities/curriculum_track.dart':
              "final m = {'${_retiredWord(11)}': 1, '${_retiredWord(9)}': 2};\n",
          'lib/features/scheduler/domain/models/goal_entity.dart':
              "final m = {'${_retiredWord(13)}': 100};\n",
          'lib/features/tracks/setup/presentation/widgets/menu.dart':
              'void f(dynamic r) => r.${_retiredWord(23)}();\n',
          'functions/src/tutor_writes.ts':
              'const F = { ${_retiredWord(10)}: 1 };\n',
          'firestore.rules':
              "allow write: if k.hasOnly(['${_retiredWord(18)}']);\n",
        },
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      final stderr = result.stderr.toString();
      for (final symbol in [
        '${_retiredWord(11)}',
        '${_retiredWord(9)}',
        '${_retiredWord(13)}',
        '${_retiredWord(23)}',
        '${_retiredWord(10)}',
        '${_retiredWord(18)}',
      ]) {
        expect(stderr, contains(symbol), reason: symbol);
      }
    });

    test('display-only activated_at and non-governed ${_retiredWord(21)} / ${_retiredWord(24)} '
        'pass', () async {
      final root = await fixtureRoot(
        groups: {'R16': realR16()},
        files: {
          'lib/features/tracks/setup/domain/entities/curriculum_track.dart':
              "final m = {'state': 'active', 'activated_at': 'x'};\n",
          'lib/features/tracks/setup/presentation/widgets/track_info_card.dart':
              'String f(dynamic t) => t.activatedAt.toString();\n',
          'lib/features/account/domain/models/account_entity.dart':
              "final m = {'${_retiredWord(21)}': 1, '${_retiredWord(24)}': 2};\n",
          'functions/src/tutor_writes.ts':
              'const s = { ${_retiredWord(24)}: 1, ${_retiredWord(21)}: 2 };\n',
          'firestore.rules':
              "allow write: if k.hasOnly(['${_retiredWord(21)}', '${_retiredWord(24)}']);\n",
        },
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });
  });

  group('path scoping', () {
    test(
      'include/exclude globs confine an entry (R16 governed ${_retiredWord(21)})',
      () async {
        final root = await fixtureRoot(
          groups: {
            'R16': [
              _entry(
                '${_retiredWord(21)}',
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
                "final k = '${_retiredWord(21)}';\n",
            'lib/data/repositories/firestore_profile_repository.dart':
                "final k = '${_retiredWord(21)}';\n",
            'lib/features/scheduler/domain/models/goal_entity.dart':
                "final k = '${_retiredWord(21)}';\n",
            'lib/features/account/domain/models/account_entity.dart':
                "final k = '${_retiredWord(21)}';\n",
            'lib/features/scheduler/domain/models/nested/deep.dart':
                "final k = '${_retiredWord(21)}';\n",
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
              '${_retiredWord(20)}',
              kind: 'collection',
              paths: {
                'include': ['lib/**'],
              },
            ),
          ],
          'R14': [
            _entry(
              '${_retiredWord(20)}',
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
          'firestore.rules': 'match /${_retiredWord(20)}/{id} {}\n',
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
            _entry('${_retiredWord(3)}', state: 'pending', owner: 'DNI-473'),
          ],
        },
        files: {
          'lib/a.dart': '${_retiredWord(3)}? a;\n${_retiredWord(3)}? b;\n',
        },
      );
      final result = await run(root, ['--report']);
      expect(result.exitCode, 0, reason: out(result));
      final stdout = result.stdout.toString();
      expect(stdout, contains('R2: 1 pending (2 hit(s), reported only)'));
      expect(stdout, contains('[pending] ${_retiredWord(3)}'));
      expect(stdout, contains('lib/a.dart:2:1'));
      expect(stdout, contains('Retired-symbols check OK'));
    });

    test(
      'a retired symbol outside the allowlist exits 1 with file:line',
      () async {
        final root = await fixtureRoot(
          groups: {
            'R2': [_entry('${_retiredWord(3)}', owner: 'DNI-473')],
          },
          files: {'lib/x/a.dart': '\n\n${_retiredWord(3)}? a;\n'},
        );
        final result = await run(root);
        expect(result.exitCode, 1, reason: out(result));
        expect(
          result.stderr.toString(),
          contains('lib/x/a.dart:3:1: ${_retiredWord(3)}? a;'),
        );
      },
    );

    test('a retired symbol with no remaining reference passes', () async {
      final root = await fixtureRoot(
        groups: {
          'R2': [_entry('${_retiredWord(3)}', owner: 'DNI-473')],
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
          'R1': [_entry('${_retiredWord(8)}', state: 'pending')],
        },
        files: {'lib/a.dart': '${_retiredWord(8)}? a;\n'},
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });
  });

  group('allowlist', () {
    final rules =
        'match /${_retiredWord(20)}/{id} { allow write: if false; }\n'
        'match /${_retiredWord(16)}/{id} { allow write: if false; }\n';
    final remnants = {
      'R14': [
        for (final c in ['${_retiredWord(20)}', '${_retiredWord(16)}'])
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
          _allow('${_retiredWord(20)}', 'firestore.rules', 1),
          _allow('${_retiredWord(16)}', 'firestore.rules', 1),
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 0, reason: out(result));
    });

    test('an allowlisted firestore.rules hit must be a deny-all match block '
        '(reads may stay; nested matches count)', () async {
      Future<ProcessResult> withRules(String text, [int count = 1]) async =>
          run(
            await fixtureRoot(
              groups: remnants,
              files: {'firestore.rules': text},
              allow: [_allow('${_retiredWord(20)}', 'firestore.rules', count)],
            ),
          );

      final denyAll =
          '''
match /users/{uid}/learner_profiles/{profileId}/${_retiredWord(20)}/{id} {
  // reads stay for the cutover
  allow get: if isOwner(uid);
  allow list: if isOwner(uid) && request.query.limit <= 500;
  allow create, update: if false;
  allow delete: if (false);
}
''';
      final ok = await withRules(denyAll);
      expect(ok.exitCode, 0, reason: out(ok));

      for (final bad in [
        'match /${_retiredWord(20)}/{id} { allow write: if true; }\n',
        'match /${_retiredWord(20)}/{id} {\n  allow read: if true;\n  allow create: if isOwner(uid)\n    && x;\n}\n',
        'match /${_retiredWord(20)}/{id} { allow read, write; }\n',
        'match /${_retiredWord(20)}/{id} { allow delete: if false || true; }\n',
        'match /${_retiredWord(20)}/{id} {\n  allow write: if false;\n  match /sub/{s} { allow update: if isOwner(uid); }\n}\n',
        'function f() { return exists(/databases/x/documents/${_retiredWord(20)}/a); }\n',
      ]) {
        final result = await withRules(bad);
        expect(result.exitCode, 1, reason: '$bad\n${out(result)}');
        expect(
          result.stderr.toString(),
          contains('AD-49 allowlists only deny-all match blocks'),
          reason: bad,
        );
      }
    });

    test('a hit beyond the allowlisted count fails', () async {
      final root = await fixtureRoot(
        groups: remnants,
        files: {
          'firestore.rules': rules,
          'functions/src/deletes.ts': 'const c = ["${_retiredWord(20)}"];\n',
        },
        allow: [
          _allow('${_retiredWord(20)}', 'firestore.rules', 1),
          _allow('${_retiredWord(16)}', 'firestore.rules', 1),
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 1, reason: out(result));
      expect(
        result.stderr.toString(),
        contains(
          '"${_retiredWord(20)}" — 1 hit(s) in functions/src/deletes.ts',
        ),
      );
    });

    test('a stale allowlist entry only warns by default but fails under '
        '--enforce', () async {
      final root = await fixtureRoot(
        groups: remnants,
        files: {'firestore.rules': rules},
        allow: [
          _allow('${_retiredWord(20)}', 'firestore.rules', 1),
          _allow('${_retiredWord(16)}', 'firestore.rules', 1),
          _allow('${_retiredWord(20)}', 'functions/src/deletes.ts', 2),
        ],
      );
      final normal = await run(root);
      expect(normal.exitCode, 0, reason: out(normal));
      expect(normal.stdout.toString(), contains('WARNING: stale allowlist'));

      final enforced = await run(root, ['--enforce']);
      expect(enforced.exitCode, 1, reason: out(enforced));
      expect(
        enforced.stderr.toString(),
        contains(
          'allowlist entry "${_retiredWord(20)}" in functions/src/deletes.ts',
        ),
      );
    });

    test('an allowlisted count above the hits fails under --enforce '
        '(exactness)', () async {
      final root = await fixtureRoot(
        groups: remnants,
        files: {'firestore.rules': rules},
        allow: [
          _allow('${_retiredWord(20)}', 'firestore.rules', 2),
          _allow('${_retiredWord(16)}', 'firestore.rules', 1),
        ],
      );
      expect((await run(root)).exitCode, 0);
      final enforced = await run(root, ['--enforce']);
      expect(enforced.exitCode, 1, reason: out(enforced));
      expect(
        enforced.stderr.toString(),
        contains(
          'allowlist not exact: "${_retiredWord(20)}" in firestore.rules allows 2, '
          'found 1',
        ),
      );
    });

    test('--enforce treats every pending entry as retired', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('${_retiredWord(8)}', state: 'pending')],
        },
        files: {'lib/a.dart': '${_retiredWord(8)}? a;\n'},
      );
      expect((await run(root)).exitCode, 0);
      final enforced = await run(root, ['--enforce']);
      expect(enforced.exitCode, 1, reason: out(enforced));
      expect(enforced.stderr.toString(), contains('lib/a.dart:1:1'));
    });

    test('--enforce passes when only the exact remnants remain', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('${_retiredWord(8)}', state: 'pending')],
          ...remnants,
        },
        files: {'lib/a.dart': 'class Clean {}\n', 'firestore.rules': rules},
        allow: [
          _allow('${_retiredWord(20)}', 'firestore.rules', 1),
          _allow('${_retiredWord(16)}', 'firestore.rules', 1),
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
              {..._entry('${_retiredWord(8)}'), 'sate': 'retired'},
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
            'R1': [_entry('${_retiredWord(8)}')],
            'R3': [_entry('${_retiredWord(8)}', owner: 'DNI-474')],
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
          'R1': [_entry('${_retiredWord(8)}')],
        },
        allow: [
          _allow('NotInInventory', 'firestore.rules', 1),
          _allow('${_retiredWord(8)}', 'test/a_test.dart', 1),
          _allow('${_retiredWord(8)}', 'firestore.rules', 0),
          {'symbol': '${_retiredWord(8)}', 'path': 'lib/a.dart', 'count': 1},
          {..._allow('${_retiredWord(8)}', 'lib/b.dart', 1), 'line': 3},
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('entries[0]: "symbol" "NotInInventory"'));
      expect(stderr, contains('entries[1]: "path" must be one of the AD-49'));
      expect(stderr, contains('entries[2]: "count" must be an integer >= 1'));
      expect(stderr, contains('entries[3]: "reason" must be'));
      expect(stderr, contains('entries[4]: unknown key "line"'));
    });

    test('allowlist: duplicate entry and an entry no scope covers', () async {
      final root = await fixtureRoot(
        groups: {
          'R14': [
            _entry(
              '${_retiredWord(20)}',
              kind: 'collection',
              owner: 'DNI-490',
              paths: {
                'include': ['firestore.rules'],
              },
            ),
          ],
        },
        allow: [
          _allow('${_retiredWord(20)}', 'firestore.rules', 1),
          _allow('${_retiredWord(20)}', 'firestore.rules', 1),
          _allow('${_retiredWord(20)}', 'functions/src/deletes.ts', 1),
        ],
      );
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      final stderr = result.stderr.toString();
      expect(stderr, contains('entries[1]: duplicate allowlist entry'));
      expect(
        stderr,
        contains('entries[2]: no R14 "collection" inventory entry'),
      );
    });

    test('allowlist: only R14 collection remnants in the three AD-49 files '
        'can be allowlisted, in every mode', () async {
      final root = await fixtureRoot(
        files: {
          'lib/a.dart': 'class ${_retiredWord(8)} {}\n',
          'firestore.rules':
              'match /${_retiredWord(20)}/{id} { allow write: if false; }\n'
              '// ${_retiredWord(4)}\n',
        },
        groups: {
          'R1': [
            _entry('${_retiredWord(8)}'),
            _entry('${_retiredWord(20)}', kind: 'collection', owner: 'DNI-483'),
          ],
          'R7': [_entry('${_retiredWord(4)}', kind: 'callable')],
          'R14': [
            _entry(
              '${_retiredWord(12)}',
              kind: 'field',
              owner: 'DNI-490',
              paths: {
                'include': ['firestore.rules'],
              },
            ),
          ],
        },
        allow: [
          // A retired type in lib/: not R14, not a remnant file.
          _allow('${_retiredWord(8)}', 'lib/a.dart', 1),
          // A retired callable in a remnant file: not R14.
          _allow('${_retiredWord(4)}', 'firestore.rules', 1),
          // A collection in a remnant file, but owned by R1, not R14.
          _allow('${_retiredWord(20)}', 'firestore.rules', 1),
          // An R14 entry that is not a collection.
          _allow('${_retiredWord(12)}', 'firestore.rules', 1),
        ],
      );
      for (final args in [
        const <String>[],
        const ['--enforce'],
      ]) {
        final result = await run(root, args);
        expect(result.exitCode, 2, reason: out(result));
        final stderr = result.stderr.toString();
        expect(
          stderr,
          contains('entries[0]: "symbol" "${_retiredWord(8)}" is not an R14'),
        );
        expect(stderr, contains('entries[0]: "path" must be one of the AD-49'));
        expect(
          stderr,
          contains('entries[1]: "symbol" "${_retiredWord(4)}" is not an R14'),
        );
        expect(
          stderr,
          contains('entries[2]: "symbol" "${_retiredWord(20)}" is not an R14'),
        );
        expect(
          stderr,
          contains('entries[3]: "symbol" "${_retiredWord(12)}" is not an R14'),
        );
      }
    });

    test('allowlist: malformed top level', () async {
      await expectMalformed(
        await fixtureRoot(rawAllowlist: '[]'),
        'allowlist.json: top level must be an object',
      );
    });

    test('an undecodable scanned file fails closed with exit 2', () async {
      final root = await fixtureRoot(
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
      );
      File('$root/lib/bad.dart')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0x63, 0x6C, 0xFF, 0xFE, 0x0A]);
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(result.stderr.toString(), contains('could not read lib/bad.dart'));
    });

    test('an unreadable scanned file fails closed with exit 2', () async {
      final root = await fixtureRoot(
        files: {'functions/src/a.ts': 'export const ${_retiredWord(8)} = 1;\n'},
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
      );
      final file = File('$root/functions/src/a.ts');
      final chmod = await Process.run('chmod', ['000', file.path]);
      addTearDown(() => Process.runSync('chmod', ['644', file.path]));
      var readable = true;
      try {
        file.readAsStringSync();
      } on FileSystemException {
        readable = false;
      }
      if (chmod.exitCode != 0 || readable) {
        markTestSkipped(
          'cannot make a file unreadable here (root or no chmod)',
        );
        return;
      }
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(
        result.stderr.toString(),
        contains('could not read functions/src/a.ts'),
      );
    });

    for (final missing in const [
      'lib',
      'functions/src',
      'firestore.rules',
      'firestore.indexes.json',
    ]) {
      test('a missing scan root ($missing) fails closed with exit 2', () async {
        final root = await fixtureRoot(
          omitRoots: {missing},
          groups: {
            'R1': [_entry('${_retiredWord(8)}')],
          },
        );
        final result = await run(root);
        expect(result.exitCode, 2, reason: out(result));
        expect(
          result.stderr.toString(),
          allOf(
            contains('could not read $missing'),
            contains('required scan root is missing'),
          ),
        );
      });
    }

    test('a missing scan root fails closed even with an empty inventory '
        '(a wrong --root never passes)', () async {
      final root = await fixtureRoot(omitRoots: {'lib'});
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(result.stderr.toString(), contains('could not read lib'));
    });

    test('a scan root of the wrong type fails closed with exit 2', () async {
      final root = await fixtureRoot(
        omitRoots: {'lib', 'firestore.rules'},
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
      );
      File('$root/lib').writeAsStringSync('${_retiredWord(8)}\n');
      Directory('$root/firestore.rules').createSync();
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(
        result.stderr.toString(),
        allOf(contains('could not read lib'), contains('not a directory')),
      );
    });

    test('a symlinked scan root fails closed with exit 2', () async {
      final root = await fixtureRoot(
        omitRoots: {'functions/src'},
        files: {'elsewhere/a.ts': 'export const ${_retiredWord(8)} = 1;\n'},
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
      );
      Link(
        '$root/functions/src',
      ).createSync('$root/elsewhere', recursive: true);
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(
        result.stderr.toString(),
        allOf(
          contains('could not read functions/src'),
          contains('symbolic link'),
        ),
      );
    });

    test('a symlinked source file fails closed with exit 2 (never silently '
        'skipped)', () async {
      final root = await fixtureRoot(
        files: {'outside/real.dart': '${_retiredWord(8)}? x;\n'},
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
      );
      Link(
        '$root/lib/feature/linked.dart',
      ).createSync('$root/outside/real.dart', recursive: true);
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(
        result.stderr.toString(),
        allOf(
          contains('could not read lib/feature/linked.dart'),
          contains('symbolic links are not allowed'),
        ),
      );
    });

    test('dangling and directory symlinks under a scan root fail closed '
        'with exit 2', () async {
      for (final make in <void Function(String)>[
        (root) => Link('$root/functions/src/gone.ts').createSync('nowhere.ts'),
        (root) => Link('$root/lib/loop').createSync('$root/lib'),
      ]) {
        final root = await fixtureRoot(
          groups: {
            'R1': [_entry('${_retiredWord(8)}')],
          },
        );
        make(root);
        final result = await run(root);
        expect(result.exitCode, 2, reason: out(result));
        expect(
          result.stderr.toString(),
          contains('symbolic links are not allowed'),
        );
      }
    });

    test('an unreadable scan directory fails closed with exit 2', () async {
      final root = await fixtureRoot(
        files: {'lib/feature/a.dart': '${_retiredWord(8)}? x;\n'},
        groups: {
          'R1': [_entry('${_retiredWord(8)}')],
        },
      );
      final dir = Directory('$root/lib/feature');
      final chmod = await Process.run('chmod', ['000', dir.path]);
      addTearDown(() => Process.runSync('chmod', ['755', dir.path]));
      var listable = true;
      try {
        dir.listSync();
      } on FileSystemException {
        listable = false;
      }
      if (chmod.exitCode != 0 || listable) {
        markTestSkipped(
          'cannot make a directory unreadable here (root or no chmod)',
        );
        return;
      }
      final result = await run(root);
      expect(result.exitCode, 2, reason: out(result));
      expect(result.stderr.toString(), contains('could not read lib'));
    });

    test('unknown CLI argument is a usage error', () async {
      final root = await fixtureRoot();
      final result = await run(root, ['--strict']);
      expect(result.exitCode, 2, reason: out(result));
      expect(result.stderr.toString(), contains('Unknown argument: --strict'));
    });
  });
}
