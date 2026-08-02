import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

typedef LifecycleHook = Future<void> Function();

/// Resume-time work runner for the sync subsystem (NFR20, T1.8).
///
/// Registers as a [WidgetsBindingObserver] and, on
/// [AppLifecycleState.resumed], invokes the injected hooks in order:
///
///   1. [resetFirestoreNetwork] — disable/re-enable the Firestore network so
///                                the gRPC channel re-resolves
///                                `firestore.googleapis.com` and re-establishes
///                                its connection. Only invoked when the app
///                                left the foreground via a genuine
///                                `paused`/`hidden` state (never a transient
///                                `inactive` blip) AND [resolveNetworkIdentity]
///                                reports the network actually changed while
///                                away, debounced (Story 1.3 / FR18 / AD-9 /
///                                E-5) — see "Resume network-reset gating"
///                                below.
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
///                                background timer (see below). Only fires
///                                when a [park] actually happened this spell.
///   6. [resubscribeDeadChannels] — Story 1.3 (FR15 / AD-9): resurrect any
///                                channel that errored and is still dead
///                                (own AND tutored, via the Story 1.1/1.2
///                                machinery) on ANY genuine resume from the
///                                background — including a short `inactive`
///                                blip that does NOT warrant the heavier
///                                network reset above. A no-op when nothing
///                                is dead.
///
/// All hooks are awaited sequentially so a fast resume cannot interleave with
/// a slow timezone lookup. Errors are deliberately not caught at this layer —
/// hook authors are responsible for their own boundary handling (the sync
/// engine surfaces failures via `SyncStatus`).
///
/// ### Resume network-reset gating (Story 1.3 / FR18 / AD-9 / E-5)
///
/// [resetFirestoreNetwork] is a heavyweight, SDK-global operation — it forces
/// every live listener across the whole gRPC channel to drop and re-handshake.
/// Firing it on every trivial app-switch (a notification shade, a permission
/// dialog) is wasteful and was report finding E-5. It is now gated on THREE
/// conditions, all of which must hold:
///
///   1. **Real background, not a blip.** Only [AppLifecycleState.paused] and
///      [AppLifecycleState.hidden] arm the reset — [AppLifecycleState.inactive]
///      (and [AppLifecycleState.detached]) never do. This is tracked
///      independently of the (unrestricted) [_wasBackgrounded] flag that
///      still gates [resubscribeDeadChannels] below.
///   2. **A genuine network-identity change.** [resolveNetworkIdentity], if
///      supplied, is called once on entering `paused`/`hidden` and once again
///      on resume; the reset only fires if the two values differ (e.g. a
///      WiFi↔cellular handoff that grpc-java's stale DNS cache doesn't
///      self-heal from). When [resolveNetworkIdentity] is omitted, every
///      real background→resume is treated as a change (preserves the
///      pre-Story-1.3 always-reset behaviour for callers/tests that don't
///      care about identity-gating).
///   3. **Debounced.** Even a genuine change only fires the reset once per
///      [resumeResetDebounce] window — a burst of rapid resumes (flapping)
///      collapses to a single reset.
///
/// ### Background parking (Phase 2 — 2026-05-21)
///
/// After [parkAfterBackgroundDuration] in any non-resumed state
/// (`paused`/`inactive`/`hidden`/`detached`), the observer invokes
/// [parkListeners] which detaches every Firestore real-time listener stream.
/// This eliminates the idle-listener Firestore read bill while backgrounded
/// (B.5 / B.6 targets in the architecture plan). This timer is unrelated to
/// the network-reset gating above and still arms on any non-resumed state.
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
    this.resubscribeDeadChannels,
    this.resolveNetworkIdentity,
    Duration? parkAfterBackgroundDuration,
    Duration? resumeResetDebounce,
  }) : parkAfterBackgroundDuration =
           parkAfterBackgroundDuration ?? const Duration(seconds: 60),
       resumeResetDebounce = resumeResetDebounce ?? const Duration(seconds: 2);

  final LifecycleHook redetectTimezone;
  final LifecycleHook invalidateSacredCache;
  final LifecycleHook triggerPull;

  /// Hook to disable/re-enable the Firestore network on a resume that follows
  /// a real background AND a genuine network-identity change. Optional so
  /// call sites that don't need the self-heal (tests, non-Firestore
  /// environments) can omit it. See the class doc's "Resume network-reset
  /// gating" section for the full gate.
  final LifecycleHook? resetFirestoreNetwork;

  /// Hook to detach the Firestore real-time listener set. Phase 2 sync-
  /// architecture-plan: fires after [parkAfterBackgroundDuration] elapses
  /// without a resume.
  final LifecycleHook? parkListeners;

  /// Hook to reattach the Firestore real-time listener set. Fires AFTER the
  /// pull-delta completes on resume, so the local DB is current before the
  /// listener stream resumes.
  final LifecycleHook? unparkListeners;

  /// Story 1.3 (FR15 / AD-9): hook to resubscribe every dead channel (own AND
  /// tutored, via the Story 1.1/1.2 machinery) on a genuine resume from the
  /// background. Fires on ANY real background→resume — including a short
  /// `inactive` blip that does not arm [resetFirestoreNetwork] — because a
  /// channel can be dead (App-Check failure, a transient error) independent
  /// of whether the network identity changed. Expected to be a cheap no-op
  /// when nothing is dead. Optional so tests/environments that don't wire the
  /// listener fleets can omit it.
  final LifecycleHook? resubscribeDeadChannels;

  /// Story 1.3 (FR18 / AD-9 / E-5): optional probe for the current network's
  /// "identity" — an opaque, `==`-comparable value (e.g. the sorted set of
  /// active `ConnectivityResult`s) representing which network the device is
  /// on right now. Called once when the app enters `paused`/`hidden` and once
  /// again on the following resume; [resetFirestoreNetwork] only fires when
  /// the two values differ. When omitted, every real background→resume is
  /// conservatively treated as a change (see class doc).
  final Future<Object?> Function()? resolveNetworkIdentity;

  /// Minimum time the app must spend in `paused`/`inactive`/`hidden`/`detached`
  /// before [parkListeners] is invoked. Defaults to 60 s (Phase 2 spec).
  /// Configurable so tests can drive a much shorter window.
  final Duration parkAfterBackgroundDuration;

  /// Story 1.3: minimum time between two actual [resetFirestoreNetwork]
  /// invocations. A burst of resumes that each independently detect a
  /// network-identity change still only fires the reset once per window.
  /// Defaults to 2 s; configurable so tests don't need to sleep for it.
  final Duration resumeResetDebounce;

  bool _registered = false;

  /// True once we have observed the app entering ANY non-resumed lifecycle
  /// state (`paused`/`inactive`/`hidden`/`detached`). Stays false from
  /// process start through the first `resumed` event so cold-start resumes
  /// don't trigger dead-channel resubscribe work. Gates
  /// [resubscribeDeadChannels] only — NOT [resetFirestoreNetwork], which uses
  /// the stricter [_networkResetEligible] below (Story 1.3 / AC2).
  bool _wasBackgrounded = false;

  /// True once we have observed the app entering `paused`/`hidden`
  /// specifically (never `inactive`/`detached`). Gates
  /// [resetFirestoreNetwork] — a transient `inactive` blip (notification
  /// shade, permission dialog) must never arm it (Story 1.3 / AC2 / E-5).
  bool _networkResetEligible = false;

  /// The network identity captured the first time this background spell
  /// entered `paused`/`hidden`, via [resolveNetworkIdentity]. `null` both
  /// when no probe is wired and when the probe itself returned `null` —
  /// [_hasCapturedBackgroundIdentity] disambiguates "never captured" from
  /// "captured as null".
  Object? _backgroundNetworkIdentity;
  bool _hasCapturedBackgroundIdentity = false;

  /// Wall-clock time [resetFirestoreNetwork] last actually fired. Used to
  /// debounce a burst of resumes into a single reset (Story 1.3 / AC2).
  DateTime? _lastResetFiredAt;

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
      // detached). Unrestricted flag: gates only [resubscribeDeadChannels],
      // which is cheap/no-op-safe and worth attempting even after a trivial
      // blip.
      _wasBackgrounded = true;

      // Story 1.3 (AC2 / E-5): only a real background — `paused`/`hidden` —
      // arms the (expensive, SDK-global) network reset. A transient
      // `inactive` blip (notification shade, permission dialog) must not.
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        _networkResetEligible = true;
        if (!_hasCapturedBackgroundIdentity) {
          _hasCapturedBackgroundIdentity = true;
          final resolve = resolveNetworkIdentity;
          _backgroundNetworkIdentity = resolve == null ? null : await resolve();
        }
      }

      // Schedule the listener-park timer — only when one isn't already
      // running. A burst of non-resumed events (paused → hidden →
      // detached) must not cancel-and-restart the timer; we want the first
      // 60 s window from the FIRST non-resumed event. Unrelated to the
      // network-reset gating above — still arms on any non-resumed state.
      if (_parkTimer == null && parkListeners != null) {
        _parkTimer = Timer(parkAfterBackgroundDuration, _onParkTimerFired);
      }
      return;
    }
    // Resumed — cancel any pending park timer (we came back inside the window).
    _parkTimer?.cancel();
    _parkTimer = null;

    final wasBackgrounded = _wasBackgrounded;
    _wasBackgrounded = false;

    if (_networkResetEligible) {
      _networkResetEligible = false;
      final hadCapturedIdentity = _hasCapturedBackgroundIdentity;
      final backgroundIdentity = _backgroundNetworkIdentity;
      _hasCapturedBackgroundIdentity = false;
      _backgroundNetworkIdentity = null;

      if (await _shouldResetOnResume(hadCapturedIdentity, backgroundIdentity)) {
        final reset = resetFirestoreNetwork;
        if (reset != null) await reset();
      }
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

    // Story 1.3 (FR15 / AD-9): resurrect any dead channel (own + tutored) on
    // ANY genuine resume-from-background, regardless of whether the network
    // reset above fired — a listener can be dead (App-Check failure) with no
    // network-identity change at all, and [unparkListeners] above only
    // clears dead-channel state when a park actually happened (≥ 60 s
    // background). Cheap no-op when nothing is dead.
    if (wasBackgrounded) {
      final resubscribe = resubscribeDeadChannels;
      if (resubscribe != null) await resubscribe();
    }
  }

  /// Decides whether a resume that left `_networkResetEligible` set should
  /// actually fire [resetFirestoreNetwork] — a genuine network-identity
  /// change (or no identity probe wired at all) AND outside the debounce
  /// window. See the class doc's "Resume network-reset gating" section.
  Future<bool> _shouldResetOnResume(
    bool hadCapturedIdentity,
    Object? backgroundIdentity,
  ) async {
    final resolve = resolveNetworkIdentity;
    bool changed;
    if (resolve == null) {
      // No identity probe wired — preserve the pre-Story-1.3 always-reset-
      // on-real-background behaviour.
      changed = true;
    } else if (!hadCapturedIdentity) {
      // Should not normally happen once `_networkResetEligible` is set, but
      // guard conservatively.
      changed = true;
    } else {
      final current = await resolve();
      changed = current != backgroundIdentity;
    }
    if (!changed) return false;

    final now = DateTimeFactory.nowUtc();
    final last = _lastResetFiredAt;
    if (last != null && now.difference(last) < resumeResetDebounce) {
      // Debounced — a reset already fired inside this window.
      return false;
    }
    _lastResetFiredAt = now;
    return true;
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
