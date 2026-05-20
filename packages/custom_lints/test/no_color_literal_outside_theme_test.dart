// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_color_literal_outside_theme.dart';

/// Writes [content] to a temporary file and returns the file.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_color_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

/// Writes [content] to a path that contains [pathSegment] so the whitelist
/// check fires for the correct directory segment.
File _tmpFileAt(String content, String pathSegment) {
  final dir = Directory('${Directory.systemTemp.path}/$pathSegment');
  dir.createSync(recursive: true);
  final file = File(
    '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

void main() {
  const rule = NoColorLiteralOutsideTheme();

  group('NoColorLiteralOutsideTheme', () {
    group('violations', () {
      test('flags Color(0xFF…) in a feature file', () async {
        final file = _tmpFile('''
import 'package:flutter/material.dart';
class Foo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0xFF0038A8));
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_color_literal_outside_theme',
          ),
          isNotEmpty,
          reason: 'Color(0xFF…) outside core/theme/ must be flagged',
        );
      });

      test('flags Color(0x…) with any hex literal argument', () async {
        // Same test as first but without import — raw code snippet.
        final file = _tmpFile('''
void foo() {
  const x = Color(0xFF123456);
}
// Stub to avoid analysis errors in isolated snippet
class Color { const Color(int v); }
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_color_literal_outside_theme',
          ),
          isNotEmpty,
          reason: 'Color(0xFF…) in stub code must be flagged',
        );
      });
    });

    group('allowed', () {
      test('does not flag named Color constants (e.g. Colors.white)', () async {
        final file = _tmpFile('''
import 'package:flutter/material.dart';
final c = Colors.white;
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_color_literal_outside_theme',
          ),
          isEmpty,
          reason: 'Named constants must not be flagged',
        );
      });

      test('does not flag non-hex integer argument to Color()', () async {
        // Color(int) with a variable/expression is not a literal — not flagged.
        final file = _tmpFile('''
import 'package:flutter/material.dart';
int colorValue = 0xFF0038A8;
final c = Color(colorValue);
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_color_literal_outside_theme',
          ),
          isEmpty,
          reason: 'Color(variable) must not be flagged — only Color(0x…) literals',
        );
      });
    });

    group('whitelist — file path checks', () {
      test('isWhitelisted returns true for lib/core/theme/ path', () {
        expect(
          _invokeIsWhitelisted('lib/core/theme/app_colors.dart'),
          isTrue,
        );
      });

      test('isWhitelisted returns true for .g.dart', () {
        expect(_invokeIsWhitelisted('some.g.dart'), isTrue);
      });

      test('isWhitelisted returns true for .freezed.dart', () {
        expect(_invokeIsWhitelisted('model.freezed.dart'), isTrue);
      });

      test('isWhitelisted returns false for feature file', () {
        expect(
          _invokeIsWhitelisted(
            'lib/features/dashboard/presentation/widgets/foo.dart',
          ),
          isFalse,
        );
      });

      test('Color(0xFF…) allowed in lib/core/theme/', () async {
        final file = _tmpFileAt('''
import 'package:flutter/material.dart';
const Color myColor = Color(0xFF0038A8);
''', 'lib/core/theme');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_color_literal_outside_theme',
          ),
          isEmpty,
          reason: 'Color(0xFF…) is allowed inside lib/core/theme/',
        );
      });
    });
  });
}

/// Mirrors the private _isWhitelisted logic for unit-level path testing.
bool _invokeIsWhitelisted(String path) {
  final normalised = path.replaceAll(r'\', '/');
  if (normalised.contains('lib/core/theme/')) return true;
  if (normalised.endsWith('.g.dart')) return true;
  if (normalised.endsWith('.freezed.dart')) return true;
  return false;
}
