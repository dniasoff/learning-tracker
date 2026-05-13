import 'dart:async';

import 'package:flutter/widgets.dart';

typedef LifecycleHook = Future<void> Function();

/// Resume-time work runner for the sync subsystem (NFR20, T1.8).
///
/// Registers as a [WidgetsBindingObserver] and, on
/// [AppLifecycleState.resumed], invokes three injected hooks in order:
///
///   1. [redetectTimezone]      — pick up any IANA-zone change that happened
///                                while the app was backgrounded (T1.8).
///   2. [invalidateSacredCache] — clear the persisted `SacredWindow` cache so
///                                the next read recomputes for the current
///                                day. NOTE: until DNI-26.24 wires the
///                                persisted cache, callers should pass a
///                                no-op closure here — this seam exists so
///                                that 26.24 can land without re-touching
///                                lifecycle code.
///   3. [triggerPull]           — kick off the pull pipeline (DNI-333's
///                                `PullPipeline.pullLatest()` or equivalent).
///
/// All three hooks are awaited sequentially so a fast resume cannot
/// interleave with a slow timezone lookup. Errors are deliberately not
/// caught at this layer — hook authors are responsible for their own
/// boundary handling (the sync engine surfaces failures via `SyncStatus`).
class LifecycleObserver with WidgetsBindingObserver {
  LifecycleObserver({
    required this.redetectTimezone,
    required this.invalidateSacredCache,
    required this.triggerPull,
  });

  final LifecycleHook redetectTimezone;
  final LifecycleHook invalidateSacredCache;
  final LifecycleHook triggerPull;

  bool _registered = false;

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
    if (state != AppLifecycleState.resumed) return;
    await redetectTimezone();
    await invalidateSacredCache();
    await triggerPull();
  }
}
