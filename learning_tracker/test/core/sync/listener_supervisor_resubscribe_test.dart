// The `_RecorderSource` test double models the REAL `FirestoreListenerSource`
// contract precisely: every `openChannels()` call returns a brand-new
// generation of streams, and — unlike the simpler cancel-and-recreate doubles
// used by the park/overflow tests — an OLDER generation's controllers are
// NEVER closed just because a newer generation was requested. This matters
// here specifically: Story 1.1's per-channel resubscribe calls
// `openChannels()` again to fetch just the one dead channel's fresh stream,
// and a sibling channel's ORIGINAL subscription (from an earlier generation)
// must keep working untouched — exactly what a real Firestore `.snapshots()`
// stream does (a fresh `.snapshots()` call never affects an already-open one).
// The analyzer cannot see that every controller is retained and eventually
// released as a whole, so close_sinks is suppressed file-wide.
// ignore_for_file: close_sinks

/// Story 1.1 (epics-firestore-migration-phase0.md) — own-account listeners
/// resubscribe on error with bounded backoff.
///
/// AD-9 / R-1: a Firestore `.snapshots()` stream is terminal on error. Before
/// this story, `ListenerSupervisor`'s `onError` only forwarded to the
/// caller's error callback and left `_attached == true` — the channel stayed
/// dark for the rest of the session (the "#1 fickle" mechanism per the
/// 2026-07-29 sync-reliability review).
///
/// Covers:
///   * the mandatory red-demo — a live channel forced into `onError`, then a
///     new server snapshot pushed, must be delivered (this is the exact
///     scenario that failed before the fix: manually verified by reverting
///     the `listener_supervisor.dart` changes and re-running this test — see
///     the test's own doc comment for the recorded before/after result);
///   * sibling channels are never disturbed by one channel's failure;
///   * bounded-exponential-backoff growth and the retry-forever-at-the-cap
///     rule (no resting "exhausted" state);
///   * jitter stays within the configured band;
///   * the double-attach guard — a pending per-channel resubscribe racing a
///     concurrent `restart()`/`unpark()`, or a second error on the same
///     channel, never produces two live subscriptions / a doubled delivery;
///   * a channel that errors while parked does not resubscribe until unpark;
///   * the `deadChannels` / `deadChannelsChanges` signal Story 1.5 will read.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';

/// A listener source whose `openChannels()` call always returns a brand-new,
/// never-closed generation of broadcast controllers — see the file doc
/// comment for why this (rather than the simpler cancel-and-recreate double
/// used elsewhere) is the right model for these tests.
class _RecorderSource implements ListenerSource {
  _RecorderSource(this.channelNames);

  final List<String> channelNames;

  /// Every generation of controllers ever handed out, oldest first.
  final List<Map<String, StreamController<Object?>>> generations = [];

  int get openChannelsCallCount => generations.length;

  /// The controller backing the most recently *created* stream for
  /// [channel] — i.e. the one the supervisor's latest resubscribe attempt
  /// (or the original `start()`) was handed.
  StreamController<Object?> latest(String channel) =>
      generations.last[channel]!;

  /// The controller from generation [index] (0 == the very first
  /// `openChannels()` call) — used to prove an OLDER subscription is still
  /// the live one when a sibling channel is resubscribed.
  StreamController<Object?> generation(int index, String channel) =>
      generations[index][channel]!;

  /// Deliver a terminal error on [channel]'s CURRENT stream, then close it.
  ///
  /// This is the whole ballgame for a faithful red-demo: a real Firestore
  /// `.snapshots()` stream is terminal on error (AD-9) — after `onError`
  /// fires, that stream will never emit again. A plain
  /// `StreamController.broadcast()` does **not** do this on its own;
  /// `addError()` alone leaves the controller open and perfectly willing to
  /// deliver further `add()` calls to the SAME (pre-fix, un-resubscribed)
  /// listener, which would make the red-demo pass vacuously even without the
  /// Story 1.1 fix. Closing the controller after the error is what makes
  /// "nothing more can ever be delivered on this stream" true, so a passing
  /// test can only mean the supervisor actually opened a NEW subscription
  /// (via a fresh `openChannels()` call) — the real fix.
  void errorAndTerminate(String channel, Object error) {
    final controller = latest(channel);
    controller.addError(error, StackTrace.current);
    unawaited(controller.close());
  }

  @override
  Map<String, Stream<Object?>> openChannels() {
    final gen = <String, StreamController<Object?>>{
      for (final name in channelNames)
        name: StreamController<Object?>.broadcast(),
    };
    generations.add(gen);
    return gen.map((key, value) => MapEntry(key, value.stream));
  }
}

Future<void> pump([Duration duration = Duration.zero]) =>
    Future<void>.delayed(duration);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Story 1.1 — ListenerSupervisor per-channel resubscribe-on-error', () {
    // ── Red-demo (NFR-1) ───────────────────────────────────────────────────
    //
    // Manually verified per the story's red-demo requirement: with the fix
    // reverted (onError only forwarding to the caller, `_attached` never
    // flipped per-channel, no backoff scheduled), this test FAILS —
    // `expect(delivered, equals(['second snapshot']))` times out because the
    // pumped snapshot is never delivered (the channel is dead but nothing
    // ever resubscribes it). With the fix in place it PASSES.
    test('a channel forced into onError resubscribes and delivers the next '
        'server snapshot (red-demo)', () async {
      final source = _RecorderSource(['completions', 'bookmarks']);
      final delivered = <Object?>[];
      final supervisor = ListenerSupervisor(
        source: source,
        onEvent: (channel, payload) => delivered.add(payload),
        resubscribeBackoffBase: const Duration(milliseconds: 5),
        resubscribeBackoffCap: const Duration(milliseconds: 20),
      );

      await supervisor.start();
      addTearDown(supervisor.stop);
      expect(source.openChannelsCallCount, 1);

      // Force the live 'completions' channel into a terminal error.
      source.errorAndTerminate('completions', Exception('UNAVAILABLE'));
      await pump();

      // Immediately after the error: the channel is dead, but the
      // supervisor as a whole is still attached — sibling channels are
      // unaffected (this is the exact contrast with the pre-fix bug, where
      // the channel was dead yet reported no way to tell).
      expect(supervisor.isAttached, isTrue);
      expect(supervisor.deadChannels, {'completions'});

      // Wait past the (short, injected) backoff window for the resubscribe
      // to fire.
      await pump(const Duration(milliseconds: 40));

      expect(
        supervisor.deadChannels,
        isEmpty,
        reason: 'the channel must have resubscribed by now',
      );
      expect(source.openChannelsCallCount, greaterThan(1));

      // A new server snapshot arrives on the freshly-resubscribed channel.
      source.latest('completions').add('second snapshot');
      await pump();

      expect(
        delivered,
        contains('second snapshot'),
        reason:
            'the resubscribed channel must deliver new snapshots — before '
            'the fix this never arrives because nothing ever resubscribes '
            'a dead channel.',
      );
    });

    // ── Sibling channels unaffected ────────────────────────────────────────

    test('one channel erroring never tears down or replaces a sibling '
        "channel's subscription", () async {
      final source = _RecorderSource(['completions', 'bookmarks', 'goals']);
      final delivered = <String>[];
      final supervisor = ListenerSupervisor(
        source: source,
        onEvent: (channel, payload) => delivered.add('$channel:$payload'),
        resubscribeBackoffBase: const Duration(milliseconds: 5),
        resubscribeBackoffCap: const Duration(milliseconds: 20),
      );

      await supervisor.start();
      addTearDown(supervisor.stop);

      // The very first generation's 'bookmarks' and 'goals' controllers —
      // if these ever stop being the live subscription, pushing through
      // them would silently stop being delivered.
      final originalBookmarks = source.generation(0, 'bookmarks');
      final originalGoals = source.generation(0, 'goals');

      source.errorAndTerminate('completions', Exception('permission-denied'));
      await pump();
      expect(supervisor.deadChannels, {'completions'});

      // Siblings still deliver through their ORIGINAL (generation-0)
      // controllers while 'completions' is mid-backoff.
      originalBookmarks.add('bookmarks-during-backoff');
      originalGoals.add('goals-during-backoff');
      await pump();
      expect(delivered, contains('bookmarks:bookmarks-during-backoff'));
      expect(delivered, contains('goals:goals-during-backoff'));

      // Let the resubscribe complete.
      await pump(const Duration(milliseconds: 40));
      expect(supervisor.deadChannels, isEmpty);

      // Siblings STILL deliver through the very same generation-0
      // controllers — resubscribing 'completions' never replaced them.
      originalBookmarks.add('bookmarks-after-heal');
      originalGoals.add('goals-after-heal');
      await pump();
      expect(delivered, contains('bookmarks:bookmarks-after-heal'));
      expect(delivered, contains('goals:goals-after-heal'));
    });

    // ── Backoff cap: bounded, never permanent give-up ──────────────────────

    test('computeBackoffDelay grows exponentially then caps — never unbounded, '
        'never gives up', () {
      final supervisor = ListenerSupervisor(
        source: _RecorderSource(['completions']),
        onEvent: (_, _) {},
        resubscribeBackoffBase: const Duration(seconds: 1),
        resubscribeBackoffCap: const Duration(seconds: 30),
        resubscribeBackoffJitter: 0, // isolate the growth curve from jitter
      );

      // 1s, 2s, 4s, 8s, 16s, then capped at 30s from attempt 6 onward.
      expect(supervisor.computeBackoffDelay(1), const Duration(seconds: 1));
      expect(supervisor.computeBackoffDelay(2), const Duration(seconds: 2));
      expect(supervisor.computeBackoffDelay(3), const Duration(seconds: 4));
      expect(supervisor.computeBackoffDelay(4), const Duration(seconds: 8));
      expect(supervisor.computeBackoffDelay(5), const Duration(seconds: 16));
      expect(supervisor.computeBackoffDelay(6), const Duration(seconds: 30));
      expect(supervisor.computeBackoffDelay(7), const Duration(seconds: 30));

      // AD-9: no permanent give-up — even an absurdly large attempt count
      // (weeks of continuous retrying at the cap) still returns a bounded,
      // finite delay at the cap rather than growing unboundedly or
      // throwing.
      expect(
        supervisor.computeBackoffDelay(10000),
        const Duration(seconds: 30),
      );
    });

    test('jitter perturbs the delay but never pushes it outside the configured '
        'band', () {
      const jitter = 0.2;
      final supervisor = ListenerSupervisor(
        source: _RecorderSource(['completions']),
        onEvent: (_, _) {},
        resubscribeBackoffBase: const Duration(seconds: 1),
        resubscribeBackoffCap: const Duration(seconds: 30),
        resubscribeBackoffJitter: jitter,
        random: math.Random(1234), // deterministic across the trial loop
      );

      // Below the cap: attempt 3 raw == 4s: band is [3.2s, 4.8s].
      for (var i = 0; i < 200; i++) {
        final d = supervisor.computeBackoffDelay(3);
        expect(d.inMilliseconds, greaterThanOrEqualTo(3200));
        expect(d.inMilliseconds, lessThanOrEqualTo(4800));
      }

      // At the cap: attempt 20 raw is astronomically above the 30s cap, so
      // the band is centred on the CAP, not the (irrelevant) raw value:
      // [24s, 36s].
      for (var i = 0; i < 200; i++) {
        final d = supervisor.computeBackoffDelay(20);
        expect(d.inMilliseconds, greaterThanOrEqualTo(24000));
        expect(d.inMilliseconds, lessThanOrEqualTo(36000));
      }
    });

    // ── Double-attach guard ─────────────────────────────────────────────────

    test('a pending resubscribe timer racing a concurrent restart() never '
        'produces two live subscriptions (no doubled delivery)', () async {
      final source = _RecorderSource(['completions', 'bookmarks']);
      final delivered = <String>[];
      final supervisor = ListenerSupervisor(
        source: source,
        onEvent: (channel, payload) => delivered.add('$channel:$payload'),
        // A backoff long enough that restart() below fires well before it
        // would otherwise elapse.
        resubscribeBackoffBase: const Duration(milliseconds: 200),
        resubscribeBackoffCap: const Duration(milliseconds: 200),
      );

      await supervisor.start();
      addTearDown(supervisor.stop);

      source.errorAndTerminate('completions', Exception('boom'));
      await pump();
      expect(supervisor.deadChannels, {'completions'});

      // restart() races the still-pending backoff timer.
      await supervisor.restart();
      expect(
        supervisor.deadChannels,
        isEmpty,
        reason: 'restart() reopens every channel',
      );

      // Wait past when the ORIGINAL backoff timer would have fired, had it
      // not been cancelled by restart().
      await pump(const Duration(milliseconds: 250));

      // Exactly one subscription: a single emission on the post-restart
      // stream produces exactly one delivery, never two.
      source.latest('completions').add('payload');
      await pump();
      expect(
        delivered.where((e) => e == 'completions:payload'),
        hasLength(1),
        reason:
            'a stale, superseded backoff resubscribe must not have opened '
            'a second subscription alongside the one restart() opened',
      );
    });

    test('two error events on the same still-open channel before it tears down '
        'coalesce onto a single pending resubscribe', () async {
      final source = _RecorderSource(['completions']);
      final delivered = <String>[];
      final supervisor = ListenerSupervisor(
        source: source,
        onEvent: (channel, payload) => delivered.add('$channel:$payload'),
        resubscribeBackoffBase: const Duration(milliseconds: 30),
        resubscribeBackoffCap: const Duration(milliseconds: 30),
      );

      await supervisor.start();
      addTearDown(supervisor.stop);

      // Two error events land back-to-back on the SAME stream before it is
      // torn down — `_scheduleResubscribe` always cancels any prior timer
      // for the channel before arming a new one (see its doc comment), so
      // this must still coalesce onto exactly ONE pending resubscribe, not
      // two independently-firing timers racing for the same channel.
      final dying = source.latest('completions');
      dying.addError(Exception('first'));
      dying.addError(Exception('should not double-schedule'));
      await dying.close();
      await pump();
      expect(supervisor.deadChannels, {'completions'});

      // Let the (single, coalesced) backoff resubscribe fire.
      await pump(const Duration(milliseconds: 60));
      expect(supervisor.deadChannels, isEmpty);
      // Exactly one fresh subscription resulted: start() (generation 0)
      // plus exactly one resubscribe (generation 1) — never two.
      expect(source.openChannelsCallCount, 2);

      source.latest('completions').add('payload');
      await pump();
      expect(delivered.where((e) => e == 'completions:payload'), hasLength(1));
    });

    // ── Park suppression ────────────────────────────────────────────────────

    test(
      'a channel that errors while parked does not resubscribe until unpark',
      () async {
        final source = _RecorderSource(['completions', 'bookmarks']);
        final supervisor = ListenerSupervisor(
          source: source,
          onEvent: (_, _) {},
          resubscribeBackoffBase: const Duration(milliseconds: 10),
          resubscribeBackoffCap: const Duration(milliseconds: 10),
        );

        await supervisor.start();
        addTearDown(supervisor.stop);

        source.errorAndTerminate('completions', Exception('boom'));
        await pump();
        expect(supervisor.deadChannels, {'completions'});

        // Park before the (short) backoff window elapses — this cancels the
        // pending timer. The channel stays dead, but must NOT resubscribe.
        await supervisor.park();
        final callsAtPark = source.openChannelsCallCount;

        // Wait well past when the backoff would otherwise have fired.
        await pump(const Duration(milliseconds: 50));
        expect(
          source.openChannelsCallCount,
          callsAtPark,
          reason: 'parked: no resubscribe may happen',
        );
        expect(supervisor.deadChannels, {'completions'});
        expect(supervisor.isParked, isTrue);

        // unpark() reopens EVERY channel, including the one that was dead.
        await supervisor.unpark();
        expect(supervisor.isAttached, isTrue);
        expect(supervisor.deadChannels, isEmpty);

        // The resubscribed channel is live and delivers again — proven via
        // deadChannels staying empty after pushing a fresh payload through
        // it (onEvent delivery itself is covered by the red-demo test).
        source.latest('completions').add('after-unpark');
        await pump();
        expect(supervisor.deadChannels, isEmpty);
      },
    );

    // ── deadChannels / deadChannelsChanges signal (for Story 1.5) ──────────

    test(
      'deadChannels and deadChannelsChanges reflect a channel going dead and '
      'recovering',
      () async {
        final source = _RecorderSource(['completions', 'bookmarks']);
        final supervisor = ListenerSupervisor(
          source: source,
          onEvent: (_, _) {},
          resubscribeBackoffBase: const Duration(milliseconds: 5),
          resubscribeBackoffCap: const Duration(milliseconds: 20),
        );

        final snapshots = <Set<String>>[];
        final sub = supervisor.deadChannelsChanges.listen(snapshots.add);
        addTearDown(sub.cancel);

        await supervisor.start();
        addTearDown(supervisor.stop);
        expect(supervisor.deadChannels, isEmpty);

        source.errorAndTerminate('completions', Exception('boom'));
        await pump();
        expect(supervisor.deadChannels, {'completions'});
        // `List<Set>.contains` uses `==`, which is identity-based for `Set`
        // (unlike `expect`'s own top-level `equals` unwrapping) — match by
        // value with a nested `equals`.
        expect(snapshots, contains(equals({'completions'})));

        await pump(const Duration(milliseconds: 40));
        expect(supervisor.deadChannels, isEmpty);
        expect(snapshots.last, isEmpty);
      },
    );

    // ── At-cap: keeps retrying forever, never a resting "exhausted" state ──

    test(
      'a channel that keeps failing every resubscribe attempt stays in '
      'deadChannels and keeps retrying at the cap — never gives up',
      () async {
        final source = _RecorderSource(['completions']);
        final supervisor = ListenerSupervisor(
          source: source,
          onEvent: (_, _) {},
          resubscribeBackoffBase: const Duration(milliseconds: 5),
          resubscribeBackoffCap: const Duration(milliseconds: 10),
        );

        await supervisor.start();
        addTearDown(supervisor.stop);

        // Fail the channel repeatedly: every time it resubscribes, error it
        // again immediately.
        for (var i = 0; i < 5; i++) {
          source.errorAndTerminate('completions', Exception('fail $i'));
          // Check immediately (before the backoff timer has had a chance to
          // fire) that the channel is marked dead.
          await pump();
          expect(
            supervisor.deadChannels,
            {'completions'},
            reason:
                'still dead right after failure $i — no resting "exhausted" '
                'state exists',
          );
          // Let this attempt's backoff resubscribe fire so the NEXT
          // iteration's error lands on the fresh subscription rather than a
          // dead, unlistened stream.
          await pump(const Duration(milliseconds: 15));
        }

        // The supervisor is still attached overall — this one permanently
        // flaky channel never tore down the whole fleet, and never stopped
        // trying.
        expect(supervisor.isAttached, isTrue);

        // One final successful attempt heals it.
        await pump(const Duration(milliseconds: 15));
        source.latest('completions').add('healed');
        await pump();
        expect(supervisor.deadChannels, isEmpty);
      },
    );
  });
}
