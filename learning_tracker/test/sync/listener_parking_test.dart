// The `_RecorderSource` test double owns a long-lived map of broadcast
// stream controllers that are cancel-and-recreated on each `openChannels()`
// call. The analyzer cannot see across that boundary, so close_sinks is
// suppressed file-wide.
// ignore_for_file: close_sinks

/// Phase 2 (sync-architecture-plan 2026-05-21) — listener parking.
///
/// After the app spends ≥ 60 s in `paused`/`hidden`/`detached`, the
/// LifecycleObserver detaches every Firestore real-time listener. On the
/// next resume, the supervisor unparks AFTER the pull-delta completes so
/// the local DB is current before the listener stream resumes.
///
/// Tests drive a configurable `parkAfterBackgroundDuration` (rather than
/// sleeping for 60 s) so the suite runs in <100 ms.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/lifecycle_observer.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';

class _RecorderSource implements ListenerSource {
  int openChannelsCallCount = 0;
  final Map<String, StreamController<Object?>> controllers = {};

  /// Stable count of "live" subscriptions = controllers with at least one
  /// listener.
  int get activeChannelCount =>
      controllers.values.where((c) => c.hasListener).length;

  @override
  Map<String, Stream<Object?>> openChannels() {
    openChannelsCallCount += 1;
    for (final c in controllers.values) {
      c.close();
    }
    controllers.clear();
    final streams = <String, Stream<Object?>>{};
    for (final name in ['completions', 'bookmarks']) {
      final c = StreamController<Object?>.broadcast();
      controllers[name] = c;
      streams[name] = c.stream;
    }
    return streams;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 — ListenerSupervisor.park / unpark', () {
    test(
      'park cancels every active subscription but remembers the live state',
      () async {
        final source = _RecorderSource();
        final supervisor = ListenerSupervisor(
          source: source,
          onEvent: (_, _) {},
        );

        await supervisor.start();
        expect(supervisor.isAttached, isTrue);
        expect(supervisor.isParked, isFalse);
        expect(source.activeChannelCount, 2);

        await supervisor.park();

        expect(supervisor.isAttached, isFalse);
        expect(supervisor.isParked, isTrue);
        expect(
          source.activeChannelCount,
          0,
          reason: 'park must cancel every gRPC subscription',
        );
      },
    );

    test('unpark re-opens channels and clears the parked flag', () async {
      final source = _RecorderSource();
      final supervisor = ListenerSupervisor(source: source, onEvent: (_, _) {});

      await supervisor.start();
      await supervisor.park();
      expect(supervisor.isParked, isTrue);
      expect(source.activeChannelCount, 0);

      await supervisor.unpark();

      expect(supervisor.isAttached, isTrue);
      expect(supervisor.isParked, isFalse);
      expect(
        source.activeChannelCount,
        2,
        reason: 'unpark must reopen every channel cancelled by park',
      );
    });

    test('unpark is a no-op when the supervisor was stopped (not parked) — '
        'callers use start() for a clean fresh start', () async {
      final source = _RecorderSource();
      final supervisor = ListenerSupervisor(source: source, onEvent: (_, _) {});

      await supervisor.start();
      await supervisor.stop();
      expect(supervisor.isParked, isFalse);

      await supervisor.unpark();
      expect(supervisor.isAttached, isFalse);
      expect(source.activeChannelCount, 0);
    });

    test(
      'park is idempotent — calling twice does not re-cancel subscriptions',
      () async {
        final source = _RecorderSource();
        final supervisor = ListenerSupervisor(
          source: source,
          onEvent: (_, _) {},
        );

        await supervisor.start();
        await supervisor.park();
        await supervisor.park();
        expect(supervisor.isParked, isTrue);
        expect(source.activeChannelCount, 0);
      },
    );
  });

  group('Phase 2 — LifecycleObserver background-park timer', () {
    test(
      'paused → ≥ window → parkListeners fires (no resume in between)',
      () async {
        final calls = <String>[];
        // Use a tiny window so the test runs instantly. Production default
        // is 60 s; the timer plumbing is the same.
        final observer = LifecycleObserver(
          redetectTimezone: () async => calls.add('tz'),
          invalidateSacredCache: () async => calls.add('cache'),
          triggerPull: () async => calls.add('pull'),
          parkListeners: () async => calls.add('park'),
          unparkListeners: () async => calls.add('unpark'),
          parkAfterBackgroundDuration: const Duration(milliseconds: 50),
        );

        observer.start();
        addTearDown(observer.stop);

        // Cold-start resume — no work since we never backgrounded.
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        calls.clear();

        // Go to background and wait past the park window without resuming.
        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(
          calls,
          equals(['park']),
          reason:
              'after 60 s in background, parkListeners must fire exactly once',
        );
      },
    );

    test(
      'paused → resumed inside the window cancels the park timer (no park)',
      () async {
        final calls = <String>[];
        final observer = LifecycleObserver(
          redetectTimezone: () async => calls.add('tz'),
          invalidateSacredCache: () async => calls.add('cache'),
          triggerPull: () async => calls.add('pull'),
          parkListeners: () async => calls.add('park'),
          unparkListeners: () async => calls.add('unpark'),
          parkAfterBackgroundDuration: const Duration(milliseconds: 100),
        );

        observer.start();
        addTearDown(observer.stop);

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        calls.clear();

        // Brief background — return to foreground BEFORE the park window
        // elapses.
        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        // Wait past the (cancelled) window to confirm park does NOT fire.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(
          calls,
          isNot(contains('park')),
          reason: 'a resume inside the park window must cancel the timer',
        );
        // Brief background did not park, so unpark must not fire either.
        expect(calls, isNot(contains('unpark')));
      },
    );

    test(
      'resume after park: unpark fires AFTER triggerPull completes',
      () async {
        final calls = <String>[];
        final observer = LifecycleObserver(
          redetectTimezone: () async => calls.add('tz'),
          invalidateSacredCache: () async => calls.add('cache'),
          triggerPull: () async {
            // Slight delay so the ordering assertion has bite — if unpark
            // were to fire before triggerPull awaited, we'd see 'unpark'
            // before 'pull' in the recorded sequence.
            await Future<void>.delayed(const Duration(milliseconds: 5));
            calls.add('pull');
          },
          parkListeners: () async => calls.add('park'),
          unparkListeners: () async => calls.add('unpark'),
          parkAfterBackgroundDuration: const Duration(milliseconds: 30),
        );

        observer.start();
        addTearDown(observer.stop);

        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
        calls.clear();

        // Background — wait for park to fire.
        await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(calls, equals(['park']));
        calls.clear();

        // Resume — the observer runs tz, cache, pull and then (because the
        // observer parked) unpark.
        await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

        // Verify unpark followed pull (pull happens before unpark).
        final pullIdx = calls.indexOf('pull');
        final unparkIdx = calls.indexOf('unpark');
        expect(
          pullIdx,
          greaterThanOrEqualTo(0),
          reason: 'triggerPull must run on resume',
        );
        expect(
          unparkIdx,
          greaterThan(pullIdx),
          reason:
              'unpark must follow the pull-delta — the local DB must be '
              'current before the listener stream resumes.',
        );
      },
    );

    test('a series of non-resumed states (paused → hidden → detached) does NOT '
        'restart the timer — the 60 s window is measured from the FIRST '
        'non-resumed event', () async {
      var parkCalls = 0;
      final observer = LifecycleObserver(
        redetectTimezone: () async {},
        invalidateSacredCache: () async {},
        triggerPull: () async {},
        parkListeners: () async => parkCalls += 1,
        unparkListeners: () async {},
        parkAfterBackgroundDuration: const Duration(milliseconds: 50),
      );

      observer.start();
      addTearDown(observer.stop);

      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Burst of non-resumed states near each other.
      await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await observer.didChangeAppLifecycleState(AppLifecycleState.detached);

      // Wait past the (single) park window from the first paused event.
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        parkCalls,
        1,
        reason:
            'park must fire exactly once per background spell — secondary '
            'non-resumed states must not restart the timer.',
      );
    });
  });
}
