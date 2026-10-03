import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_retired_test_references.dart';

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('retired-test-scan-');
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('loads only retired identifiers from all inventory groups', () {
    final symbols = loadRetiredTestSymbols(Directory.current);
    expect(symbols, contains('Completion${'Entity'}'));
    expect(symbols, contains('tutor${'ResetCompletion'}'));
    expect(symbols, isNot(contains('c0${'Stub'}')));
    // R14 keeps the collection's rules/deletes.ts remnant pending until the
    // cutover release, so the collection is not yet a deleted symbol.
    expect(symbols, isNot(contains('comp${'letions'}')));
  });

  group('inventory semantics', () {
    void writeInventory(Map<int, List<Map<String, Object?>>> groups) {
      for (var group = 1; group <= 16; group++) {
        File('${sandbox.path}/tool/retired_symbols/R$group.json')
          ..createSync(recursive: true)
          ..writeAsStringSync(
            jsonEncode({'group': 'R$group', 'entries': groups[group] ?? []}),
          );
      }
    }

    void writeTest(String path, String contents) =>
        File('${sandbox.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(contents);

    List<String> scan() => [
      for (final reference in scanRetiredTestReferences(
        root: sandbox,
        inventory: loadRetiredTestInventory(sandbox),
      ))
        '$reference',
    ];

    test('a symbol with any pending entry is not yet deleted', () {
      writeInventory({
        1: [
          {'symbol': 'LiveRemnant', 'kind': 'type', 'state': 'retired'},
          {'symbol': 'GoneType', 'kind': 'type', 'state': 'retired'},
        ],
        14: [
          {'symbol': 'LiveRemnant', 'kind': 'type', 'state': 'pending'},
        ],
      });
      writeTest('test/a_test.dart', '// LiveRemnant and GoneType\n');

      expect(loadRetiredTestSymbols(sandbox), {'GoneType'});
      expect(scan(), ['test/a_test.dart:1: GoneType']);
    });

    test('a scoped entry projects onto the mirrored tests only', () {
      writeInventory({
        16: [
          {
            'symbol': 'old_field',
            'kind': 'field',
            'state': 'retired',
            'paths': {
              'include': [
                'lib/data/{goal,track}_repository.dart',
                'lib/features/tracks/**',
                'functions/src/write_with_change_log.ts',
                'firestore.rules',
              ],
            },
          },
        ],
      });
      const line = "final k = 'old_field';\n";
      writeTest('test/data/goal_repository_test.dart', line);
      writeTest('test/data/track_repository_extended_test.dart', line);
      writeTest('test/features/tracks/setup/x_test.dart', line);
      writeTest('integration_test/features/tracks/y_test.dart', line);
      writeTest('functions/test/cf_write_with_change_log.test.mjs', line);
      writeTest('functions/test/firestore_rules.test.mjs', line);
      // Out of scope: another collection legitimately keeps the name.
      writeTest('test/data/settings_repository_test.dart', line);
      writeTest('functions/test/cf_triggers.test.mjs', line);

      expect(scan(), [
        'functions/test/cf_write_with_change_log.test.mjs:1: old_field',
        'functions/test/firestore_rules.test.mjs:1: old_field',
        'integration_test/features/tracks/y_test.dart:1: old_field',
        'test/data/goal_repository_test.dart:1: old_field',
        'test/data/track_repository_extended_test.dart:1: old_field',
        'test/features/tracks/setup/x_test.dart:1: old_field',
      ]);
    });

    test('excludes carve out a scope; an unknown scope fails safe to every '
        'root', () {
      writeInventory({
        5: [
          {
            'symbol': 'old_ledger',
            'kind': 'collection',
            'state': 'retired',
            'paths': {
              'include': ['functions/src/**'],
              'exclude': ['functions/src/deletes.ts'],
            },
          },
          {
            'symbol': 'odd_scope',
            'kind': 'field',
            'state': 'retired',
            'paths': {
              'include': ['firestore.indexes.json'],
            },
          },
        ],
      });
      writeTest('functions/test/cf_deletes.test.mjs', "'old_ledger'\n");
      writeTest('functions/test/cf_triggers.test.mjs', "'old_ledger'\n");
      writeTest('test/a_test.dart', "'old_ledger' 'odd_scope'\n");

      expect(scan(), [
        'functions/test/cf_triggers.test.mjs:1: old_ledger',
        'test/a_test.dart:1: odd_scope',
      ]);
    });

    test('a one-word lowercase collection or field counts only in code '
        'position', () {
      writeInventory({
        8: [
          {'symbol': 'widgets', 'kind': 'collection', 'state': 'retired'},
          {'symbol': 'Widgets', 'kind': 'type', 'state': 'retired'},
        ],
      });
      writeTest(
        'test/a_test.dart',
        [
          '// No widgets yet. Widgets.build',
          "db.collection('widgets');",
          '// the retired `widgets` store',
          'final path = "users/u/widgets/w";',
          '{"widgets": 1}',
        ].join('\n'),
      );

      expect(scan(), [
        'test/a_test.dart:1: Widgets',
        'test/a_test.dart:2: widgets',
        'test/a_test.dart:3: widgets',
        'test/a_test.dart:4: widgets',
        'test/a_test.dart:5: widgets',
      ]);
    });

    test('brace alternatives expand before projection', () {
      expect(expandBraces('lib/{a,b}/x_{c,d}.dart'), [
        'lib/a/x_c.dart',
        'lib/a/x_d.dart',
        'lib/b/x_c.dart',
        'lib/b/x_d.dart',
      ]);
      expect(projectToTestRoots('functions/src/**'), ['functions/test/**']);
    });
  });

  test('reports comments, source and text fixtures in every test root', () {
    final symbol = String.fromCharCodes([
      0x52,
      0x65,
      0x74,
      0x69,
      0x72,
      0x65,
      0x64,
      0x52,
      0x65,
      0x66,
      0x65,
      0x72,
      0x65,
      0x6e,
      0x63,
      0x65,
    ]);
    File('${sandbox.path}/test/check.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// $symbol\nfinal value = "$symbol";\n');
    File('${sandbox.path}/integration_test/fixture.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"note":"$symbol"}\n');
    File('${sandbox.path}/functions/test/fixture.mjs')
      ..createSync(recursive: true)
      ..writeAsStringSync('/* $symbol */\n');

    final references = scanRetiredTestReferences(
      root: sandbox,
      symbols: [symbol],
    );

    expect(references, hasLength(4));
    expect(
      references.map((reference) => '${reference.path}:${reference.line}'),
      containsAll([
        'test/check.dart:1',
        'test/check.dart:2',
        'integration_test/fixture.json:1',
        'functions/test/fixture.mjs:1',
      ]),
    );
    expect(references.map((reference) => reference.symbol).toSet(), {symbol});
  });

  test(
    'reports every match on its own line and preserves exact boundaries',
    () {
      final symbol = String.fromCharCodes([
        0x52,
        0x65,
        0x74,
        0x69,
        0x72,
        0x65,
        0x64,
        0x46,
        0x69,
        0x65,
        0x6c,
        0x64,
      ]);
      File('${sandbox.path}/test/matches.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'x$symbol${'Suffix'}\n$symbol and $symbol\n${symbol}X\n',
        );

      final references = scanRetiredTestReferences(
        root: sandbox,
        symbols: [symbol],
      );

      expect(references, hasLength(2));
      expect(references.map((reference) => reference.line), [2, 2]);
    },
  );

  test('skips binary assets while scanning other extensionless text files', () {
    final symbol = String.fromCharCodes([
      0x52,
      0x65,
      0x74,
      0x69,
      0x72,
      0x65,
      0x64,
      0x52,
      0x65,
      0x66,
      0x65,
      0x72,
      0x65,
      0x6e,
      0x63,
      0x65,
    ]);
    File('${sandbox.path}/test/asset.bin')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0x89, 0x50, 0x00, 0xff]);
    File('${sandbox.path}/test/no-extension')
      ..createSync(recursive: true)
      ..writeAsStringSync('comment: $symbol\n');

    final references = scanRetiredTestReferences(
      root: sandbox,
      symbols: [symbol],
    );

    expect(references, hasLength(1));
    expect(references.single.path, 'test/no-extension');
  });

  test('missing and empty roots pass', () {
    Directory('${sandbox.path}/test').createSync(recursive: true);
    Directory('${sandbox.path}/integration_test').createSync();

    expect(
      scanRetiredTestReferences(root: sandbox, symbols: const ['RetiredType']),
      isEmpty,
    );
  });

  test('clean source and fixture samples have no findings', () {
    final fixtureRoot = Directory(
      '${Directory.current.path}/test/tool/fixtures/retired_test_references',
    );
    for (final fixture in fixtureRoot.listSync()) {
      if (fixture is File) {
        final destination = File(
          '${sandbox.path}/test/${fixture.uri.pathSegments.last}',
        );
        destination.createSync(recursive: true);
        fixture.copySync(destination.path);
      }
    }

    expect(
      scanRetiredTestReferences(
        root: sandbox,
        symbols: const ['RetiredReference'],
      ),
      isEmpty,
    );
  });
}
