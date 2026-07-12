// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_dead_error_field.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_dead_error_field_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _lintName = 'no_dead_error_field';

void main() {
  const rule = NoDeadErrorField();

  group('NoDeadErrorField', () {
    group('violations — loading/error field pair never set on failure', () {
      test(
        'flags a riverpod_generator Notifier (class Foo extends _\$Foo) '
        'whose state.copyWith(loading:, error:) is only ever reset to '
        'false/null, never set to a failure value (the '
        'AUD-gamification-10 RewardConfigController shape before the fix)',
        () async {
          final file = _tmpFile('''
class FormState {
  const FormState({this.loading = false, this.error});
  final bool loading;
  final String? error;
  FormState copyWith({bool? loading, Object? error = _sentinel}) {
    return FormState(
      loading: loading ?? this.loading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

class FooController extends _\$FooController {
  @override
  FormState build() => const FormState();

  Future<void> bootstrap() async {
    state = state.copyWith(loading: false, error: null);
  }

  Future<void> saveReward() async {
    await _svc.upsertMilestone();
    // No try/catch, no error surfaced on failure -- an unhandled Future
    // rejection.
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'a loading/error field pair that is never set to a failure '
                'value anywhere in the file must be flagged as dead',
          );
        },
      );

      test('flags a plain Notifier<T> (not codegen) with the same shape',
          () async {
        final file = _tmpFile('''
class BarState {
  const BarState({this.loading = false, this.error});
  final bool loading;
  final String? error;
  BarState copyWith({bool? loading, String? error}) =>
      BarState(loading: loading ?? this.loading, error: error);
}

class BarController extends Notifier<BarState> {
  @override
  BarState build() => const BarState();

  void reset() {
    state = state.copyWith(loading: false, error: null);
  }
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isNotEmpty,
        );
      });
    });

    group('allowed — at least one non-null error assignment exists', () {
      test(
        'does not flag when a copyWith(error: e.toString()) call exists '
        '(the AUD-gamification-10 fixed shape)',
        () async {
          final file = _tmpFile('''
class FormState {
  const FormState({this.loading = false, this.error});
  final bool loading;
  final String? error;
  FormState copyWith({bool? loading, Object? error = _sentinel}) {
    return FormState(
      loading: loading ?? this.loading,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

const _sentinel = Object();

class FooController extends _\$FooController {
  @override
  FormState build() => const FormState();

  Future<void> saveReward() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _svc.upsertMilestone();
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isEmpty,
            reason: 'a real non-null error: assignment anywhere in the file '
                'means the field is wired, not dead',
          );
        },
      );

      test('does not flag a file with no Notifier-like class at all', () async {
        final file = _tmpFile('''
class PlainState {
  const PlainState({this.loading = false, this.error});
  final bool loading;
  final String? error;
  PlainState copyWith({bool? loading, String? error}) =>
      PlainState(loading: loading ?? this.loading, error: error);
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(errors.where((e) => e.errorCode.name == _lintName), isEmpty);
      });

      test(
        'does not flag a Notifier whose copyWith calls never mention both '
        'loading: and error: together',
        () async {
          final file = _tmpFile('''
class OtherState {
  const OtherState({this.name = ''});
  final String name;
  OtherState copyWith({String? name}) => OtherState(name: name ?? this.name);
}

class OtherController extends _\$OtherController {
  @override
  OtherState build() => const OtherState();

  void setName(String value) => state = state.copyWith(name: value);
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(errors.where((e) => e.errorCode.name == _lintName), isEmpty);
        },
      );
    });
  });
}
