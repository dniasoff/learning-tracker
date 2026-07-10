// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:test/test.dart';

import 'package:learning_tracker_lints/src/rules/no_hand_rolled_async_state_notifier.dart';

/// Writes [content] to a temporary file and returns it.
File _tmpFile(String content) {
  final file = File(
    '${Directory.systemTemp.path}/test_async_state_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  file.writeAsStringSync(content);
  return file;
}

const _lintName = 'no_hand_rolled_async_state_notifier';

void main() {
  const rule = NoHandRolledAsyncStateNotifier();

  group('NoHandRolledAsyncStateNotifier', () {
    group('violations — Idle/Loading/Error sealed union on Notifier<T>', () {
      test(
        'flags a Notifier<T> whose sealed state has Idle/Submitting/Error '
        'variants (the AUD-account-14 SignInController shape)',
        () async {
          final file = _tmpFile('''
sealed class SignInState {
  const SignInState();
}

final class SignInIdle extends SignInState {
  const SignInIdle();
}

final class SignInSubmitting extends SignInState {
  const SignInSubmitting();
}

final class SignInError extends SignInState {
  const SignInError(this.message);
  final String message;
}

class SignInController extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInIdle();
}
''');
          final errors = await rule.testAnalyzeAndRun(file);
          expect(
            errors.where((e) => e.errorCode.name == _lintName),
            isNotEmpty,
            reason: 'A hand-rolled Idle/Submitting/Error union on Notifier<T> '
                'must be flagged as an SM-5 migration candidate',
          );
        },
      );

      test('flags Loading/Success-adjacent naming (Pending + Failed)',
          () async {
        final file = _tmpFile('''
sealed class FooState {}
final class FooInitial extends FooState {}
final class FooPending extends FooState {}
final class FooFailed extends FooState {}

class FooController extends Notifier<FooState> {
  @override
  FooState build() => FooInitial();
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isNotEmpty,
          reason: 'Initial/Pending/Failed naming must also match the '
              'idle/loading/error buckets',
        );
      });
    });

    group('allowed — AsyncNotifier is the migration target, never flagged', () {
      test(
          'does not flag AsyncNotifier<T> even with an Idle/Loading/Error '
          'sealed type parameter', () async {
        final file = _tmpFile('''
sealed class BarState {}
final class BarIdle extends BarState {}
final class BarLoading extends BarState {}
final class BarError extends BarState {}

class BarController extends AsyncNotifier<BarState> {
  @override
  Future<BarState> build() async => BarIdle();
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'AsyncNotifier<T> is the migration target, never flagged',
        );
      });
    });

    group('allowed — missing bucket does not trip the rule', () {
      test(
          'does not flag a Notifier<T> with only Idle + Error (no loading '
          'variant)', () async {
        final file = _tmpFile('''
sealed class BazState {}
final class BazIdle extends BazState {}
final class BazError extends BazState {}

class BazController extends Notifier<BazState> {
  @override
  BazState build() => BazIdle();
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'Missing the loading bucket must not trip the rule',
        );
      });

      test('does not flag a Notifier<T> whose state type is not sealed',
          () async {
        final file = _tmpFile('''
class QuxState {}
class QuxIdle extends QuxState {}
class QuxLoading extends QuxState {}
class QuxError extends QuxState {}

class QuxController extends Notifier<QuxState> {
  @override
  QuxState build() => QuxIdle();
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A non-sealed state type must not trip the rule',
        );
      });
    });

    group('allowed — wizard-step-shaped sealed unions are a different shape',
        () {
      test(
          'does not flag a multi-step wizard union with no Idle/Loading/'
          'Error naming (AddTrackFlowState shape)', () async {
        final file = _tmpFile('''
sealed class AddTrackFlowState {}
final class CurriculumChoiceState extends AddTrackFlowState {}
final class ProgramChoiceState extends AddTrackFlowState {}
final class ConfirmationState extends AddTrackFlowState {}

class AddTrackController extends Notifier<AddTrackFlowState> {
  @override
  AddTrackFlowState build() => CurriculumChoiceState();
}
''');
        final errors = await rule.testAnalyzeAndRun(file);
        expect(
          errors.where((e) => e.errorCode.name == _lintName),
          isEmpty,
          reason: 'A wizard-step union with no Idle/Loading/Error-shaped names '
              'must not be flagged',
        );
      });
    });
  });
}
