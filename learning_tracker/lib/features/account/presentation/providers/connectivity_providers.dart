import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// The single first-party reachability endpoint used for on-demand internet
/// probes.
///
/// `generate_204` is what Android's own captive-portal / network-validation
/// checks use: a bare, uncached, empty-body 204 response, so a probe costs
/// one tiny round trip and nothing else. This REPLACES the
/// `internet_connection_checker` package default of 3 third-party demo hosts
/// (`dummyapi.online`, `jsonplaceholder.typicode.com`, `fakestoreapi.com`) —
/// see finding E-1, docs/reports/sync-reliability-efficiency-review-2026-07-29.md.
final AddressCheckOption _reachabilityAddress = AddressCheckOption(
  uri: Uri.parse('https://www.gstatic.com/generate_204'),
);

/// Cadence of the background reachability safety-net probe (see
/// [connectivityStreamProvider]). Deliberately long (3-5 min band): day-to-day
/// online/offline detection is driven by real platform events
/// ([Connectivity.onConnectivityChanged]) and on-demand probes on
/// transitions/resume, not by this timer — it only exists to catch the rare
/// case where the OS-level network interface stays associated but upstream
/// connectivity silently drops or returns without a platform event (e.g. a
/// router's WAN link flaps while the LAN association is untouched).
const Duration _kBackgroundSafetyNetInterval = Duration(minutes: 4);

/// Shared `InternetConnectionChecker` instance, used ONLY as an on-demand
/// reachability probe (`hasConnection`) — never subscribed to its own
/// `onStatusChange`/internal polling loop. Configured against a single
/// first-party host so every probe this module ever issues (transition-
/// triggered, resume-triggered, or the background safety net) costs exactly
/// one request to ONE host, never the package default of 3.
///
/// Exposed as a provider so tests can override with a fake that emits a
/// scripted sequence without touching the network.
final internetConnectionCheckerProvider = Provider<InternetConnectionChecker>((
  ref,
) {
  final checker = InternetConnectionChecker.createInstance(
    // Defensive/documentary only: this module never subscribes to
    // `onStatusChange`, so the package's own internal timer (which is the
    // only thing that reads `checkInterval`) never starts. Set anyway so a
    // long, safe default is in force if anything else ever does.
    checkInterval: _kBackgroundSafetyNetInterval,
    addresses: [_reachabilityAddress],
  );
  ref.onDispose(checker.dispose);
  return checker;
});

/// The platform's `connectivity_plus` singleton — the real, event-driven
/// source of connectivity transitions (NIC associate/disassociate, Wi-Fi ↔
/// cellular handoff, airplane mode). A genuine OS callback, not a poll: idle
/// cost is ~0 while nothing on the device's network state changes.
///
/// Exposed as a provider so tests can swap the platform implementation via
/// `ConnectivityPlatform.instance =` (the standard federated-plugin test
/// seam) without needing to override this provider at all.
final connectivityPlusProvider = Provider<Connectivity>(
  (ref) => Connectivity(),
);

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

/// How long an "offline" signal must persist before it is forwarded
/// downstream as a real [connectivityStreamProvider] emission.
///
/// On Android/iOS the platform can fire an immediate `ConnectivityResult.none`
/// event before the OS has finished associating the active network interface
/// — a spurious ~1 s blip that causes the offline banner to flash on
/// cold-start even though the device is genuinely online.
///
/// Buffering "offline" signals for this short window suppresses startup noise
/// while keeping real mid-session offline detection fast (300 ms delay is
/// imperceptible in practice). "Online" (`true`) signals are always forwarded
/// immediately because there is no benefit in delaying a recovery signal.
const _kOfflineDebounce = Duration(milliseconds: 300);

/// Live connectivity stream — `true` when the device has a usable internet
/// connection, `false` otherwise. Widgets/providers that need to react to
/// online/offline transitions (offline banner, "Wait for Internet" screen,
/// sync engine activation) watch this.
///
/// ## Cost model (E-1 fix)
///
/// Before this fix, connectivity was sourced from
/// `InternetConnectionChecker.createInstance()` with NO overrides — the
/// package default: a 5 s poll against 3 third-party demo hosts, running
/// continuously in the foreground AND background (≈51,840 requests/day), plus
/// a SECOND redundant 5 s re-probe loop that ran while offline, doubling that
/// cost during any outage. Every one of those requests also wakes the
/// cellular radio, which is the dominant real-world battery/data cost — a
/// prior version of this comment incorrectly described the design as
/// "event-driven ... so idle CPU cost is [near zero]", which was never true
/// for this package version.
///
/// After this fix, connectivity is sourced from real platform events
/// ([Connectivity.onConnectivityChanged], via [connectivityPlusProvider]) —
/// a genuine OS callback with ~0 idle cost — plus an on-demand reachability
/// probe fired ONLY on a genuine transition or app-resume, against ONE
/// first-party host ([_reachabilityAddress]). A long-interval background
/// safety-net probe ([_kBackgroundSafetyNetInterval], 4 min) covers the rare
/// case a platform event never fires. Steady-state cost is therefore ≈
/// 86,400 / 240 ≈ 360 background probes/day, plus a handful more for real
/// transitions/resumes — a ~99% reduction from the pre-fix ≈51,840/day, and
/// the 5 s radio-wake cadence is eliminated entirely.
///
/// ## Behaviour
///
/// Starts with an explicit `hasConnection` check so subscribers get the
/// current state immediately instead of waiting for the first platform
/// event. Every emission also updates [lastKnownOnline] so the loading state
/// of connectivity-aware UI can seed from the latest reading.
///
///   * Offline signals are debounced by [_kOfflineDebounce] to suppress
///     transient platform noise (the cold-start flash described above).
///   * Online signals are forwarded immediately.
///   * A platform event reporting NO interface at all
///     (`ConnectivityResult.none`) is surfaced as offline directly — no probe
///     needed, the OS already told us there is no network path.
///   * A platform event reporting SOME interface (Wi-Fi/cellular/etc.)
///     triggers exactly one on-demand [InternetConnectionChecker.hasConnection]
///     probe before surfacing — having a NIC is not the same as having
///     working internet (captive portal, dead WAN).
///   * A resume from background also triggers one on-demand probe, so a
///     connection that returned while backgrounded is detected the moment
///     the user comes back, without waiting for the next safety-net tick.
///   * The self-healing loop from the pre-fix design (a fast, unconditional
///     re-probe timer while believed-offline) is REMOVED — recovery is now
///     driven by real platform events (the OS fires one the instant the
///     interface actually reconnects) plus the resume probe plus the
///     long-interval safety net, without doubling cost during an outage.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final checker = ref.watch(internetConnectionCheckerProvider);
  final connectivity = ref.watch(connectivityPlusProvider);

  final initial = await checker.hasConnection;
  _lastKnownOnline = initial;
  yield initial;

  // All downstream emissions flow through this controller so every source
  // (platform events, the background safety-net probe, the resume probe)
  // shares one debounce + output path.
  final controller = StreamController<bool>();
  Timer? offlineDebounceTimer;

  void surfaceOnline() {
    offlineDebounceTimer?.cancel();
    offlineDebounceTimer = null;
    _lastKnownOnline = true;
    if (!controller.isClosed) controller.add(true);
  }

  void surfaceOfflineDebounced() {
    offlineDebounceTimer?.cancel();
    offlineDebounceTimer = Timer(_kOfflineDebounce, () {
      _lastKnownOnline = false;
      if (!controller.isClosed) controller.add(false);
    });
  }

  // Runs a single on-demand reachability probe and surfaces the result. This
  // is the ONLY place a probe fires outside the long-interval background
  // safety net — always in direct response to a genuine transition or resume
  // signal, never on a fixed short cadence.
  Future<void> probeAndSurface() async {
    if (controller.isClosed) return;
    bool online;
    try {
      online = await checker.hasConnection;
    } on Object {
      // A failed probe means we're (still) offline.
      online = false;
    }
    if (controller.isClosed) return;
    if (online) {
      surfaceOnline();
    } else {
      surfaceOfflineDebounced();
    }
  }

  // Platform events: a real OS callback, not a poll — idle cost is ~0. Fires
  // ONLY on a genuine NIC-level change.
  final platformSubscription = connectivity.onConnectivityChanged.listen(
    (results) {
      if (results.length == 1 && results.single == ConnectivityResult.none) {
        // No interface at all: certainly offline, no probe needed.
        surfaceOfflineDebounced();
      } else {
        // Has *a* network path — confirm it's actually working internet.
        unawaited(probeAndSurface());
      }
    },
    onError: (Object e, StackTrace s) {
      // A platform-stream error must NOT latch the banner offline — leave
      // the last known state as-is; the next event or the safety-net probe
      // below will re-establish the truth.
    },
  );

  // Background safety net: re-verifies reachability on
  // [_kBackgroundSafetyNetInterval] regardless of platform events. See the
  // cost-model doc comment above.
  final safetyNetTimer = Timer.periodic(
    _kBackgroundSafetyNetInterval,
    (_) => probeAndSurface(),
  );

  // Re-probe the moment the app returns to the foreground: a connection that
  // came back while backgrounded is detected immediately instead of waiting
  // up to one safety-net interval.
  final lifecycleListener = AppLifecycleListener(
    onResume: () => probeAndSurface(),
  );

  ref.onDispose(() {
    platformSubscription.cancel();
    safetyNetTimer.cancel();
    offlineDebounceTimer?.cancel();
    lifecycleListener.dispose();
    controller.close();
  });

  yield* controller.stream;
});
