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
