import 'package:dio/dio.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// Creates a configured [Dio] instance with Talker logging interceptor.
///
/// The [TalkerDioLogger] interceptor logs request URLs, methods, and response
/// status codes. Request and response bodies are not logged to prevent
/// sensitive data leaks (emails, passwords, PINs).
Dio createDioClient({required Talker talker}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.add(
    TalkerDioLogger(
      talker: talker,
      settings: const TalkerDioLoggerSettings(
        // Log request/response metadata but NOT bodies to prevent
        // sensitive data leaks (email, password, PIN, tokens).
        printRequestData: false,
        printResponseData: false,
        printRequestHeaders: false,
        printResponseHeaders: false,
        printResponseMessage: true,
      ),
    ),
  );

  return dio;
}
