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
///
/// All hooks are awaited sequentially so a fast resume cannot interleave with
/// a slow timezone lookup. Errors are deliberately not caught at this layer —
/// hook authors are responsible for their own boundary handling (the sync
/// engine surfaces failures via `SyncStatus`).
class LifecycleObserver with WidgetsBindingObserver {
  LifecycleObserver({
    required this.redetectTimezone,
    required this.invalidateSacredCache,
    required this.triggerPull,
    this.resetFirestoreNetwork,
  });

  final LifecycleHook redetectTimezone;
  final LifecycleHook invalidateSacredCache;
  final LifecycleHook triggerPull;

  /// Hook to disable/re-enable the Firestore network on a resume that follows
  /// a real background. Optional so call sites that don't need the self-heal
  /// (tests, non-Firestore environments) can omit it.
  final LifecycleHook? resetFirestoreNetwork;

  bool _registered = false;

  /// True once we have observed the app entering a non-resumed lifecycle
  /// state. Stays false from process start through the first `resumed`
  /// event so cold-start resumes don't trigger a Firestore network reset.
  bool _wasBackgrounded = false;

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
      return;
    }
    if (_wasBackgrounded) {
      _wasBackgrounded = false;
      final reset = resetFirestoreNetwork;
      if (reset != null) await reset();
    }
    await redetectTimezone();
    await invalidateSacredCache();
    await triggerPull();
  }
}
