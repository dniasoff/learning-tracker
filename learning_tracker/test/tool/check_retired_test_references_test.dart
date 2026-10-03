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
  });

  test('reports comments, source and text fixtures in every test root', () {
    final symbol = 'Retired${'Reference'}';
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
      final symbol = 'Retired${'Field'}';
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
    final symbol = 'Retired${'Reference'}';
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
      scanRetiredTestReferences(root: sandbox, symbols: ['Retired${'Type'}']),
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
        symbols: ['Retired${'Reference'}'],
      ),
      isEmpty,
    );
  });
}
