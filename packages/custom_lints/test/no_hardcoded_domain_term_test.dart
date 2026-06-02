// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_hardcoded_domain_term.dart';

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

const _codeName = 'no_hardcoded_domain_term';

void main() {
  const rule = NoHardcodedDomainTerm();

  group('NoHardcodedDomainTerm', () {
    group('violations', () {
      test('flags Text("Mishnayos done!") in presentation', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Mishnayos done!');
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: "Text('Mishnayos done!') must be flagged",
        );
      });

      test('flags a UI named arg (title:) with a domain term', () async {
        final file = _tmpFileAt(
          '''
class AppBar {
  const AppBar({this.title});
  final String? title;
}

Object build() => const AppBar(title: 'Masechta progress');
''',
          'lib/features/tracks/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'title: with a domain term must be flagged',
        );
      });

      test('flags a string-interpolation literal containing a term', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build(int n) => Text('Chazara: \$n');
''',
          'lib/features/learning/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isNotEmpty,
          reason: 'interpolation containing Chazara must be flagged',
        );
      });
    });

    group('allowed — negatives', () {
      test('does NOT flag domainTermLabels(ref).chazara', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

class Labels {
  String get chazara => 'x';
}

Labels domainTermLabels(Object ref) => Labels();

Object build(Object ref) => Text(domainTermLabels(ref).chazara);
''',
          'lib/features/learning/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'label-library access must not be flagged',
        );
      });

      test('does NOT flag a domain term inside a comment', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

// Mishnayos count is rendered elsewhere via the label library.
Object build() => const Text('hello');
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'a term in a comment must not be flagged',
        );
      });

      test('does NOT flag a domain term in a non-UI context (Map key)',
          () async {
        final file = _tmpFileAt(
          '''
const Map<String, int> counts = {
  'Mishnayos': 3,
};
''',
          'lib/features/learning/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'a Map key literal must not be flagged',
        );
      });

      test('does NOT flag in lib/core/labels/ (exempt)', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Mishnayos done!');
''',
          'lib/core/labels',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'lib/core/labels/ is exempt',
        );
      });

      test('does NOT flag in lib/l10n/ (exempt)', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Mishnayos done!');
''',
          'lib/l10n',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'lib/l10n/ is exempt',
        );
      });

      test('does NOT flag an ambiguous excluded word (Review)', () async {
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Review your progress');
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'excluded ambiguous words must not be flagged',
        );
      });

      test('does NOT flag a substring (e.g. word containing a term)', () async {
        // 'Shabbaton' contains 'Shabbat' but is not a whole-word match.
        final file = _tmpFileAt(
          '''
class Text {
  const Text(this.data);
  final String data;
}

Object build() => const Text('Shabbaton schedule');
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _codeName),
          isEmpty,
          reason: 'partial-word matches must not be flagged',
        );
      });
    });
  });
}
