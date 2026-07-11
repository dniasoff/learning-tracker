// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_log_less_catch.dart';

/// Writes [content] to a path that contains [pathSegment] (so the rule's
/// `lib/` scoping check can be exercised deterministically).
File _tmpFileAt(String content, String pathSegment) {
  final dir = Directory('${Directory.systemTemp.path}/$pathSegment');
  dir.createSync(recursive: true);
  final file = File(
    '${dir.path}/test_log_less_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _lintName = 'no_log_less_catch';
const _libPath = 'lib/features/onboarding/presentation/screens';

void main() {
  const rule = NoLogLessCatch();

  group('NoLogLessCatch', () {
    group('violations', () {
      test(
        'flags a comment-only catch body (the pre-fix '
        'BulkMarkScreen._loadPreExistingCompletions shape — dodges '
        "empty_catches' comment carve-out)",
        () async {
          final file = _tmpFileAt('''
Future<void> load() async {
  try {
    await Future.value();
  } catch (_) {
    // Non-fatal: if pre-tick loading fails just open with unticked state.
  }
}
''', _libPath);
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A comment-only catch body with no AppLogger call and no '
                'rethrow must be flagged',
          );
        },
      );

      test('flags a literally empty catch body', () async {
        final file = _tmpFileAt('''
Future<void> load() async {
  try {
    await Future.value();
  } catch (_) {}
}
''', _libPath);
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isNotEmpty,
        );
      });

      test(
        'flags a catch body that does something (setState) but never logs '
        'or rethrows',
        () async {
          final file = _tmpFileAt('''
class FooState {
  void setState(void Function() fn) {}

  Future<void> load() async {
    try {
      await Future.value();
    } catch (e) {
      setState(() {});
    }
  }
}
''', _libPath);
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A catch body that silently does something else (without '
                'logging or rethrowing) is still log-less and must be '
                'flagged',
          );
        },
      );
    });

    group('allowed', () {
      test(
        'does not flag a catch body that logs via AppLogger.instance '
        '(the _expungeRefs.catchError pattern already used in the same '
        'file)',
        () async {
          final file = _tmpFileAt('''
Future<void> load() async {
  try {
    await Future.value();
  } catch (e, st) {
    AppLogger.instance.error(
      event: 'load failed',
      exception: e,
      stackTrace: st,
    );
  }
}
''', _libPath);
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
          );
        },
      );

      test(
          'does not flag a catch body that logs via AppLogger.instance.warning',
          () async {
        final file = _tmpFileAt('''
Future<void> load() async {
  try {
    await Future.value();
  } catch (e, st) {
    AppLogger.instance.warning(event: 'load failed', exception: e, stackTrace: st);
  }
}
''', _libPath);
        final errors = await rule.testAnalyzeAndRun(file);
        expect(errors.where((e) => e.errorCode.name == _lintName), isEmpty);
      });

      test('does not flag a catch body that rethrows', () async {
        final file = _tmpFileAt('''
Future<void> load() async {
  try {
    await Future.value();
  } catch (e) {
    rethrow;
  }
}
''', _libPath);
        final errors = await rule.testAnalyzeAndRun(file);
        expect(errors.where((e) => e.errorCode.name == _lintName), isEmpty);
      });

      test('does not flag a catch clause outside lib/ (e.g. test code)',
          () async {
        final file = _tmpFileAt('''
Future<void> load() async {
  try {
    await Future.value();
  } catch (_) {
    // swallowed in a test helper
  }
}
''', 'test/features/onboarding');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: "This rule's checker AC scopes to lib/ only",
        );
      });
    });
  });
}
