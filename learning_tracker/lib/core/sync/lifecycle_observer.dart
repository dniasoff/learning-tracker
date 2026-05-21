import 'dart:async';

import 'package:flutter/widgets.dart';

typedef LifecycleHook = Future<void> Function();

/// Resume-time work runner for the sync subsystem (NFR20, T1.8).
///
/// Registers as a [WidgetsBindingObserver] and, on
/// [AppLifecycleState.resumed], invokes the injected hooks in order:
///
///   1. [resetFirestoreNetwork] — disable/re-enable the Firestore network so
///                                the gRPC channel re-resolves
///                                `firestore.googleapis.com` and re-establishes
///                                its connection.  Only invoked when we've
///                                actually returned from the background (i.e.
///                                the app entered `paused`/`inactive`/`hidden`
///                                before this resume), so cold-start resumes
///                                don't tear down a freshly-built channel.
///   2. [redetectTimezone]      — pick up any IANA-zone change that happened
///                                while the app was backgrounded (T1.8).
///   3. [invalidateSacredCache] — clear the persisted `SacredWindow` cache so
///                                the next read recomputes for the current
///                                day.
///   4. [triggerPull]           — kick off the pull pipeline (DNI-333's
///                                `PullPipeline.pullLatest()` or equivalent).
///   5. [unparkListeners]       — Phase 2 sync-architecture-plan: reopen the
///                                Firestore real-time listeners after the
///                                pull-delta has updated the local DB. Paired
///                                with [parkListeners] fired by the
///                                background timer (see below).
///
/// All hooks are awaited sequentially so a fast resume cannot interleave with
/// a slow timezone lookup. Errors are deliberately not caught at this layer —
/// hook authors are responsible for their own boundary handling (the sync
/// engine surfaces failures via `SyncStatus`).
///
/// ### Background parking (Phase 2 — 2026-05-21)
///
/// After [parkAfterBackgroundDuration] in any non-resumed state
/// (`paused`/`inactive`/`hidden`/`detached`), the observer invokes
/// [parkListeners] which detaches every Firestore real-time listener stream.
/// This eliminates the idle-listener Firestore read bill while backgrounded
/// (B.5 / B.6 targets in the architecture plan).
///
/// A short background → resume (< 60 s, e.g. a brief app switch) does NOT
/// fire [parkListeners]; the listeners stay attached. Only when the timer
/// elapses without a resume does the supervisor park.
class LifecycleObserver with WidgetsBindingObserver {
  LifecycleObserver({
    required this.redetectTimezone,
    required this.invalidateSacredCache,
    required this.triggerPull,
    this.resetFirestoreNetwork,
    this.parkListeners,
    this.unparkListeners,
    Duration? parkAfterBackgroundDuration,
  }) : parkAfterBackgroundDuration =
           parkAfterBackgroundDuration ?? const Duration(seconds: 60);

  final LifecycleHook redetectTimezone;
  final LifecycleHook invalidateSacredCache;
  final LifecycleHook triggerPull;

  /// Hook to disable/re-enable the Firestore network on a resume that follows
  /// a real background. Optional so call sites that don't need the self-heal
  /// (tests, non-Firestore environments) can omit it.
  final LifecycleHook? resetFirestoreNetwork;

  /// Hook to detach the Firestore real-time listener set. Phase 2 sync-
  /// architecture-plan: fires after [parkAfterBackgroundDuration] elapses
  /// without a resume.
  final LifecycleHook? parkListeners;

  /// Hook to reattach the Firestore real-time listener set. Fires AFTER the
  /// pull-delta completes on resume, so the local DB is current before the
  /// listener stream resumes.
  final LifecycleHook? unparkListeners;

  /// Minimum time the app must spend in `paused`/`inactive`/`hidden`/`detached`
  /// before [parkListeners] is invoked. Defaults to 60 s (Phase 2 spec).
  /// Configurable so tests can drive a much shorter window.
  final Duration parkAfterBackgroundDuration;

  bool _registered = false;

  /// True once we have observed the app entering a non-resumed lifecycle
  /// state. Stays false from process start through the first `resumed`
  /// event so cold-start resumes don't trigger a Firestore network reset.
  bool _wasBackgrounded = false;

  /// Background timer started on the first non-resumed lifecycle event;
  /// cancelled on `resumed`. When the timer fires (60 s elapsed), the
  /// observer invokes [parkListeners] and clears the timer.
  Timer? _parkTimer;

  /// True after [parkListeners] has fired in the current background spell.
  /// Reset on the next `resumed` event. Used so `unpark` only fires when a
  /// `park` actually happened (a brief background does not need an unpark).
  bool _wasParked = false;

  /// Register with `WidgetsBinding.instance` so [didChangeAppLifecycleState]
  /// starts receiving system lifecycle notifications.
  ///
  /// Idempotent: calling [start] twice without an intervening [stop] is a
  /// no-op — the second call does not double-register, so [stop] still
  /// correctly tears down the observer with a single call.
  void start() {
    if (_registered) return;
    _registered = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Unregister from `WidgetsBinding.instance`. Safe to call repeatedly.
  void stop() {
    if (!_registered) return;
    _registered = false;
    _parkTimer?.cancel();
    _parkTimer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) {
      // Any non-resumed state means we've left the foreground (paused while
      // another app is in front, inactive during a phone call, hidden while
      // detached). The next resume should self-heal the Firestore channel
      // since the underlying network may have changed (WiFi↔cell handoff,
      // VPN reconnect, etc.) and gRPC sometimes pins to a stale DNS answer.
      _wasBackgrounded = true;
      // Schedule the listener-park timer — only when one isn't already
      // running. A burst of non-resumed events (paused → hidden →
      // detached) must not cancel-and-restart the timer; we want the first
      // 60 s window from the FIRST non-resumed event.
      if (_parkTimer == null && parkListeners != null) {
        _parkTimer = Timer(parkAfterBackgroundDuration, _onParkTimerFired);
      }
      return;
    }
    // Resumed — cancel any pending park timer (we came back inside the window).
    _parkTimer?.cancel();
    _parkTimer = null;

    if (_wasBackgrounded) {
      _wasBackgrounded = false;
      final reset = resetFirestoreNetwork;
      if (reset != null) await reset();
    }
    await redetectTimezone();
    await invalidateSacredCache();
    await triggerPull();
    // Phase 2: unpark listeners AFTER the pull-delta completes, so the local
    // DB is current before the listener stream resumes. Only call when the
    // observer actually parked during this background spell.
    if (_wasParked) {
      _wasParked = false;
      final unpark = unparkListeners;
      if (unpark != null) await unpark();
    }
  }

  /// Invoked when the 60 s park timer fires without an intervening resume.
  /// Detaches the listener set; the next resume re-attaches via [unparkListeners].
  Future<void> _onParkTimerFired() async {
    _parkTimer = null;
    _wasParked = true;
    final park = parkListeners;
    if (park != null) {
      await park();
    }
  }
}
