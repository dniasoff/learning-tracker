/// Tests for [LifecycleObserver]'s resume-time hook orchestration, including
/// the Firestore-network self-heal that fires only on a real foreground
/// return (not on a cold-start `resumed`), gated to a genuine
/// network-identity change and debounced (Story 1.3 / FR18 / AD-9 / E-5), and
/// the dead-channel resubscribe hook (Story 1.3 / FR15 / AD-9).
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

    test('resume after a paused state DOES reset Firestore, before the pull '
        '(no identity probe wired — always treated as a change)', () async {
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
    });

    test(
      // Story 1.3 red-demo (b): pre-fix, ANY non-resumed state (including a
      // transient `inactive` blip — notification shade, permission dialog)
      // armed the Firestore reset. Post-fix, only `paused`/`hidden` do —
      // `inactive` must never trigger a full network reset (AC2 / E-5).
      'inactive → resumed does NOT reset Firestore — it is a transient blip, '
      'not a real background (Story 1.3 AC2 red-demo)',
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
        // then it returns to foreground. This must NOT reset Firestore.
        await observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(
          log.calls,
          equals(['tz', 'cache', 'pull']),
          reason:
              'an inactive-only blip must never arm the Firestore network '
              'reset — only paused/hidden do (Story 1.3 AC2)',
        );
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

    test('hidden flags as backgrounded and resets Firestore; detached does NOT '
        '(Story 1.3 AC2 — only paused/hidden are eligible)', () async {
      final log = _HookLog();
      final observer = LifecycleObserver(
        resetFirestoreNetwork: log.record('reset'),
        redetectTimezone: log.record('tz'),
        invalidateSacredCache: log.record('cache'),
        triggerPull: log.record('pull'),
      );

      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      log.calls.clear();

      // `hidden` (Flutter 3.13+) is the cross-platform "not visible" state
      // — still eligible for the reset.
      await observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(log.calls, equals(['reset', 'tz', 'cache', 'pull']));
      log.calls.clear();

      // `detached` — the engine is running with no view attached. Per the
      // binding AC2 text ("restricted to the paused/hidden states"),
      // detached is NOT reset-eligible.
      await observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(log.calls, equals(['tz', 'cache', 'pull']));
    });
  });

  group('LifecycleObserver — network-identity gating (Story 1.3 AC2)', () {
    test(
      'resume with an UNCHANGED network identity does NOT reset Firestore',
      () async {
        final log = _HookLog();
        final observer = LifecycleObserver(
          resetFirestoreNetwork: log.record('reset'),
          redetectTimezone: log.record('tz'),
          invalidateSacredCache: log.record('cache'),
          triggerPull: log.record('pull'),
          resolveNetworkIdentity: () async => 'wifi',
        );

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        log.calls.clear();

        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(
          log.calls,
          equals(['tz', 'cache', 'pull']),
          reason:
              'the identity probe returned "wifi" both times — a trivial '
              'app-switch with no real network change must not reset',
        );
      },
    );

    test(
      'resume with a CHANGED network identity fires exactly one reset',
      () async {
        final log = _HookLog();
        var identity = 'wifi';
        final observer = LifecycleObserver(
          resetFirestoreNetwork: log.record('reset'),
          redetectTimezone: log.record('tz'),
          invalidateSacredCache: log.record('cache'),
          triggerPull: log.record('pull'),
          resolveNetworkIdentity: () async => identity,
        );

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        log.calls.clear();

        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        // Network handed off from WiFi to cellular while backgrounded.
        identity = 'cellular';
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(
          log.calls,
          equals(['reset', 'tz', 'cache', 'pull']),
          reason: 'a genuine network-identity change must still fire a reset',
        );
      },
    );

    test('a burst of resumes with a genuine identity change debounces to '
        'exactly one reset', () async {
      final log = _HookLog();
      var identity = 'wifi';
      final observer = LifecycleObserver(
        resetFirestoreNetwork: log.record('reset'),
        redetectTimezone: log.record('tz'),
        invalidateSacredCache: log.record('cache'),
        triggerPull: log.record('pull'),
        resolveNetworkIdentity: () async => identity,
        resumeResetDebounce: const Duration(seconds: 10),
      );

      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      log.calls.clear();

      // First flap: identity changes, reset fires.
      await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      identity = 'cellular';
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(log.calls.where((c) => c == 'reset').length, 1);

      // Rapid second flap inside the debounce window: identity changes
      // AGAIN, but the debounce must suppress a second reset.
      await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      identity = 'wifi';
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(
        log.calls.where((c) => c == 'reset').length,
        1,
        reason:
            'rapid flapping must coalesce to exactly one reset inside the '
            'debounce window (no thundering herd)',
      );
    });
  });

  group(
    'LifecycleObserver — resubscribeDeadChannels hook (Story 1.3 FR15/AD-9)',
    () {
      test('cold-start resume does NOT resubscribe dead channels', () async {
        final log = _HookLog();
        final observer = LifecycleObserver(
          redetectTimezone: log.record('tz'),
          invalidateSacredCache: log.record('cache'),
          triggerPull: log.record('pull'),
          resubscribeDeadChannels: log.record('resubscribe'),
        );

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(log.calls, equals(['tz', 'cache', 'pull']));
      });

      test(
        'resume after an inactive-only blip STILL resubscribes dead '
        'channels — cheap and independent of the network-reset gate',
        () async {
          final log = _HookLog();
          final observer = LifecycleObserver(
            redetectTimezone: log.record('tz'),
            invalidateSacredCache: log.record('cache'),
            triggerPull: log.record('pull'),
            resubscribeDeadChannels: log.record('resubscribe'),
          );

          await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
          log.calls.clear();

          await observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
          await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

          expect(
            log.calls,
            equals(['tz', 'cache', 'pull', 'resubscribe']),
            reason:
                'resubscribing dead channels is cheap/no-op-safe and should '
                'run on every genuine resume, even a trivial inactive blip',
          );
        },
      );

      test('resubscribeDeadChannels runs AFTER unparkListeners on a resume '
          'that actually parked', () async {
        final log = _HookLog();
        final observer = LifecycleObserver(
          redetectTimezone: log.record('tz'),
          invalidateSacredCache: log.record('cache'),
          triggerPull: log.record('pull'),
          parkListeners: log.record('park'),
          unparkListeners: log.record('unpark'),
          resubscribeDeadChannels: log.record('resubscribe'),
          parkAfterBackgroundDuration: const Duration(milliseconds: 20),
        );

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        log.calls.clear();

        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(log.calls, equals(['park']));
        log.calls.clear();

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(
          log.calls,
          equals(['tz', 'cache', 'pull', 'unpark', 'resubscribe']),
        );
      });
    },
  );
}
