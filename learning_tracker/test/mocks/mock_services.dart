/// Shared mock services for testing
/// Uses mocktail (no codegen) as per project standards
library;

import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:mocktail/mocktail.dart';

// Connectivity Service
class MockConnectivityService extends Mock implements ConnectivityService {}
