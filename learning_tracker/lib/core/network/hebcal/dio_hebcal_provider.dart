import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// Hebcal API base URL.
const _hebcalBaseUrl = 'https://www.hebcal.com';

/// Riverpod provider for the Hebcal-specific [Dio] HTTP client.
final hebcalDioProvider = Provider<Dio>((ref) {
  final talker = ref.watch(talkerProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: _hebcalBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
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
