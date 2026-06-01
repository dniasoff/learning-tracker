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

/// Live connectivity stream — `true` when the device has a usable
/// internet connection, `false` otherwise. Widgets/providers that
/// need to react to online/offline transitions (offline banner,
/// "Wait for Internet" screen, sync engine activation) watch this.
///
/// Starts with an explicit `hasConnection` check so subscribers get
/// the current state immediately instead of waiting for the first
/// transition event. Every emission also updates [lastKnownOnline] so the
/// loading state of connectivity-aware UI can seed from the latest reading.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final checker = ref.watch(internetConnectionCheckerProvider);
  final initial = await checker.hasConnection;
  _lastKnownOnline = initial;
  yield initial;
  yield* checker.onStatusChange.map((status) {
    final online = status == InternetConnectionStatus.connected;
    _lastKnownOnline = online;
    return online;
  });
});
