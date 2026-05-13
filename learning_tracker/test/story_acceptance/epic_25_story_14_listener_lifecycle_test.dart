// The `_FakeListenerSource` test double owns a long-lived map of broadcast
// stream controllers that are cancel-and-recreated on each `openChannels()`
// call (mirroring the real Firestore re-listen contract). The analyzer
// cannot see across the recreate boundary so `close_sinks` is suppressed.
// ignore_for_file: close_sinks

/// Story acceptance tests for Epic 25 — Story 25.14 (DNI-335):
/// SyncEngine decomposition Part 3 — ListenerSupervisor + LifecycleObserver.
///
/// Validates:
///   AC1 — `ListenerSupervisor` owns the listener subscriptions and exposes
///         `start()` / `stop()` / `restart()` (NFR20: lifecycle is testable
///         in isolation, not coupled to sync_engine.dart).
///   AC2 — `LifecycleObserver` registers as a `WidgetsBindingObserver` and,
///         on `AppLifecycleState.resumed`, calls each injected hook exactly
///         once: timezone re-detect, sacred-window cache invalidate
///         (no-op stub until DNI-26.24), and pull-latest.
///   AC3 — Driving `resumed` through the WidgetsBinding test harness fires
///         the observer's hooks (state reset assertion).
///   AC4 — `ListenerSupervisor.restart()` reattaches without duplicate
///         firing: a single payload from each upstream listener still
///         produces exactly one delivery to the sink.
@Tags(['epic_25'])
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:learning_tracker/core/sync/lifecycle_observer.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';
import 'package:test/test.dart';

void main() {
  // Initialise the Flutter binding once so LifecycleObserver can register
  // against `WidgetsBinding.instance` from a plain `package:test` runner.
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Story 25.14 — ListenerSupervisor + LifecycleObserver',
    tags: ['story_25_14'],
    () {
      // ── AC1 — ListenerSupervisor owns subscriptions ───────────────────────

      group('ListenerSupervisor', () {
        test(
          'start() subscribes to every listener exposed by the source',
          () async {
            final source = _FakeListenerSource(['completions', 'bookmarks']);
            final delivered = <String>[];
            final supervisor = ListenerSupervisor(
              source: source,
              onEvent: (channel, payload) => delivered.add('$channel:$payload'),
            );

            await supervisor.start();

            expect(
              source.activeChannelCount,
              2,
              reason: 'one subscription per channel',
            );

            source.emit('completions', 'c1');
            source.emit('bookmarks', 'b1');
            await Future<void>.delayed(Duration.zero);
            expect(delivered, ['completions:c1', 'bookmarks:b1']);

            await supervisor.stop();
          },
        );

        test(
          'start() called twice without an intervening stop is idempotent',
          () async {
            final source = _FakeListenerSource(['completions']);
            final supervisor = ListenerSupervisor(
              source: source,
              onEvent: (_, _) {},
            );

            await supervisor.start();
            await supervisor.start();

            expect(
              source.activeChannelCount,
              1,
              reason:
                  'duplicate start() must not double-subscribe; the second '
                  'call should be a no-op while listeners are already attached',
            );

            await supervisor.stop();
          },
        );

        test('stop() cancels every subscription', () async {
          final source = _FakeListenerSource(['completions', 'bookmarks']);
          final delivered = <String>[];
          final supervisor = ListenerSupervisor(
            source: source,
            onEvent: (channel, payload) => delivered.add('$channel:$payload'),
          );

          await supervisor.start();
          await supervisor.stop();

          expect(source.activeChannelCount, 0);

          // Emits after stop must not arrive at the sink.
          source.emit('completions', 'late');
          await Future<void>.delayed(Duration.zero);
          expect(delivered, isEmpty);
        });

        test(
          'onError is invoked when an upstream listener emits an error',
          () async {
            final source = _FakeListenerSource(['completions']);
            final errors = <Object>[];
            final supervisor = ListenerSupervisor(
              source: source,
              onEvent: (_, _) {},
              onError: (channel, error, _) => errors.add('$channel:$error'),
            );

            await supervisor.start();
            source.emitError('completions', StateError('boom'));
            await Future<void>.delayed(Duration.zero);

            expect(errors, hasLength(1));
            expect(errors.single, startsWith('completions:'));

            await supervisor.stop();
          },
        );
      });

      // ── AC4 — restart() reattaches without duplicate firing ───────────────

      group('ListenerSupervisor.restart()', () {
        test('after restart, each upstream emit produces exactly one delivery '
            '(no duplicate firing)', () async {
          final source = _FakeListenerSource([
            'completions',
            'bookmarks',
            'settings',
          ]);
          final delivered = <String>[];
          final supervisor = ListenerSupervisor(
            source: source,
            onEvent: (channel, payload) => delivered.add('$channel:$payload'),
          );

          await supervisor.start();
          await supervisor.restart();

          expect(
            source.activeChannelCount,
            3,
            reason:
                'restart must hold listener count steady — old '
                'subscriptions cancelled before new ones attach',
          );

          source.emit('completions', 'c1');
          source.emit('bookmarks', 'b1');
          source.emit('settings', 's1');
          await Future<void>.delayed(Duration.zero);

          // The critical assertion: one upstream event => one delivery.
          // Pre-DNI-335 sync_engine.attachListeners could double-subscribe
          // because the `_listenersAttached` flag was reset by external
          // callers (e.g. `_onReconnect`) without first cancelling old
          // subscriptions, producing duplicate merges.
          expect(delivered, ['completions:c1', 'bookmarks:b1', 'settings:s1']);

          await supervisor.stop();
        });
      });

      // ── AC2 + AC3 — LifecycleObserver behaviour ───────────────────────────

      group('LifecycleObserver', () {
        test('start() registers with WidgetsBinding; stop() unregisters', () {
          final observer = LifecycleObserver(
            redetectTimezone: () async {},
            invalidateSacredCache: () async {},
            triggerPull: () async {},
          );

          // Snapshot the WidgetsBindingObserver list indirectly: registering
          // and then dispatching an AppLifecycleState change is the only
          // public observable. After stop(), the dispatch must not call our
          // hooks anymore.
          observer.start();
          observer.stop();
          // No exception means the observer was registered and unregistered
          // without throwing — explicit positive proof comes from the
          // resumed-dispatch test below.
        });

        test('on AppLifecycleState.resumed, every injected hook fires exactly '
            'once and in order: timezone, sacredCache, pull', () async {
          final calls = <String>[];
          final observer = LifecycleObserver(
            redetectTimezone: () async => calls.add('timezone'),
            invalidateSacredCache: () async => calls.add('sacredCache'),
            triggerPull: () async => calls.add('pull'),
          );

          observer.start();
          try {
            await observer.didChangeAppLifecycleState(
              AppLifecycleState.resumed,
            );
            expect(calls, ['timezone', 'sacredCache', 'pull']);
          } finally {
            observer.stop();
          }
        });

        test(
          'lifecycle states other than resumed do not fire the resume hooks',
          () async {
            final calls = <String>[];
            final observer = LifecycleObserver(
              redetectTimezone: () async => calls.add('timezone'),
              invalidateSacredCache: () async => calls.add('sacredCache'),
              triggerPull: () async => calls.add('pull'),
            );

            observer.start();
            try {
              await observer.didChangeAppLifecycleState(
                AppLifecycleState.paused,
              );
              await observer.didChangeAppLifecycleState(
                AppLifecycleState.inactive,
              );
              await observer.didChangeAppLifecycleState(
                AppLifecycleState.detached,
              );
              await observer.didChangeAppLifecycleState(
                AppLifecycleState.hidden,
              );
              expect(calls, isEmpty);
            } finally {
              observer.stop();
            }
          },
        );

        test(
          'driving resumed through the real WidgetsBinding harness still '
          'fires the hooks (AC3 — the binding is wired, not just the method)',
          () async {
            final calls = <String>[];
            final observer = LifecycleObserver(
              redetectTimezone: () async => calls.add('timezone'),
              invalidateSacredCache: () async => calls.add('sacredCache'),
              triggerPull: () async => calls.add('pull'),
            );

            observer.start();
            try {
              // Push a lifecycle change through the binding's normal
              // notification path so we exercise the addObserver hookup.
              WidgetsBinding.instance.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
              // Hooks are async; pump a single microtask to drain them.
              await Future<void>.delayed(Duration.zero);

              expect(
                calls,
                ['timezone', 'sacredCache', 'pull'],
                reason:
                    'LifecycleObserver must be registered as a real '
                    'WidgetsBindingObserver — driving the binding alone '
                    'should be enough to invoke the hooks',
              );
            } finally {
              observer.stop();
            }
          },
        );

        test('stop() removes the observer — subsequent binding events are '
            'silent', () async {
          final calls = <String>[];
          final observer = LifecycleObserver(
            redetectTimezone: () async => calls.add('timezone'),
            invalidateSacredCache: () async => calls.add('sacredCache'),
            triggerPull: () async => calls.add('pull'),
          );

          observer.start();
          observer.stop();

          WidgetsBinding.instance.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await Future<void>.delayed(Duration.zero);

          expect(calls, isEmpty);
        });
      });
    },
  );
}

// ─── Test doubles ────────────────────────────────────────────────────────────

/// A `ListenerSource` that hands out broadcast streams per channel and
/// records how many active subscriptions exist on each underlying
/// controller — used to detect duplicate subscription via `restart()`.
///
/// Controllers are deliberately long-lived for the duration of a test (each
/// `openChannels()` call closes the previous batch) — the `close_sinks` lint
/// is suppressed at the field level because the analyzer cannot see across
/// the cancel-and-recreate boundary.
class _FakeListenerSource implements ListenerSource {
  _FakeListenerSource(this._channels);

  final List<String> _channels;
  final Map<String, StreamController<Object?>> _controllers = {};

  int get activeChannelCount =>
      _controllers.values.where((c) => c.hasListener).length;

  void emit(String channel, Object? payload) {
    final c = _controllers[channel];
    if (c == null) {
      fail('emit($channel) before openChannels()');
    }
    c.add(payload);
  }

  void emitError(String channel, Object error) {
    final c = _controllers[channel];
    if (c == null) {
      fail('emitError($channel) before openChannels()');
    }
    c.addError(error);
  }

  @override
  Map<String, Stream<Object?>> openChannels() {
    // Cancel + recreate controllers each time, so a `restart()` produces
    // brand-new streams (matching the real Firestore re-listen contract).
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    final streams = <String, Stream<Object?>>{};
    for (final name in _channels) {
      final c = StreamController<Object?>.broadcast();
      _controllers[name] = c;
      streams[name] = c.stream;
    }
    return streams;
  }
}
