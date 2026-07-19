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

    group('violations — textDirection: bare TextDirection literal', () {
      test('flags textDirection: TextDirection.rtl on a widget', () async {
        // Mirrors the exact shape of the AUD-tracks-25 defect: a free-text
        // field forcing RTL unconditionally, regardless of app locale.
        final file = _tmpFile('''
import 'package:flutter/material.dart';

class Foo extends StatelessWidget {
  const Foo({super.key});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      textDirection: TextDirection.rtl,
    );
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'textDirection: TextDirection.rtl must be flagged',
        );
      });

      test('flags textDirection: TextDirection.ltr on a widget', () async {
        final file = _tmpFile('''
import 'package:flutter/material.dart';

class Foo extends StatelessWidget {
  const Foo({super.key});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      textDirection: TextDirection.ltr,
    );
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isNotEmpty,
          reason: 'textDirection: TextDirection.ltr must be flagged',
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

      test(
        'allows textDirection: computed from a locale-aware ternary',
        () async {
          // Mirrors scope_views.dart's chooseLevelPrompt pattern, cited in
          // AUD-tracks-25's recommendation as the correct, direction-aware
          // shape — the ternary is the argument's direct expression, not a
          // bare `TextDirection.rtl`/`.ltr` literal, so it must not fire.
          final file = _tmpFile('''
import 'package:flutter/material.dart';

class Foo extends StatelessWidget {
  const Foo({required this.useHebrew, super.key});

  final bool useHebrew;

  @override
  Widget build(BuildContext context) {
    return Text(
      'x',
      textDirection: useHebrew ? TextDirection.rtl : TextDirection.ltr,
    );
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where(
              (e) => e.errorCode.name == 'no_hardcoded_text_direction',
            ),
            isEmpty,
            reason:
                'a ternary keyed off a locale-aware flag is direction-aware '
                'and must not be flagged',
          );
        },
      );

      test('allows textDirection: Directionality.of(context)', () async {
        final file = _tmpFile('''
import 'package:flutter/material.dart';

class Foo extends StatelessWidget {
  const Foo({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'x',
      textDirection: Directionality.of(context),
    );
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors
              .where((e) => e.errorCode.name == 'no_hardcoded_text_direction'),
          isEmpty,
          reason: 'Directionality.of(context) is the ambient-locale-aware '
              'default and must not be flagged',
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
