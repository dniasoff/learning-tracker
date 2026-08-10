// The `_ControllerSource` test double owns a long-lived map of broadcast
// stream controllers that are cancel-and-recreated on each `openChannels()`
// call. The analyzer cannot see across that boundary, so close_sinks is
// suppressed file-wide (matches epic_25_story_14_listener_lifecycle_test).
// ignore_for_file: close_sinks

/// Phase 2 (sync-architecture-plan 2026-05-21) — listener overflow recovery.
///
/// When a snapshot returns exactly `limit` docs the listener has saturated
/// its page-size window — there may be older docs the listener cannot see.
/// The supervisor must trigger a collection-scoped recovery pull (NOT a
/// full re-pull of every kind) and throttle to at most one invocation per
/// minute per channel.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';

import '../helpers/fake_clock.dart';

/// A listener source whose channels are backed by user-driven controllers.
class _ControllerSource implements ListenerSource {
  _ControllerSource(this.channelNames);

  final List<String> channelNames;
  final Map<String, StreamController<Object?>> controllers = {};

  void emit(String channel, Object? payload) =>
      controllers[channel]!.add(payload);

  @override
  Map<String, Stream<Object?>> openChannels() {
    for (final c in controllers.values) {
      c.close();
    }
    controllers.clear();
    final streams = <String, Stream<Object?>>{};
    for (final name in channelNames) {
      final c = StreamController<Object?>.broadcast();
      controllers[name] = c;
      streams[name] = c.stream;
    }
    return streams;
  }
}

void main() {
  group('Phase 2 — recovery pull on listener overflow', () {
    test(
      'an at-limit snapshot triggers the matching collection recovery pull',
      () async {
        final source = _ControllerSource(['goals', 'bookmarks']);
        var goalsPulls = 0;
        var bookmarksPulls = 0;
        final supervisor = ListenerSupervisor(
          source: source,
          onEvent: (_, _) {},
          recoveryPullTriggers: {
            'goals': () async {
              goalsPulls += 1;
            },
            'bookmarks': () async {
              bookmarksPulls += 1;
            },
          },
        );

        await supervisor.start();
        addTearDown(supervisor.stop);

        // Snapshot below the limit — no recovery pull.
        source.emit(
          'goals',
          const ListenerSnapshot(rows: [], isAtLimit: false),
        );
        await Future<void>.delayed(Duration.zero);
        expect(goalsPulls, 0);
        expect(bookmarksPulls, 0);

        // Snapshot at the limit — recovery pull fires for goals ONLY.
        source.emit('goals', const ListenerSnapshot(rows: [], isAtLimit: true));
        await Future<void>.delayed(Duration.zero);
        expect(goalsPulls, 1);
        expect(
          bookmarksPulls,
          0,
          reason:
              'overflow on goals must NOT trigger a full re-pull of '
              'every kind — bookmarks must remain untouched.',
        );
      },
    );

    test('a second at-limit snapshot within 60 s does NOT retrigger the pull '
        '(per-channel throttle), and one past the 60 s window DOES', () async {
      // AUD-t-cross-101: drive the throttle boundary through the
      // injectable LocalDayClock seam instead of real elapsed time, so
      // both sides of the 60 s window are provable by construction.
      final clock = installFakeClock(DateTime.utc(2026, 1, 1));

      final source = _ControllerSource(['completions']);
      var pullCount = 0;
      final supervisor = ListenerSupervisor(
        source: source,
        onEvent: (_, _) {},
        recoveryPullTriggers: {
          'completions': () async {
            pullCount += 1;
          },
        },
      );

      await supervisor.start();
      addTearDown(supervisor.stop);

      source.emit(
        'completions',
        const ListenerSnapshot(rows: [], isAtLimit: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(pullCount, 1);

      // Advance the fake clock but stay INSIDE the 60 s throttle window —
      // a burst of at-limit snapshots here must be coalesced.
      clock.advance(const Duration(seconds: 30));
      source.emit(
        'completions',
        const ListenerSnapshot(rows: [], isAtLimit: true),
      );
      await Future<void>.delayed(Duration.zero);
      clock.advance(const Duration(seconds: 29));
      source.emit(
        'completions',
        const ListenerSnapshot(rows: [], isAtLimit: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        pullCount,
        1,
        reason:
            'recovery-pull is throttled to one invocation per minute per '
            'channel — a burst of at-limit snapshots inside the window '
            'must not loop the pull pipeline.',
      );

      // Advance the fake clock PAST the 60 s throttle window (59 s + 2 s
      // = 61 s elapsed since the first pull) — the next at-limit
      // snapshot must retrigger the recovery pull. This is the side of
      // the boundary the original wall-clock-only test could never
      // exercise deterministically.
      clock.advance(const Duration(seconds: 2));
      source.emit(
        'completions',
        const ListenerSnapshot(rows: [], isAtLimit: true),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        pullCount,
        2,
        reason:
            'once the throttle window has elapsed, the next at-limit '
            'snapshot must retrigger the recovery pull — the throttle '
            'coalesces bursts, it does not permanently suppress '
            'recovery.',
      );
    });

    test('recovery-pull trigger is keyed by channel — an at-limit snapshot on '
        'an unwired channel is silently ignored (no trigger map entry, no '
        'crash)', () async {
      final source = _ControllerSource(['tutor_grants']);
      // No trigger for tutor_grants — that channel has no PullPipeline
      // method (server-driven tutor flow).
      final supervisor = ListenerSupervisor(
        source: source,
        onEvent: (_, _) {},
        // ignore: prefer_const_literals_to_create_immutables
        recoveryPullTriggers: const {},
      );

      await supervisor.start();
      addTearDown(supervisor.stop);

      // Must not throw.
      source.emit(
        'tutor_grants',
        const ListenerSnapshot(rows: [], isAtLimit: true),
      );
      await Future<void>.delayed(Duration.zero);
    });

    test('rows from an at-limit snapshot are still forwarded to the event '
        'handler (the recovery-pull is additive, not a replacement)', () async {
      final source = _ControllerSource(['goals']);
      final delivered = <int>[];
      final supervisor = ListenerSupervisor(
        source: source,
        onEvent: (channel, payload) {
          if (payload is List) {
            delivered.add(payload.length);
          }
        },
        recoveryPullTriggers: {'goals': () async {}},
      );

      await supervisor.start();
      addTearDown(supervisor.stop);

      source.emit(
        'goals',
        const ListenerSnapshot(
          rows: [
            {'id': '1'},
            {'id': '2'},
            {'id': '3'},
          ],
          isAtLimit: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        delivered,
        equals([3]),
        reason:
            'the rows the listener DID deliver must still be merged — '
            'recovery pull only covers the older docs the window missed.',
      );
    });

    test(
      'snapshot-size telemetry fires for the first 10 snapshots, then stops',
      () async {
        final source = _ControllerSource(['bookmarks']);
        final telemetry = <({String channel, int size, bool isAtLimit})>[];
        final supervisor = ListenerSupervisor(
          source: source,
          onEvent: (_, _) {},
          snapshotTelemetry: (channel, size, isAtLimit) {
            telemetry.add((channel: channel, size: size, isAtLimit: isAtLimit));
          },
        );

        await supervisor.start();
        addTearDown(supervisor.stop);

        for (var i = 0; i < ListenerSupervisor.maxTelemetrySnapshots + 5; i++) {
          source.emit(
            'bookmarks',
            ListenerSnapshot(
              rows: [
                {'id': '$i'},
              ],
              isAtLimit: false,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        }

        expect(
          telemetry,
          hasLength(ListenerSupervisor.maxTelemetrySnapshots),
          reason:
              'telemetry must fire for the first 10 snapshots only; '
              'further snapshots must be silent to avoid log spam.',
        );
      },
    );
  });
}
