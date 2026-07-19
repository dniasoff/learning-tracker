// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_e_to_string_in_ui.dart';

/// Writes [content] to a temp file whose path contains a `presentation/`
/// segment — matching the path-scoping the rule checks
/// (`resolver.path.contains('/presentation/')`). [subPath] lets a test
/// mirror a specific real feature layout (e.g.
/// `features/progress/presentation/screens`) so the fixture matches
/// AUD-progress-08's evidence sites exactly.
File _tmpFileNamed(
  String content,
  String fileName, {
  String subPath = 'lib/features/some_feature/presentation/screens',
}) {
  final dir = Directory(
    '${Directory.systemTemp.path}/'
    'no_e_to_string_in_ui_${DateTime.now().microsecondsSinceEpoch}/'
    '$subPath',
  );
  dir.createSync(recursive: true);
  final file = File('${dir.path}/$fileName');
  file.writeAsStringSync(content);
  return file;
}

const _codeName = 'no_e_to_string_in_ui';

void main() {
  const rule = NoEToStringInUi();

  group('NoEToStringInUi', () {
    group('violations — inside presentation/', () {
      test(
        'flags error.toString() interpolated into an l10n(...) call '
        '(the AUD-progress-08 lifetime_knowledge_screen.dart shape)',
        () async {
          final file = _tmpFileNamed(
            '''
class L10n {
  String lifetimeKnowledgeLoadError(String error) => error;
}

Object build(L10n l10n, Object error) {
  return l10n.lifetimeKnowledgeLoadError(error.toString());
}
''',
            'lifetime_knowledge_screen.dart',
            subPath: 'lib/features/progress/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _codeName),
            isNotEmpty,
            reason: 'error.toString() flowing into an l10n(...) call inside '
                'features/progress/presentation/ must be flagged',
          );
        },
      );

      test('flags e.toString() passed straight to Text(...)', () async {
        final file = _tmpFileNamed(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build(Object e) => Text(e.toString());
''',
          'some_screen.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'e.toString() rendered directly in presentation/ must be '
              'flagged',
        );
      });

      test(
          'flags exception.toString() (a less common but valid catch '
          'identifier)', () async {
        final file = _tmpFileNamed(
          '''
Object build(Object exception) => exception.toString();
''',
          'another_screen.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'exception.toString() in presentation/ must be flagged',
        );
      });

      test('flags err.toString() (the short catch-identifier spelling)',
          () async {
        final file = _tmpFileNamed(
          '''
Object build(Object err) => err.toString();
''',
          'another_screen.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'err.toString() in presentation/ must be flagged',
        );
      });

      test('flags ex.toString() (the abbreviated catch-identifier spelling)',
          () async {
        final file = _tmpFileNamed(
          '''
Object build(Object ex) => ex.toString();
''',
          'another_screen.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'ex.toString() in presentation/ must be flagged',
        );
      });
    });

    group('allowed — negatives (the AUD-progress-08 post-fix shape)', () {
      test(
        'does NOT flag a no-arg localized call with no error interpolation '
        '(the recent_activity_screen.dart / post-fix pattern)',
        () async {
          final file = _tmpFileNamed(
            '''
class L10n {
  String get lifetimeKnowledgeLoadError => 'x';
}

Object build(L10n l10n, Object error) {
  return l10n.lifetimeKnowledgeLoadError;
}
''',
            'lifetime_knowledge_screen.dart',
            subPath: 'lib/features/progress/presentation/screens',
          );
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _codeName),
            isEmpty,
            reason: 'a generic localized error string with no '
                '.toString() call must not be flagged',
          );
        },
      );

      test('does NOT flag .toString() on an unrelated identifier', () async {
        final file = _tmpFileNamed(
          '''
Object build(int count) => count.toString();
''',
          'some_screen.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'toString() on a non-exception-named identifier (count) '
              'must not be flagged',
        );
      });

      test('does NOT flag error.toString() outside a presentation/ path',
          () async {
        final file = _tmpFileNamed(
          '''
Object build(Object error) => error.toString();
''',
          'error_mapper.dart',
          subPath: 'lib/features/progress/domain',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'this rule is scoped to presentation/ only — domain-layer '
              'error.toString() (e.g. for logging) is a separate, '
              'out-of-scope concern',
        );
      });

      test('does NOT flag error.toString() in a generated .g.dart file',
          () async {
        final file = _tmpFileNamed(
          '''
Object build(Object error) => error.toString();
''',
          'some_screen.g.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'generated .g.dart files are exempt from this rule even '
              'inside presentation/',
        );
      });

      test('does NOT flag error.toString() in a generated .freezed.dart file',
          () async {
        final file = _tmpFileNamed(
          '''
Object build(Object error) => error.toString();
''',
          'some_state.freezed.dart',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'generated .freezed.dart files are exempt from this rule '
              'even inside presentation/',
        );
      });
    });
  });
}
