/// Tests for [LifecycleObserver]'s resume-time hook orchestration, including
/// the Firestore-network self-heal that fires only on a real foreground
/// return (not on a cold-start `resumed`).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/lifecycle_observer.dart';

class _HookLog {
  final List<String> calls = [];
  LifecycleHook record(String name) => () async {
    calls.add(name);
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LifecycleObserver — resume hook ordering', () {
    test('cold-start resume does NOT reset Firestore', () async {
      final log = _HookLog();
      final observer = LifecycleObserver(
        resetFirestoreNetwork: log.record('reset'),
        redetectTimezone: log.record('tz'),
        invalidateSacredCache: log.record('cache'),
        triggerPull: log.record('pull'),
      );

      // Process start → first event is `resumed` (cold start). The observer
      // hasn't seen a non-resumed state, so the Firestore reset must NOT fire.
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(
        log.calls,
        equals(['tz', 'cache', 'pull']),
        reason: 'cold-start resume must skip the Firestore network reset',
      );
    });

    test(
      'resume after a paused state DOES reset Firestore, before the pull',
      () async {
        final log = _HookLog();
        final observer = LifecycleObserver(
          resetFirestoreNetwork: log.record('reset'),
          redetectTimezone: log.record('tz'),
          invalidateSacredCache: log.record('cache'),
          triggerPull: log.record('pull'),
        );

        // Cold-start resume — no reset (covered by the previous test).
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        log.calls.clear();

        // App backgrounds, then returns to foreground.
        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(
          log.calls,
          equals(['reset', 'tz', 'cache', 'pull']),
          reason:
              'a resume that follows a non-resumed state must reset the '
              'Firestore channel before the pull pipeline runs',
        );
      },
    );

    test(
      'inactive → resumed counts as a real foreground return (resets Firestore)',
      () async {
        final log = _HookLog();
        final observer = LifecycleObserver(
          resetFirestoreNetwork: log.record('reset'),
          redetectTimezone: log.record('tz'),
          invalidateSacredCache: log.record('cache'),
          triggerPull: log.record('pull'),
        );

        // First resume — no reset.
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        log.calls.clear();

        // A phone call / system overlay puts the app into `inactive`,
        // then it returns to foreground.
        await observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(log.calls.first, equals('reset'));
      },
    );

    test(
      'back-to-back resumes only reset on the first after backgrounding',
      () async {
        final log = _HookLog();
        final observer = LifecycleObserver(
          resetFirestoreNetwork: log.record('reset'),
          redetectTimezone: log.record('tz'),
          invalidateSacredCache: log.record('cache'),
          triggerPull: log.record('pull'),
        );

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        log.calls.clear();

        // A spurious second resumed event (no intervening pause) must NOT
        // reset Firestore again — the backgrounded flag was cleared by the
        // first post-pause resume.
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(log.calls, equals(['tz', 'cache', 'pull']));
      },
    );

    test('resetFirestoreNetwork hook is optional', () async {
      final log = _HookLog();
      final observer = LifecycleObserver(
        // resetFirestoreNetwork omitted on purpose.
        redetectTimezone: log.record('tz'),
        invalidateSacredCache: log.record('cache'),
        triggerPull: log.record('pull'),
      );

      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // The two resumes run the three required hooks each, no reset hook.
      expect(log.calls, equals(['tz', 'cache', 'pull', 'tz', 'cache', 'pull']));
    });

    test('hidden and detached states also flag as backgrounded', () async {
      final log = _HookLog();
      final observer = LifecycleObserver(
        resetFirestoreNetwork: log.record('reset'),
        redetectTimezone: log.record('tz'),
        invalidateSacredCache: log.record('cache'),
        triggerPull: log.record('pull'),
      );

      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      log.calls.clear();

      // `hidden` (Flutter 3.13+) is the cross-platform "not visible" state.
      await observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(log.calls.first, equals('reset'));
      log.calls.clear();

      // `detached` — the engine is running with no view attached (e.g. the
      // last Android Activity was destroyed but the process survives).
      await observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(log.calls.first, equals('reset'));
    });
  });
}
