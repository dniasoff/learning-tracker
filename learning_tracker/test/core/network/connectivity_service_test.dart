import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/connectivity_gateway.dart';

void main() {
  group('ConnectivityGateway', () {
    test('isOnline and isOffline return opposite values', () async {
      final service = ConnectivityGateway();

      // We can't guarantee network in test, but we can verify
      // that isOnline and isOffline are consistent.
      final online = await service.isOnline;
      final offline = await service.isOffline;

      expect(online, isNot(offline));
    });
  });
}
