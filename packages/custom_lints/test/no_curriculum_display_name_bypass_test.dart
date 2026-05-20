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

/// Mirrors the private _isWhitelisted logic from the rule for unit-level tests.
bool _invokeIsWhitelisted(String path) {
  final normalised = path.replaceAll(r'\', '/');
  if (normalised.contains('lib/core/labels/')) return true;
  if (normalised.endsWith('.g.dart')) return true;
  if (normalised.endsWith('.freezed.dart')) return true;
  return false;
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
      test('isWhitelisted returns true for lib/core/labels/ path', () {
        expect(
          _invokeIsWhitelisted('lib/core/labels/curriculum_label.dart'),
          isTrue,
        );
      });

      test('isWhitelisted returns true for nested lib/core/labels/ path', () {
        expect(
          _invokeIsWhitelisted('lib/core/labels/renderers/label_renderer.dart'),
          isTrue,
        );
      });

      test('isWhitelisted returns true for .g.dart file', () {
        expect(_invokeIsWhitelisted('lib/features/foo/foo.g.dart'), isTrue);
      });

      test('isWhitelisted returns true for .freezed.dart file', () {
        expect(
          _invokeIsWhitelisted('lib/features/foo/foo.freezed.dart'),
          isTrue,
        );
      });

      test('isWhitelisted returns false for feature file', () {
        expect(
          _invokeIsWhitelisted('lib/features/dashboard/screen.dart'),
          isFalse,
        );
      });

      test('isWhitelisted returns false for core/sync file', () {
        expect(
          _invokeIsWhitelisted('lib/core/sync/some_merger.dart'),
          isFalse,
        );
      });

      test('isWhitelisted handles Windows-style separators for labels path',
          () {
        expect(
          _invokeIsWhitelisted(r'lib\core\labels\curriculum_label.dart'),
          isTrue,
        );
      });
    });
  });
}
