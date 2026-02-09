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

/// Default connection timeout in milliseconds.
const _kConnectTimeout = Duration(seconds: 15);

/// Default receive timeout in milliseconds.
const _kReceiveTimeout = Duration(seconds: 30);

/// Maximum number of retry attempts for failed requests.
const _kMaxRetries = 3;

/// Initial delay between retries (doubles with each attempt).
const _kRetryDelay = Duration(seconds: 1);

/// Creates a configured [Dio] instance for Sefaria API requests.
///
/// Includes:
/// - Sefaria base URL
/// - Timeout configuration
/// - Retry interceptor with exponential backoff
/// - Talker logging interceptor
Dio createSefariaClient({TalkerDioLogger? logger}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://www.sefaria.org',
      connectTimeout: _kConnectTimeout,
      receiveTimeout: _kReceiveTimeout,
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(RetryInterceptor(dio: dio));

  if (logger != null) {
    dio.interceptors.add(logger);
  } else {
    dio.interceptors.add(
      TalkerDioLogger(
        settings: const TalkerDioLoggerSettings(
          printRequestHeaders: false,
          printResponseHeaders: false,
          printResponseData: false,
        ),
      ),
    );
  }

  return dio;
}

/// Interceptor that retries failed requests with exponential backoff.
///
/// Retries on:
/// - Network errors (connection timeout, socket exceptions)
/// - Server errors (5xx status codes)
/// - Rate limiting (429 status code)
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = _kMaxRetries,
    this.retryDelay = _kRetryDelay,
  });

  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final attempt = _getRetryCount(err.requestOptions) + 1;
    if (attempt > maxRetries) {
      return handler.next(err);
    }

    final delay = retryDelay * (1 << (attempt - 1));
    await Future<void>.delayed(delay);

    try {
      final options = err.requestOptions;
      options.extra['retryCount'] = attempt;
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  int _getRetryCount(RequestOptions options) {
    return (options.extra['retryCount'] as int?) ?? 0;
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    final statusCode = err.response?.statusCode;
    if (statusCode == null) return true;

    // Retry on server errors and rate limiting
    return statusCode >= 500 || statusCode == 429;
  }
}
