import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// Sefaria API base URL.
const _sefariaBaseUrl = 'https://www.sefaria.org/api';

/// Connection and receive timeout for all Dio requests.
const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 30);

/// Riverpod provider that creates and configures the application-wide [Dio]
/// HTTP client.
///
/// The client is pre-configured with:
/// - Sefaria API base URL
/// - JSON content-type headers
/// - Connection / receive timeouts
/// - [TalkerDioLogger] interceptor for structured request/response logging
///
/// Override in tests:
/// ```dart
/// final container = ProviderContainer(overrides: [
///   dioProvider.overrideWithValue(mockDio),
/// ]);
/// ```
final dioProvider = Provider<Dio>((ref) {
  final talker = ref.watch(talkerProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: _sefariaBaseUrl,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    TalkerDioLogger(
      talker: talker,
      settings: const TalkerDioLoggerSettings(
        printRequestHeaders: false,
        printResponseHeaders: false,
        printResponseData: false,
      ),
    ),
  );

  return dio;
});
