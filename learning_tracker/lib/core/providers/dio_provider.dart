import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_tracker/core/network/dio_client.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';

/// Provides the application-wide [Dio] HTTP client instance.
///
/// The client is pre-configured with [TalkerDioLogger] interceptor
/// that logs request URLs, methods, and response status codes without
/// logging sensitive request/response body data.
final dioProvider = Provider<Dio>((ref) {
  final talker = ref.read(talkerProvider);
  return createDioClient(talker: talker);
});
