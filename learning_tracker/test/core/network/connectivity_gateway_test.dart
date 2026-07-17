import 'dart:async';
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

    test('isOnline resolves false on timeout without waiting for a lookup '
        'that never completes (AUD-core-network-03: the abandoned lookup '
        'Future is left running in the background — see the accepted-'
        'tradeoff comment on ConnectivityGateway.isOnline)', () async {
      var lookupCompleted = false;
      final hang = Completer<List<InternetAddress>>();

      final gateway = ConnectivityGateway(
        lookup: (host) async {
          final result = await hang.future;
          lookupCompleted = true;
          return result;
        },
      );

      final stopwatch = Stopwatch()..start();
      final online = await gateway.isOnline;
      stopwatch.stop();

      // isOnline must not block on the lookup: it resolves via the 2s
      // timeout, well under the lookup's (never-completing) future.
      expect(online, isFalse);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));

      // The underlying lookup is still in flight — this is exactly the
      // documented, accepted leak. It is bounded because it is a single
      // independent Future that finishes (and is reclaimed) once the
      // fake "OS resolver" below completes it; it does not hang forever.
      expect(lookupCompleted, isFalse);
      hang.complete(<InternetAddress>[]);
      await Future<void>.delayed(Duration.zero);
      expect(lookupCompleted, isTrue);
    });
  });
}
