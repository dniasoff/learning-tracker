// Mirror test for
// `lib/features/learning/domain/commands/learning_failure_reporter.dart`
// (DNI-469 AC-7: Crashlytics context is enums and counts only).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';

void main() {
  test('command kinds report stable storage values', () {
    expect(LearningCommandKind.values.map((k) => k.storage), [
      'capture',
      'void',
      'replace',
      'unlearn',
      'undo',
      'retry',
    ]);
  });

  test('the recorded error renders enums and a count only', () {
    for (final reason in PendingFailureReason.values) {
      final text = LearningWriteRejectedError(
        command: LearningCommandKind.replace,
        reason: reason,
        writeCount: 3,
      ).toString();
      expect(
        text,
        'LearningWriteRejected(command: replace, reason: ${reason.name}, '
        'writes: 3)',
      );
    }
  });
}
