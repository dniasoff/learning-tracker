import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Shared `InternetConnectionChecker` instance. The package runs a
/// low-frequency background probe against a set of reliable hosts
/// and emits a [InternetConnectionStatus] on every change — event-
/// driven instead of polling, so idle CPU cost is ~0.
///
/// Exposed as a provider so tests can override with a fake that
/// emits a scripted sequence without touching the network.
final internetConnectionCheckerProvider =
    Provider<InternetConnectionChecker>((ref) {
  final checker = InternetConnectionChecker.createInstance();
  ref.onDispose(checker.dispose);
  return checker;
});

/// Live connectivity stream — `true` when the device has a usable
/// internet connection, `false` otherwise. Widgets/providers that
/// need to react to online/offline transitions (offline banner,
/// "Wait for Internet" screen, sync engine activation) watch this.
///
/// Starts with an explicit `hasConnection` check so subscribers get
/// the current state immediately instead of waiting for the first
/// transition event.
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final checker = ref.watch(internetConnectionCheckerProvider);
  yield await checker.hasConnection;
  yield* checker.onStatusChange.map(
    (status) => status == InternetConnectionStatus.connected,
  );
});
