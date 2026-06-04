import 'dart:async';

import 'package:flutter/foundation.dart';
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
/// Offline signals from [InternetConnectionChecker.onStatusChange] are
/// debounced by [_kOfflineDebounce] to suppress transient platform noise
/// (see constant documentation above).  Online signals are forwarded
/// immediately.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final checker = ref.watch(internetConnectionCheckerProvider);
  final initial = await checker.hasConnection;
  _lastKnownOnline = initial;
  yield initial;

  // Debounce offline signals so a transient platform disconnected event
  // (common on startup) does not flash the offline banner.
  Timer? offlineDebounceTimer;
  final controller = StreamController<bool>();

  final subscription = checker.onStatusChange.listen(
    (status) {
      final online = status == InternetConnectionStatus.connected;
      _lastKnownOnline = online;
      if (online) {
        // Cancel any pending offline debounce and emit online immediately.
        offlineDebounceTimer?.cancel();
        offlineDebounceTimer = null;
        if (!controller.isClosed) controller.add(true);
      } else {
        // Defer the offline signal; only emit if still offline after the window.
        offlineDebounceTimer?.cancel();
        offlineDebounceTimer = Timer(_kOfflineDebounce, () {
          if (!controller.isClosed) controller.add(false);
        });
      }
    },
    onDone: () {
      offlineDebounceTimer?.cancel();
      controller.close();
    },
    onError: (Object e, StackTrace s) {
      offlineDebounceTimer?.cancel();
      if (!controller.isClosed) controller.addError(e, s);
    },
  );

  ref.onDispose(() {
    subscription.cancel();
    offlineDebounceTimer?.cancel();
    controller.close();
  });

  yield* controller.stream;
});
