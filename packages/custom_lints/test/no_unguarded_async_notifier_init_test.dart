// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_unguarded_async_notifier_init.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_unguarded_init_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _lintName = 'no_unguarded_async_notifier_init';

void main() {
  const rule = NoUnguardedAsyncNotifierInit();

  group('NoUnguardedAsyncNotifierInit', () {
    group('violations — fire-and-forget private async init, zero try/catch',
        () {
      test(
        'flags build() firing an unawaited _init() with no try/catch in '
        '_init() (the pre-fix AUD-account-11 AuthStateNotifier shape, '
        'riverpod_generator codegen base class)',
        () async {
          final file = _tmpFile('''
class AuthState {
  const AuthState.initializing();
}

abstract class _\$AuthStateNotifier {
  AuthState build();
}

class AuthStateNotifier extends _\$AuthStateNotifier {
  @override
  AuthState build() {
    _init();
    return const AuthState.initializing();
  }

  Future<void> _init() async {
    final firebaseUser = await Future.value(null);
    if (firebaseUser != null) {
      throw Exception('boom');
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A Notifier build() that fires an unawaited private async '
                'method with zero try/catch in its body must be flagged '
                '(the exact AUD-account-11 pre-fix shape)',
          );
        },
      );

      test(
          'flags plain Notifier<T> superclass shape, not just the '
          'riverpod_generator _\$ codegen shape', () async {
        final file = _tmpFile('''
class FooState {}

class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() {
    _load();
    return FooState();
  }

  Future<void> _load() async {
    await Future.value();
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isNotEmpty,
          reason: 'Plain Notifier<T> superclass must also be scanned, not '
              'only the _\$ codegen convention',
        );
      });
    });

    group('allowed — the AUD-account-11 post-fix shape and other safe forms',
        () {
      test(
          'does not flag _init() once its entire body is wrapped in '
          'try/catch (the actual AUD-account-11 fix)', () async {
        final file = _tmpFile('''
class AuthState {
  const AuthState.initializing();
  const AuthState.signedOut();
}

abstract class _\$AuthStateNotifier {
  AuthState build();
}

class AuthStateNotifier extends _\$AuthStateNotifier {
  @override
  AuthState build() {
    _init();
    return const AuthState.initializing();
  }

  Future<void> _init() async {
    try {
      final firebaseUser = await Future.value(null);
      if (firebaseUser != null) {
        throw Exception('boom');
      }
    } on Exception catch (e, st) {
      // logged and resolved to a terminal state
    }
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A private async method whose body is guarded by '
              'try/catch anywhere must not be flagged, even called '
              'fire-and-forget',
        );
      });

      test('does not flag an awaited call to the private async method',
          () async {
        final file = _tmpFile('''
class FooState {}

class FooNotifier extends Notifier<FooState> {
  @override
  Future<FooState> build() async {
    await _load();
    return FooState();
  }

  Future<void> _load() async {
    await Future.value();
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'An awaited call lets the exception propagate normally '
              'and must not be flagged',
        );
      });

      test('does not flag a call wrapped in try/catch at the call site',
          () async {
        final file = _tmpFile('''
class FooState {}

class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() {
    try {
      _load();
    } catch (_) {}
    return FooState();
  }

  Future<void> _load() async {
    await Future.value();
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A fire-and-forget call guarded by try/catch at the call '
              'site must not be flagged',
        );
      });

      test('does not flag a fire-and-forget call to a synchronous method',
          () async {
        final file = _tmpFile('''
class FooState {}

class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() {
    _logStart();
    return FooState();
  }

  void _logStart() {
    print('starting');
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A synchronous callee cannot leave a dangling Future '
              'rejection and must not be flagged',
        );
      });

      test('does not flag a fire-and-forget call to a public async method',
          () async {
        final file = _tmpFile('''
class FooState {}

class FooNotifier extends Notifier<FooState> {
  @override
  FooState build() {
    refresh();
    return FooState();
  }

  Future<void> refresh() async {
    await Future.value();
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'Only private (underscore-prefixed) callees are in scope '
              'for this rule',
        );
      });

      test('does not flag a class that is not Notifier-like', () async {
        final file = _tmpFile('''
class PlainService {
  void build() {
    _init();
  }

  Future<void> _init() async {
    await Future.value();
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A class that does not extend a Riverpod Notifier base '
              '(or its _\$ codegen base) must never be flagged',
        );
      });
    });
  });
}
