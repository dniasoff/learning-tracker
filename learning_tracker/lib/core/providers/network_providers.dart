import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  // ConnectivityService currently holds no long-lived resources, but
  // onDispose is registered here so that if a dispose() method is added
  // in the future it will be called automatically.
  ref.onDispose(() => service.dispose());
  return service;
});
