import 'dart:io';

/// Signature of [InternetAddress.lookup], factored out so tests can supply
/// a fake without performing a real DNS query.
typedef DnsLookup = Future<List<InternetAddress>> Function(String host);

/// Service for checking network connectivity status.
///
/// Uses a lightweight DNS lookup to determine if the device can reach
/// the internet, avoiding dependency on platform-specific plugins.
class ConnectivityGateway {
  /// Creates a gateway. [lookup] defaults to [InternetAddress.lookup] and
  /// only needs overriding in tests, which inject a fake to stay hermetic.
  ConnectivityGateway({DnsLookup lookup = InternetAddress.lookup})
    : _lookup = lookup;

  final DnsLookup _lookup;

  /// Checks if the device currently has internet connectivity.
  ///
  /// Attempts a DNS lookup of a neutral host. Returns `true` if the
  /// lookup succeeds, `false` otherwise.
  Future<bool> get isOnline async {
    try {
      // Accepted tradeoff (AUD-core-network-03): `.timeout()` only races a
      // Timer against `_lookup`'s Future — dart:io exposes no cancellable
      // primitive for `InternetAddress.lookup`, so on timeout the
      // OS-level DNS resolution keeps running in the background with no
      // handle to cancel it.
      //
      // Bounded impact: each abandoned lookup is a single independent
      // Future that terminates on its own once the OS resolver completes
      // or gives up (it does not hang forever), after which Dart's GC
      // reclaims it — there is no unbounded accumulation over the life of
      // the app. `isOnline` is only invoked from user-initiated actions
      // (sign-in, delete-account, account-picker — see call sites), not
      // from a tight retry loop, so the number of concurrently
      // in-flight abandoned lookups stays small in practice.
      final result = await _lookup(
        'dns.google',
      ).timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on Exception {
      return false;
    }
  }

  /// Checks if the device is currently offline.
  Future<bool> get isOffline async => !(await isOnline);

  /// Releases any resources held by this service.
  ///
  /// Currently a no-op — provided so that [ConnectivityService] follows the
  /// disposable pattern and future stream subscriptions or timers can be
  /// cleaned up here without changing the provider.
  void dispose() {}
}
