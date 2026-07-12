// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_onboarding_raw_string_literal.dart';

/// Writes [content] to a path that contains [pathSegment].
File _tmpFileAt(String content, String pathSegment) {
  final dir = Directory(
    '${Directory.systemTemp.path}/$pathSegment',
  );
  dir.createSync(recursive: true);
  final file = File(
    '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _codeName = 'no_onboarding_raw_string_literal';

void main() {
  const rule = NoOnboardingRawStringLiteral();

  group('NoOnboardingRawStringLiteral', () {
    group('violations', () {
      test('flags Text("All Set!") under onboarding/presentation', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('All Set!');
''',
          'lib/features/onboarding/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: "Text('All Set!') must be flagged",
        );
      });

      test('flags errorText: with a raw literal', () async {
        final file = _tmpFileAt(
          '''
class InputDecoration {
  const InputDecoration({this.errorText});
  final String? errorText;
}

Object build() => const InputDecoration(errorText: 'PINs do not match');
''',
          'lib/features/onboarding/presentation/steps',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'errorText: with a raw literal must be flagged',
        );
      });

      test('flags hintText: with a raw literal', () async {
        final file = _tmpFileAt(
          '''
class InputDecoration {
  const InputDecoration({this.hintText});
  final String? hintText;
}

Object build() => const InputDecoration(hintText: 'Enter a name');
''',
          'lib/features/onboarding/presentation/steps',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'hintText: with a raw literal must be flagged',
        );
      });

      test('flags label: with a raw literal (AppBarTitle-style text:)',
          () async {
        final file = _tmpFileAt(
          '''
class AppBarTitle {
  const AppBarTitle({this.text});
  final String? text;
}

Object build() => const AppBarTitle(text: 'Set Parent PIN');
''',
          'lib/features/onboarding/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'AppBarTitle(text: ...) with a raw literal must be flagged',
        );
      });

      test('flags a string-interpolation literal with prose content', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build(String name) => Text("\$name's learning is all set up");
''',
          'lib/features/onboarding/presentation/steps',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'interpolation with literal prose must be flagged',
        );
      });
    });

    group('allowed — negatives', () {
      test('does NOT flag Text(l10n.someKey) — an l10n getter access',
          () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

class L10n {
  String get onboardingAllSet => 'x';
}

Object build(L10n l10n) => Text(l10n.onboardingAllSet);
''',
          'lib/features/onboarding/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'an AppLocalizations getter access must not be flagged',
        );
      });

      test('does NOT flag outside lib/features/onboarding/presentation/',
          () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('All Set!');
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'files outside the onboarding presentation dir are exempt',
        );
      });

      test('does NOT flag in a onboarding _test.dart file (exempt)', () async {
        final file = File(
          '${Directory.systemTemp.path}/lib/features/onboarding/presentation/'
          '${DateTime.now().microsecondsSinceEpoch}_widget_test.dart',
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('All Set!');
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: '_test.dart files are exempt',
        );
      });

      test('does NOT flag an empty-string literal (spacer/separator)',
          () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('');
''',
          'lib/features/onboarding/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'an empty-string literal must not be flagged',
        );
      });

      test('does NOT flag a literal in a non-UI context (Map key)', () async {
        final file = _tmpFileAt(
          '''
const Map<String, int> counts = {
  'adult': 1,
};
''',
          'lib/features/onboarding/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'a Map key literal must not be flagged',
        );
      });

      test('does NOT flag a non-UI named arg (e.g. profileMode:)', () async {
        final file = _tmpFileAt(
          '''
class Profile {
  const Profile({this.profileMode});
  final String? profileMode;
}

Object build() => const Profile(profileMode: 'adult');
''',
          'lib/features/onboarding/presentation/screens',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'a non-UI named argument must not be flagged',
        );
      });
    });
  });
}
