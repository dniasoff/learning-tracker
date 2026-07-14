import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/connectivity_gateway.dart';

/// Fakes a successful DNS lookup — the "online" path.
Future<List<InternetAddress>> _fakeLookupSucceeds(String host) async {
  return [InternetAddress('142.250.0.1')];
}

/// Fakes the OS refusing the lookup (no route to host / DNS unreachable) —
/// the "offline" path. This is what a real device sees with no network,
/// without this test ever touching the real network.
Future<List<InternetAddress>> _fakeLookupThrowsSocketException(
  String host,
) async {
  throw const SocketException('Failed host lookup: no network');
}

void main() {
  group('ConnectivityGateway', () {
    test('isOnline is true when the DNS lookup succeeds', () async {
      final gateway = ConnectivityGateway(lookup: _fakeLookupSucceeds);

      expect(await gateway.isOnline, isTrue);
      expect(await gateway.isOffline, isFalse);
    });

    test(
      'isOnline is false when the DNS lookup throws a SocketException',
      () async {
        final gateway = ConnectivityGateway(
          lookup: _fakeLookupThrowsSocketException,
        );

        expect(await gateway.isOnline, isFalse);
        expect(await gateway.isOffline, isTrue);
      },
    );

    test(
      'isOnline is false when the DNS lookup returns no addresses',
      () async {
        final gateway = ConnectivityGateway(
          lookup: (host) async => <InternetAddress>[],
        );

        expect(await gateway.isOnline, isFalse);
      },
    );
  });
}
