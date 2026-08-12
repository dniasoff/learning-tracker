/// Unit tests for `study_day_toggle_service.dart` — the extracted
/// track-resolution guard and write-then-invalidate ordering helpers behind
/// `study_day_config_screen.dart` (AUD-t-scheduler-02).
@Tags(['scheduler', 'study_day'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/study_day_toggle_service.dart';

void main() {
  group('writeThenInvalidate (STUDYDAY-TOGGLE-RACE-14 ordering)', () {
    test('invalidate runs only after write resolves', () async {
      final events = <String>[];
      final writeCompleter = Completer<void>();

      final future = writeThenInvalidate(
        write: () async {
          await writeCompleter.future;
          events.add('write');
        },
        invalidate: () => events.add('invalidate'),
      );

      // Give the event loop a turn: if invalidate ran synchronously/early
      // (the STUDYDAY-TOGGLE-RACE-14 bug), it would already be recorded here
      // even though the write has not resolved.
      await Future<void>.delayed(Duration.zero);
      expect(
        events,
        isEmpty,
        reason: 'invalidate must not fire before write completes',
      );

      writeCompleter.complete();
      await future;

      expect(
        events,
        equals(['write', 'invalidate']),
        reason:
            'STUDYDAY-TOGGLE-RACE-14: invalidate must run strictly after '
            'the awaited write, never before.',
      );
    });

    test('propagates a write failure without invoking invalidate', () async {
      var invalidated = false;

      await expectLater(
        writeThenInvalidate(
          write: () => Future<void>.error(Exception('write failed')),
          invalidate: () => invalidated = true,
        ),
        throwsA(isException),
      );

      expect(
        invalidated,
        isFalse,
        reason: 'a failed write must not trigger a scheduler invalidation',
      );
    });
  });

  // ── AUD-scheduler-17 ─────────────────────────────────────────────────────
  //
  // _toggleDay ran the DB write with no surrounding try/catch (a thrown
  // upsertDayConfig error had no local AppLogger call) and invalidated the
  // scheduler with no context.mounted guard, unlike the SnackBar guard three
  // lines later in the same method. writeThenInvalidateGuarded is the exact
  // function _toggleDay now calls — these tests drive it directly.
  group('writeThenInvalidateGuarded (AUD-scheduler-17)', () {
    test('on a successful write while mounted: invalidate runs and true is '
        'returned', () async {
      var invalidateCalled = false;
      Object? reportedError;

      final result = await writeThenInvalidateGuarded(
        write: () async {},
        invalidate: () => invalidateCalled = true,
        isMounted: () => true,
        onError: (e, st) => reportedError = e,
      );

      expect(result, isTrue);
      expect(invalidateCalled, isTrue);
      expect(reportedError, isNull);
    });

    test(
      'AC2: on a successful write while NOT mounted, invalidate is never '
      'called (the widget may have been disposed by a fast navigation-away)',
      () async {
        var invalidateCalled = false;

        final result = await writeThenInvalidateGuarded(
          write: () async {},
          invalidate: () => invalidateCalled = true,
          isMounted: () => false,
          onError: (e, st) => fail('onError must not run for a good write'),
        );

        expect(result, isTrue, reason: 'the write itself still succeeded');
        expect(
          invalidateCalled,
          isFalse,
          reason:
              'AUD-scheduler-17 AC2: ref.invalidate(allDailyTasksProvider) '
              'must only run when the widget is still mounted.',
        );
      },
    );

    test('AC1: a thrown write error is routed to onError (not silently '
        'swallowed, not left to propagate as an unhandled Future error) and '
        'invalidate never runs', () async {
      var invalidateCalled = false;
      Object? reportedError;
      StackTrace? reportedStackTrace;
      final thrown = Exception('upsertDayConfig: disk error');

      // No throwsA/expectLater here on purpose: the whole point of the fix
      // is that the Future returned by writeThenInvalidateGuarded resolves
      // normally (onError already handled the failure) instead of
      // completing with an error the caller must catch.
      final result = await writeThenInvalidateGuarded(
        write: () => Future<void>.error(thrown),
        invalidate: () => invalidateCalled = true,
        isMounted: () => true,
        onError: (e, st) {
          reportedError = e;
          reportedStackTrace = st;
        },
      );

      expect(result, isFalse);
      expect(
        reportedError,
        same(thrown),
        reason:
            'AUD-scheduler-17 AC1: the write failure must reach onError '
            '(the screen logs it via AppLogger there) rather than vanish.',
      );
      expect(reportedStackTrace, isNotNull);
      expect(
        invalidateCalled,
        isFalse,
        reason: 'a failed write must never trigger a scheduler invalidation',
      );
    });
  });
}
