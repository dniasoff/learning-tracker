// Unit tests for `lib/core/utils/guarded_persist.dart` (AUD-core-preferences-04).
//
// [guardedPersist] is the shared EH-2/SM-5 guard every plain-value Notifier
// mutation method in the finding's scope routes its persistence call
// through. Directly exercises its two contracts:
//   * a successful [write] resolves normally, [onFailure] is never called,
//     and nothing is logged.
//   * a failing [write] is caught (the returned Future never rejects),
//     logged via [AppLogger] under [event], and [onFailure] is invoked
//     exactly once.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/guarded_persist.dart';

void main() {
  setUp(() {
    // Reset the AppLogger singleton (and its Talker history) between tests.
    AppLogger.init();
  });

  group('guardedPersist', () {
    test('a successful write completes normally without calling onFailure or '
        'logging anything', () async {
      var writeCalled = false;
      var onFailureCalled = false;
      final historyBefore = AppLogger.rawTalker.history.length;

      await guardedPersist(
        event: 'test_persist_ok',
        write: () async {
          writeCalled = true;
        },
        onFailure: () => onFailureCalled = true,
      );

      expect(writeCalled, isTrue);
      expect(onFailureCalled, isFalse);
      expect(AppLogger.rawTalker.history.length, historyBefore);
    });

    test('a failing write never lets the exception escape, calls onFailure '
        'exactly once, and logs the failure via AppLogger under the given '
        'event', () async {
      var onFailureCallCount = 0;
      Object? caughtError;

      await runZonedGuarded(() async {
        await guardedPersist(
          event: 'test_persist_failed',
          write: () async {
            throw Exception('simulated write failure');
          },
          onFailure: () => onFailureCallCount++,
        );
      }, (error, stack) => caughtError = error);

      expect(
        caughtError,
        isNull,
        reason:
            'guardedPersist must never let a write failure escape as an '
            'unobserved/unhandled exception (got: $caughtError)',
      );
      expect(onFailureCallCount, 1);

      final lastLog = AppLogger.rawTalker.history.last;
      expect(lastLog.message, contains('test_persist_failed'));
      expect(lastLog.exception ?? lastLog.error, isNotNull);
    });

    test(
      'onFailure is not called more than once for a single failure',
      () async {
        var onFailureCallCount = 0;

        await guardedPersist(
          event: 'test_persist_failed_once',
          write: () async => throw Exception('boom'),
          onFailure: () => onFailureCallCount++,
        );

        expect(onFailureCallCount, 1);
      },
    );

    test('optional fields are included in the logged event', () async {
      await guardedPersist(
        event: 'test_persist_failed_with_fields',
        write: () async => throw Exception('boom'),
        onFailure: () {},
        fields: {'profileId': 42},
      );

      final lastLog = AppLogger.rawTalker.history.last;
      expect(lastLog.message, contains('test_persist_failed_with_fields'));
      expect(lastLog.message, contains('profileId'));
      expect(lastLog.message, contains('42'));
    });
  });
}
