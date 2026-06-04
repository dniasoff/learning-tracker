import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Shared `InternetConnectionChecker` instance. The package runs a
/// low-frequency background probe against a set of reliable hosts
/// and emits a [InternetConnectionStatus] on every change — event-
/// driven instead of polling, so idle CPU cost is ~0.
///
/// Exposed as a provider so tests can override with a fake that
/// emits a scripted sequence without touching the network.
final internetConnectionCheckerProvider = Provider<InternetConnectionChecker>((
  ref,
) {
  final checker = InternetConnectionChecker.createInstance();
  ref.onDispose(checker.dispose);
  return checker;
});

/// Last connectivity value observed by [connectivityStreamProvider] in this
/// process. Seeds the *loading* state of connectivity-aware UI so screens never
/// have to fall back to a hard-coded assumption while the first probe is in
/// flight.
///
/// Defaults to `false` (offline). For an offline-first app, optimistically
/// claiming "online" before the probe resolves is the dangerous default: it
/// makes the sign-in / sign-up screens render the cloud-blue "your data is
/// backed up" card and a tappable Google button for the whole probe window
/// even when the device is genuinely offline. Assuming offline-until-proven-
/// online keeps those surfaces honest; a real online device self-corrects to
/// the cloud card within one probe cycle.
bool _lastKnownOnline = false;

/// Read the last connectivity value observed in this process. Exposed so
/// connectivity-aware widgets can seed their loading state with the most
/// recent real reading instead of a hard-coded guess. `@visibleForTesting`
/// reset lives alongside via [debugResetLastKnownOnline].
bool get lastKnownOnline => _lastKnownOnline;

/// Resets the process-wide connectivity cache. Tests that pump connectivity
/// screens call this so a value leaked from a previous test cannot bleed in.
@visibleForTesting
void debugResetLastKnownOnline() => _lastKnownOnline = false;

/// Seeds the process-wide connectivity cache. Tests that assert the ONLINE
/// variant of a connectivity-aware screen call this with `true` so the
/// loading-window fallback (read before the first stream emission) renders
/// online — a `connectivityStreamProvider` override alone does NOT update this
/// global, since the override replaces the body that maintains it.
@visibleForTesting
void debugSetLastKnownOnline(bool value) => _lastKnownOnline = value;

/// How long an "offline" signal from the platform connectivity stream must
/// persist before it is forwarded downstream as a real [connectivityStreamProvider]
/// emission.
///
/// The underlying `internet_connection_checker` package subscribes to the
/// platform `connectivity_plus` stream on first listen. On Android/iOS the
/// platform can fire an immediate `ConnectivityResult.none` event before the
/// OS has finished associating the active network interface — a spurious
/// ~1 s blip that causes the offline banner to flash on cold-start even though
/// the device is genuinely online.
///
/// Buffering "offline" signals for this short window suppresses startup noise
/// while keeping real mid-session offline detection fast (300 ms delay is
/// imperceptible in practice).  "Online" (`true`) signals are always forwarded
/// immediately because there is no benefit in delaying a recovery signal.
const _kOfflineDebounce = Duration(milliseconds: 300);

/// How often the provider re-probes connectivity while it currently believes
/// the device is OFFLINE.
///
/// Recovery must be automatic — the offline banner must clear on its own within
/// a few seconds of the connection returning, NOT only after a manual
/// pull-to-refresh. We cannot rely on `internet_connection_checker`'s own
/// internal poll for this: its default reachability hosts are three flaky
/// third-party demo APIs, and over a flaky link (e.g. Tailscale) its periodic
/// check can keep timing out / returning offline, leaving the banner stuck.
///
/// So while we believe we are offline we drive our OWN active `hasConnection`
/// re-probe on this interval. As soon as one succeeds we emit `true` and stop
/// the re-probe loop (the package's event-driven `onStatusChange` then handles
/// the next offline transition). While online, no re-probe runs — idle cost
/// stays ~0.
///
/// Not `const` so tests can shrink it via [debugSetOfflineRecoveryProbeInterval]
/// and exercise the self-heal loop without waiting whole seconds.
Duration _offlineRecoveryProbeInterval = const Duration(seconds: 5);

/// Test seam: shrink the offline recovery re-probe interval so the self-healing
/// loop can be exercised quickly. Pair with [debugResetOfflineRecoveryProbeInterval]
/// in a tearDown so the production default is restored between tests.
@visibleForTesting
void debugSetOfflineRecoveryProbeInterval(Duration value) =>
    _offlineRecoveryProbeInterval = value;

/// Test seam: restore the production offline recovery re-probe interval.
@visibleForTesting
void debugResetOfflineRecoveryProbeInterval() =>
    _offlineRecoveryProbeInterval = const Duration(seconds: 5);

/// Live connectivity stream — `true` when the device has a usable
/// internet connection, `false` otherwise. Widgets/providers that
/// need to react to online/offline transitions (offline banner,
/// "Wait for Internet" screen, sync engine activation) watch this.
///
/// Starts with an explicit `hasConnection` check so subscribers get
/// the current state immediately instead of waiting for the first
/// transition event. Every emission also updates [lastKnownOnline] so the
/// loading state of connectivity-aware UI can seed from the latest reading.
///
/// Behaviour:
///   * Offline signals from [InternetConnectionChecker.onStatusChange] are
///     debounced by [_kOfflineDebounce] to suppress transient platform noise.
///   * Online signals are forwarded immediately.
///   * While the provider currently believes it is OFFLINE it actively
///     re-probes [InternetConnectionChecker.hasConnection] every
///     [_kOfflineRecoveryProbeInterval] so the offline state self-heals to
///     online without any external invalidation or manual refresh.
///   * It also re-probes immediately on [AppLifecycleState.resumed], so a
///     connection that returned while the app was backgrounded is detected the
///     moment the user comes back.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final checker = ref.watch(internetConnectionCheckerProvider);
  final initial = await checker.hasConnection;
  _lastKnownOnline = initial;
  yield initial;

  // All downstream emissions flow through this controller so the debounce,
  // the recovery re-probe, and the lifecycle re-probe share one output.
  final controller = StreamController<bool>();
  Timer? offlineDebounceTimer;
  Timer? recoveryProbeTimer;
  // Whether the value we last surfaced downstream is "offline". Drives the
  // self-healing re-probe loop (only runs while we believe we're offline).
  var believeOffline = !initial;

  // Emits [online] downstream and (re)arms or cancels the offline recovery
  // re-probe loop accordingly. Centralised so every path — the status stream,
  // the periodic probe, and the lifecycle probe — keeps the loop consistent.
  void surface(bool online) {
    _lastKnownOnline = online;
    believeOffline = !online;
    if (!controller.isClosed) controller.add(online);
    if (online) {
      // Recovered (or stayed online): no need to keep re-probing.
      recoveryProbeTimer?.cancel();
      recoveryProbeTimer = null;
    } else {
      // Offline: ensure the self-healing re-probe loop is running.
      recoveryProbeTimer ??= Timer.periodic(
        _offlineRecoveryProbeInterval,
        (_) => _runRecoveryProbe(
          checker,
          controller,
          () => believeOffline,
          surface,
        ),
      );
    }
  }

  // If we started offline, begin the recovery loop immediately.
  if (believeOffline) {
    recoveryProbeTimer = Timer.periodic(
      _offlineRecoveryProbeInterval,
      (_) =>
          _runRecoveryProbe(checker, controller, () => believeOffline, surface),
    );
  }

  final subscription = checker.onStatusChange.listen(
    (status) {
      final online = status == InternetConnectionStatus.connected;
      if (online) {
        // Cancel any pending offline debounce and surface online immediately.
        offlineDebounceTimer?.cancel();
        offlineDebounceTimer = null;
        surface(true);
      } else {
        // Defer the offline signal; only surface if still offline after the
        // debounce window (suppresses transient startup noise).
        offlineDebounceTimer?.cancel();
        offlineDebounceTimer = Timer(_kOfflineDebounce, () => surface(false));
      }
    },
    onDone: () {
      offlineDebounceTimer?.cancel();
      recoveryProbeTimer?.cancel();
      controller.close();
    },
    onError: (Object e, StackTrace s) {
      // An error on the status stream must NOT latch the banner offline.
      // Surface it (app_shell treats AsyncError/AsyncLoading as assume-online),
      // but keep the recovery loop alive so we still self-heal.
      offlineDebounceTimer?.cancel();
      if (!controller.isClosed) controller.addError(e, s);
    },
  );

  // Re-probe the moment the app returns to the foreground: a connection that
  // came back while backgrounded is detected immediately instead of waiting up
  // to one probe interval.
  final lifecycleListener = AppLifecycleListener(
    onResume: () => _runRecoveryProbe(
      checker,
      controller,
      // On resume we always re-probe (even if we believe we're online) so a
      // connection that dropped while backgrounded is also re-evaluated.
      () => true,
      surface,
    ),
  );

  ref.onDispose(() {
    subscription.cancel();
    offlineDebounceTimer?.cancel();
    recoveryProbeTimer?.cancel();
    lifecycleListener.dispose();
    controller.close();
  });

  yield* controller.stream;
});

/// Runs a single active connectivity re-probe and surfaces the result.
///
/// [shouldProbe] gates the probe so the periodic loop only re-checks while we
/// still believe we're offline (a concurrent online signal may have already
/// cancelled the need to probe). The lifecycle-resume caller always passes a
/// `true` gate so a resume re-evaluates connectivity unconditionally.
Future<void> _runRecoveryProbe(
  InternetConnectionChecker checker,
  StreamController<bool> controller,
  bool Function() shouldProbe,
  void Function(bool online) surface,
) async {
  if (controller.isClosed || !shouldProbe()) return;
  bool online;
  try {
    online = await checker.hasConnection;
  } on Object {
    // A failed probe means we're (still) offline — keep the loop running.
    online = false;
  }
  if (controller.isClosed) return;
  // Only surface a result that still matters: an online recovery always
  // matters; an offline result only re-affirms an existing offline state, so
  // forwarding it is harmless (the controller de-dups at the StreamProvider).
  surface(online);
}
