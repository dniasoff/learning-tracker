// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_hardcoded_error_widget_string.dart';

/// Writes [content] to a temp file whose path ends with
/// `lib/core/widgets/<fileName>` — matching the exact-file scoping the rule
/// checks (`resolver.path.endsWith(...)`).
File _tmpFileNamed(String content, String fileName) {
  final dir = Directory(
    '${Directory.systemTemp.path}/'
    'no_hardcoded_error_widget_string_${DateTime.now().microsecondsSinceEpoch}/'
    'lib/core/widgets',
  );
  dir.createSync(recursive: true);
  final file = File('${dir.path}/$fileName');
  file.writeAsStringSync(content);
  return file;
}

const _codeName = 'no_hardcoded_error_widget_string';

void main() {
  const rule = NoHardcodedErrorWidgetString();

  group('NoHardcodedErrorWidgetString', () {
    group('violations — inside a target file', () {
      test('flags Text("Retry") in app_error_view.dart', () async {
        final file = _tmpFileNamed(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Retry');
''',
          'app_error_view.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: "Text('Retry') in app_error_view.dart must be flagged",
        );
      });

      test(
        'flags a hardcoded title: on a non-Flutter helper class '
        '(the _ErrorConfig shape) in app_error_view.dart',
        () async {
          final file = _tmpFileNamed(
            '''
class ErrorConfig {
  const ErrorConfig({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
}

Object build() => const ErrorConfig(
      title: 'Something went wrong',
      subtitle: 'An unexpected error occurred. Try again or report the issue.',
    );
''',
            'app_error_view.dart',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _codeName),
            isNotEmpty,
            reason: 'a hardcoded title:/subtitle: literal must be flagged',
          );
        },
      );

      test('flags Text("Retry") in error_display.dart', () async {
        final file = _tmpFileNamed(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Retry');
''',
          'error_display.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: "Text('Retry') in error_display.dart must be flagged",
        );
      });

      test(
        'flags a hardcoded lockout string interpolation in '
        'pin_entry_widget.dart',
        () async {
          final file = _tmpFileNamed(
            '''
class Text {
  const Text(this.data);
  final String data;
}

Object build(int minutes) => Text('Try again in \$minutes minute(s)');
''',
            'pin_entry_widget.dart',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _codeName),
            isNotEmpty,
            reason: 'a hardcoded interpolated Text(...) must be flagged',
          );
        },
      );
    });

    group('allowed — negatives', () {
      test(
          'does NOT flag Text(l10n.actionRetry) (an identifier, not a '
          'literal) in app_error_view.dart', () async {
        final file = _tmpFileNamed(
          '''
class Text {
  const Text(this.data);
  final String data;
}

class L10n {
  String get actionRetry => 'x';
}

Object build(L10n l10n) => Text(l10n.actionRetry);
''',
          'app_error_view.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'an l10n getter reference must not be flagged',
        );
      });

      test(
          'does NOT flag the same Text("Retry") literal in an '
          'out-of-scope core/widgets file', () async {
        final file = _tmpFileNamed(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Retry');
''',
          'track_progress_bar.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'this rule is scoped to exactly app_error_view.dart / '
              'error_display.dart / pin_entry_widget.dart — other '
              'core/widgets files are a separate, out-of-scope defect',
        );
      });

      test(
          'does NOT flag a non-UI-context literal (a Map key) in '
          'pin_entry_widget.dart', () async {
        final file = _tmpFileNamed(
          '''
const Map<String, int> counts = {
  'Retry': 3,
};
''',
          'pin_entry_widget.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'a Map key literal must not be flagged',
        );
      });

      test(
          'does NOT flag a purely structural literal (obscuringCharacter: '
          "' ') in pin_entry_widget.dart", () async {
        final file = _tmpFileNamed(
          '''
class TextField {
  const TextField({this.obscuringCharacter});
  final String? obscuringCharacter;
}

Object build() => const TextField(obscuringCharacter: ' ');
''',
          'pin_entry_widget.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'a letter-less structural literal must not be flagged',
        );
      });
    });
  });
}
