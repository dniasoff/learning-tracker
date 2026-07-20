// Tests for `tool/check_arb_duplicate_keys.dart` (AUD-l10n-01).
//
// Fixture-based, same shape as test/tool/check_platform_deep_link_hosting_test.dart:
// each test writes a disposable .arb fixture under a temp dir and drives the
// checker at it via a positional path argument, so nothing touches this
// repo's real app_en.arb/app_he.arb and tests stay hermetic under
// `--concurrency=2`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _cleanArb = '''
{
  "greeting": "Hello",
  "@greeting": {
    "description": "A greeting."
  },
  "farewell": "Goodbye {name}",
  "@farewell": {
    "placeholders": {
      "name": { "type": "String" }
    }
  }
}
''';

/// Same shape as AUD-l10n-01's real defect: `todaysLearning` is defined
/// twice at the top level, once with no placeholder and once with a
/// `{count}` placeholder + matching `@todaysLearning` metadata. JSON
/// last-key-wins means only the second is ever live.
const _duplicateKeyArb = '''
{
  "greeting": "Hello",
  "todaysLearning": "Today's Learning",
  "farewell": "Goodbye {name}",
  "@farewell": {
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "todaysLearning": "Today's learning ({count})",
  "@todaysLearning": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
''';

/// A key legitimately reused at nested depth (inside two different
/// `@key` metadata `placeholders` blocks) must NOT be flagged — only
/// duplication at the top level (depth 1) is a defect.
const _nestedReuseIsFineArb = '''
{
  "greeting": "Hello {name}",
  "@greeting": {
    "placeholders": {
      "name": { "type": "String", "description": "the name" }
    }
  },
  "farewell": "Goodbye {name}",
  "@farewell": {
    "placeholders": {
      "name": { "type": "String", "description": "the name again" }
    }
  }
}
''';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_arb_duplicate_keys.dart';

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('arb_dup_key_fixture_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<ProcessResult> runCheck(String arbContent) async {
    final arbFile = File('${tempDir.path}/app_test.arb')
      ..writeAsStringSync(arbContent);
    return Process.run('dart', [
      'run',
      scriptPath,
      arbFile.path,
    ], workingDirectory: packageDir);
  }

  group('tool/check_arb_duplicate_keys.dart (AUD-l10n-01)', () {
    test('exits 0 on the real (fixed) app_en.arb + app_he.arb', () async {
      final result = await Process.run('dart', [
        'run',
        scriptPath,
      ], workingDirectory: packageDir);
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.stdout.toString(), contains('passed'));
    });

    test(
      'exits 0 on a clean fixture with no duplicate top-level keys',
      () async {
        final result = await runCheck(_cleanArb);
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      },
    );

    test(
      'RED: FAILS when a top-level key is duplicated — this is the exact '
      'AUD-l10n-01 defect shape (shadowed todaysLearning definition)',
      () async {
        final result = await runCheck(_duplicateKeyArb);
        expect(
          result.exitCode,
          isNot(0),
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stderr.toString(),
          contains('top-level key "todaysLearning" is duplicated'),
        );
      },
    );

    test('reports every duplicated key, not just the first found', () async {
      final result = await runCheck(_duplicateKeyArb);
      expect(result.exitCode, isNot(0));
      // Both todaysLearning AND its @todaysLearning metadata pair are
      // duplicated in this fixture (metadata only added on the second
      // definition — so only the base key duplicates here); assert the
      // violation count line is present and non-zero.
      expect(result.stderr.toString(), contains('violation(s):'));
    });

    test('does NOT flag a key name reused only at nested depth (inside two '
        'different @key placeholders blocks) — only top-level duplication '
        'is a defect', () async {
      final result = await runCheck(_nestedReuseIsFineArb);
      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
    });

    test(
      'exits 2 with a clear error when the given path does not exist',
      () async {
        final result = await Process.run('dart', [
          'run',
          scriptPath,
          '${tempDir.path}/does_not_exist.arb',
        ], workingDirectory: packageDir);
        expect(result.exitCode, 2);
        expect(result.stderr.toString(), contains('not found'));
      },
    );
  });
}
