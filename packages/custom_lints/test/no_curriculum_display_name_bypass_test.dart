// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_curriculum_display_name_bypass.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_display_name_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

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

/// Writes [content] to a temp file whose name ends with [suffix] (e.g.
/// `.g.dart`) so the rule's suffix-based whitelist checks are exercised
/// through the real analyzer path rather than a hand-copied helper.
File _tmpFileWithSuffix(String content, String suffix) {
  final file = File(
    '${Directory.systemTemp.path}/test_display_name_gen_${DateTime.now().microsecondsSinceEpoch}$suffix',
  );
  file.writeAsStringSync(content);
  return file;
}

void main() {
  const rule = NoCurriculumDisplayNameBypass();

  group('NoCurriculumDisplayNameBypass', () {
    group('violations', () {
      test('flags .displayNameEn property access outside core/labels',
          () async {
        // We define a local class so the analyzer can resolve the property.
        final file = _tmpFile('''
class MockCurriculum {
  String get displayNameEn => "Chumash";
}

void main() {
  final c = MockCurriculum();
  final name = c.displayNameEn; // violation
  print(name);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isNotEmpty,
          reason: 'displayNameEn access outside core/labels must be flagged',
        );
      });

      test('flags .displayNameHe property access outside core/labels',
          () async {
        final file = _tmpFile('''
class MockCurriculum {
  String get displayNameHe => "חומש";
}

void main() {
  final c = MockCurriculum();
  final name = c.displayNameHe; // violation
  print(name);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isNotEmpty,
          reason: 'displayNameHe access outside core/labels must be flagged',
        );
      });

      test('flags displayNameEn access in feature file', () async {
        final file = _tmpFileAt(
          '''
class MockCurriculum {
  String get displayNameEn => "Chumash";
}

void main() {
  final c = MockCurriculum();
  print(c.displayNameEn);
}
''',
          'lib/features/dashboard/presentation',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isNotEmpty,
          reason: 'displayNameEn in feature file must be flagged',
        );
      });

      test('flags displayNameHe access in core/sync (non-labels)', () async {
        final file = _tmpFileAt(
          '''
class MockCurriculum {
  String get displayNameHe => "גמרא";
}

void main() {
  final c = MockCurriculum();
  print(c.displayNameHe);
}
''',
          'lib/core/sync',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isNotEmpty,
          reason:
              'displayNameHe in core/sync (not core/labels) must be flagged',
        );
      });
    });

    group('allowed — whitelist', () {
      test('allows .displayNameEn inside lib/core/labels/', () async {
        final file = _tmpFileAt(
          '''
class MockCurriculum {
  String get displayNameEn => "Chumash";
}

void main() {
  final c = MockCurriculum();
  print(c.displayNameEn); // allowed here
}
''',
          'lib/core/labels',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isEmpty,
          reason: 'displayNameEn inside lib/core/labels/ must be allowed',
        );
      });

      test('allows .displayNameHe inside lib/core/labels/', () async {
        final file = _tmpFileAt(
          '''
class MockCurriculum {
  String get displayNameHe => "גמרא";
}

void main() {
  final c = MockCurriculum();
  print(c.displayNameHe); // allowed here
}
''',
          'lib/core/labels',
        );
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isEmpty,
          reason: 'displayNameHe inside lib/core/labels/ must be allowed',
        );
      });

      test('allows code without restricted property names', () async {
        final file = _tmpFile('''
class Track {
  String get name => "Chumash";
  int get count => 42;
}

void main() {
  final t = Track();
  print(t.name);
  print(t.count);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isEmpty,
          reason: 'Properties other than displayNameEn/He must not be flagged',
        );
      });
    });

    group('whitelist — file path checks', () {
      test('displayNameEn access allowed in generated .g.dart file', () async {
        final file = _tmpFileWithSuffix('''
class MockCurriculum {
  String get displayNameEn => "Chumash";
}

void main() {
  final c = MockCurriculum();
  print(c.displayNameEn);
}
''', '.g.dart');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isEmpty,
          reason: 'Generated .g.dart files are whitelisted',
        );
      });

      test('displayNameHe access allowed in generated .freezed.dart file',
          () async {
        final file = _tmpFileWithSuffix('''
class MockCurriculum {
  String get displayNameHe => "גמרא";
}

void main() {
  final c = MockCurriculum();
  print(c.displayNameHe);
}
''', '.freezed.dart');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isEmpty,
          reason: 'Generated .freezed.dart files are whitelisted',
        );
      });

      test(
          'displayNameEn access allowed with Windows-style backslash path '
          'segments', () async {
        // Simulates a Windows-reported path — a single directory literally
        // named "lib\core\labels" (backslashes as characters, not
        // separators, since this test runs on Linux) so the rule's
        // path.replaceAll(r'\', '/') normalisation is exercised through the
        // real analyzer path, matching production behavior when `dart
        // analyze` runs on Windows.
        final file = _tmpFileAt('''
class MockCurriculum {
  String get displayNameEn => "Chumash";
}

void main() {
  final c = MockCurriculum();
  print(c.displayNameEn); // allowed here
}
''', r'lib\core\labels');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where(
            (e) => e.errorCode.name == 'no_curriculum_display_name_bypass',
          ),
          isEmpty,
          reason: 'Windows-style backslash path segments must normalise to '
              'lib/core/labels/ and be allowed',
        );
      });
    });
  });
}
