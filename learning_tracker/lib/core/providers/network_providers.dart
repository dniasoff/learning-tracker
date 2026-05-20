import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/network/connectivity_gateway.dart';

final connectivityServiceProvider = Provider<ConnectivityGateway>((ref) {
  final service = ConnectivityGateway();
  // ConnectivityGateway currently holds no long-lived resources, but
  // onDispose is registered here so that if a dispose() method is added
  // in the future it will be called automatically.
  ref.onDispose(() => service.dispose());
  return service;
});
