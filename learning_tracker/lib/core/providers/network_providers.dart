import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});
