/// Shared mock services for testing
/// Uses mocktail (no codegen) as per project standards
library;

import 'package:learning_tracker/core/network/connectivity_gateway.dart';
import 'package:mocktail/mocktail.dart';

// Connectivity Gateway (formerly ConnectivityService — renamed W5.20)
class MockConnectivityService extends Mock implements ConnectivityGateway {}
