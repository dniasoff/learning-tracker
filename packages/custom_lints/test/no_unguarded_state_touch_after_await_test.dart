// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_unguarded_state_touch_after_await.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_unguarded_state_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _lintName = 'no_unguarded_state_touch_after_await';

void main() {
  const rule = NoUnguardedStateTouchAfterAwait();

  group('NoUnguardedStateTouchAfterAwait', () {
    group('violations', () {
      test(
        'flags `state = ...` after an unguarded await in a Notifier method '
        '(the pre-fix OnboardingController.advance shape)',
        () async {
          final file = _tmpFile('''
abstract class _\$FooController {
  FooState get state;
  set state(FooState value);
}

class FooState {
  FooState copyWith() => this;
}

class FooController extends _\$FooController {
  @override
  FooState state = FooState();

  Future<void> advance() async {
    await Future.value();
    state = state.copyWith();
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'state = ... after an unguarded await in a Notifier method '
                'must be flagged',
          );
        },
      );

      test(
        'flags a bare setState(...) after an unguarded await in a State '
        'method (the pre-fix BulkMarkScreen._proceedToConfirmation shape)',
        () async {
          final file = _tmpFile('''
class FooWidget {}

class FooState extends State<FooWidget> {
  Future<void> proceed() async {
    await Future.value();
    setState(() {});
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'setState(...) after an unguarded await in a State method '
                'must be flagged',
          );
        },
      );

      test(
        'flags setState(...) in a catch clause whose sibling try contains '
        'an await (the pre-fix BulkMarkScreen._executeBulkMark catch shape)',
        () async {
          final file = _tmpFile('''
class FooWidget {}

class FooState extends State<FooWidget> {
  Future<void> execute() async {
    try {
      await Future.value();
    } catch (e) {
      setState(() {});
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason:
                'setState(...) in a catch whose try awaited must be flagged '
                'even though the catch body itself has no await',
          );
        },
      );

      test(
        'flags setState(...) inside the try body itself, after its own '
        'await',
        () async {
          final file = _tmpFile('''
class FooWidget {}

class FooState extends State<FooWidget> {
  Future<void> execute() async {
    try {
      await Future.value();
      setState(() {});
    } catch (e) {
      // handled elsewhere
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason:
                'setState(...) after an await inside the same try body must '
                'be flagged',
          );
        },
      );
    });

    group('allowed', () {
      test(
        'does not flag state = ... guarded by `if (!ref.mounted) return;`',
        () async {
          final file = _tmpFile('''
abstract class _\$FooController {
  FooState get state;
  set state(FooState value);
}

class FooState {
  FooState copyWith() => this;
}

class FooController extends _\$FooController {
  @override
  FooState state = FooState();

  Future<void> advance() async {
    await Future.value();
    if (!ref.mounted) return;
    state = state.copyWith();
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'An early-return `if (!ref.mounted) return;` guard must '
                'suppress the flag for everything after it',
          );
        },
      );

      test(
        'does not flag setState(...) guarded by `if (!mounted) return;`',
        () async {
          final file = _tmpFile('''
class FooWidget {}

class FooState extends State<FooWidget> {
  Future<void> proceed() async {
    await Future.value();
    if (!mounted) return;
    setState(() {});
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
          );
        },
      );

      test(
        'does not flag setState(...) wrapped in `if (mounted) { ... }`',
        () async {
          final file = _tmpFile('''
class FooWidget {}

class FooState extends State<FooWidget> {
  Future<void> proceed() async {
    await Future.value();
    if (mounted) {
      setState(() {});
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
          );
        },
      );

      test(
        'does not flag setState(...) in a catch whose sibling try has no '
        'await (the post-fix BulkMarkScreen shape after guarding)',
        () async {
          final file = _tmpFile('''
class FooWidget {}

class FooState extends State<FooWidget> {
  void execute() {
    try {
      final x = 1 + 1;
    } catch (e) {
      setState(() {});
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'No await anywhere in the sibling try means nothing could '
                'have raced a disposal',
          );
        },
      );

      test('does not flag setState(...) with no preceding await at all',
          () async {
        final file = _tmpFile('''
class FooWidget {}

class FooState extends State<FooWidget> {
  void toggle() {
    setState(() {});
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(errors.where((e) => e.errorCode.name == _lintName), isEmpty);
      });

      test(
        'does not flag a class that is neither Notifier-like nor State-like',
        () async {
          final file = _tmpFile('''
class PlainService {
  dynamic state;

  Future<void> run() async {
    await Future.value();
    state = 1;
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason:
                'A plain class unrelated to Riverpod/Flutter lifecycle must '
                'never be flagged',
          );
        },
      );
    });
  });
}
