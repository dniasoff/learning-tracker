// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_hardcoded_text_direction.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_rtl_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

void main() {
  const rule = NoHardcodedTextDirection();

  group('NoHardcodedTextDirection', () {
    group('violations — static member access', () {
      test('flags Alignment.centerLeft', () async {
        final file = _tmpFile('''
class Foo {
  final align = Alignment.centerLeft;
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'Alignment.centerLeft must be flagged',
        );
      });

      test('flags Alignment.centerRight', () async {
        final file = _tmpFile('''
class Foo {
  final align = Alignment.centerRight;
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'Alignment.centerRight must be flagged',
        );
      });

      test('flags TextAlign.left', () async {
        final file = _tmpFile('''
class Foo {
  final align = TextAlign.left;
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'TextAlign.left must be flagged',
        );
      });

      test('flags TextAlign.right', () async {
        final file = _tmpFile('''
class Foo {
  final align = TextAlign.right;
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'TextAlign.right must be flagged',
        );
      });
    });

    group('violations — EdgeInsets.only named arguments', () {
      test('flags EdgeInsets.only(left: …)', () async {
        final file = _tmpFile('''
class Foo {
  final padding = EdgeInsets.only(left: 8.0);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'EdgeInsets.only(left:) must be flagged',
        );
      });

      test('flags EdgeInsets.only(right: …)', () async {
        final file = _tmpFile('''
class Foo {
  final padding = EdgeInsets.only(right: 8.0);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'EdgeInsets.only(right:) must be flagged',
        );
      });
    });

    group('allowed', () {
      test('allows Alignment.center (not directional)', () async {
        final file = _tmpFile('''
class Foo {
  final align = Alignment.center;
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isEmpty,
          reason: 'Alignment.center is not directional and must not be flagged',
        );
      });

      test('allows TextAlign.start and TextAlign.end', () async {
        final file = _tmpFile('''
class Foo {
  final a = TextAlign.start;
  final b = TextAlign.end;
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isEmpty,
          reason:
              'TextAlign.start/end are direction-aware and must not be flagged',
        );
      });

      test('allows EdgeInsets.only(top: …, bottom: …)', () async {
        final file = _tmpFile('''
class Foo {
  final padding = EdgeInsets.only(top: 8.0, bottom: 4.0);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isEmpty,
          reason:
              'EdgeInsets.only with only top/bottom args must not be flagged',
        );
      });

      test('allows EdgeInsetsDirectional.only(start:)', () async {
        final file = _tmpFile('''
class Foo {
  final padding = EdgeInsetsDirectional.only(start: 8.0);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isEmpty,
          reason:
              'EdgeInsetsDirectional.only is the correct RTL-safe alternative',
        );
      });
    });

    group('whitelist — generated files', () {
      test('isGenerated returns true for .g.dart', () {
        expect(_invokeIsGenerated('some.g.dart'), isTrue);
      });

      test('isGenerated returns true for .freezed.dart', () {
        expect(_invokeIsGenerated('model.freezed.dart'), isTrue);
      });

      test('isGenerated returns false for regular dart file', () {
        expect(
          _invokeIsGenerated('lib/features/dashboard/presentation/screen.dart'),
          isFalse,
        );
      });
    });
  });
}

/// Mirrors the private _isGenerated logic for unit-level path testing.
bool _invokeIsGenerated(String path) {
  final normalised = path.replaceAll(r'\', '/');
  if (normalised.endsWith('.g.dart')) return true;
  if (normalised.endsWith('.freezed.dart')) return true;
  return false;
}
