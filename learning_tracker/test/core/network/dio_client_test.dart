import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/lib/dio_client.dart';

/// A custom [HttpClientAdapter] that returns pre-configured responses
/// without making actual HTTP requests.
class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter({required this.statusCode, this.responseBody = '{}'});

  final int statusCode;
  final String responseBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Talker talker;
  late Dio dio;

  setUp(() {
    talker = AppLogger.init();
  });

  group('createDioClient', () {
    test('returns a Dio instance with TalkerDioLogger interceptor', () {
      dio = createDioClient(talker: talker);
      expect(dio, isA<Dio>());
      expect(dio.interceptors.any((i) => i is TalkerDioLogger), isTrue);
    });

    test('logs HTTP request URL, method, and response status code', () async {
      dio = createDioClient(talker: talker);
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: '{"data": "test"}',
      );

      final historyBefore = talker.history.length;
      await dio.get<dynamic>('https://api.example.com/texts/Mishnah');

      // Should have logged request and response
      expect(talker.history.length, greaterThan(historyBefore));

      final logMessages = talker.history
          .map((e) => e.generateTextMessage())
          .join('\n');

      // Verify URL is logged
      expect(logMessages, contains('api.example.com'));
      // Verify status code is logged
      expect(logMessages, contains('200'));
    });

    test(
      'does NOT log request/response bodies containing sensitive fields',
      () async {
        dio = createDioClient(talker: talker);
        dio.httpClientAdapter = _MockHttpClientAdapter(
          statusCode: 200,
          responseBody: jsonEncode({
            'email': 'user@example.com',
            'password': 'secret123',
            'token': 'jwt-token-value',
          }),
        );

        await dio.post<dynamic>(
          'https://api.example.com/auth/login',
          data: {'email': 'user@example.com', 'password': 'secret123'},
        );

        final logMessages = talker.history
            .map((e) => e.generateTextMessage())
            .join('\n');

        // Request/response bodies should NOT be logged
        expect(logMessages, isNot(contains('user@example.com')));
        expect(logMessages, isNot(contains('secret123')));
        expect(logMessages, isNot(contains('jwt-token-value')));
      },
    );

    test('does NOT log email addresses in auth operation logs', () async {
      dio = createDioClient(talker: talker);
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({'email': 'test@example.com', 'pin': '1234'}),
      );

      await dio.post<dynamic>(
        'https://api.example.com/auth/verify',
        data: {'email': 'test@example.com', 'pin': '1234'},
      );

      final logMessages = talker.history
          .map((e) => e.generateTextMessage())
          .join('\n');

      expect(logMessages, isNot(contains('test@example.com')));
      expect(logMessages, isNot(contains('"1234"')));
    });
  });

  group('createSefariaClient', () {
    test('configures correct Sefaria base URL', () {
      final dio = createSefariaClient();

      expect(dio.options.baseUrl, 'https://www.sefaria.org');
    });

    test('configures timeout settings', () {
      final dio = createSefariaClient();

      expect(dio.options.connectTimeout, const Duration(seconds: 15));
      expect(dio.options.receiveTimeout, const Duration(seconds: 30));
    });

    test('includes retry interceptor', () {
      final dio = createSefariaClient();

      final hasRetry = dio.interceptors.any((i) => i is RetryInterceptor);
      expect(hasRetry, true);
    });

    test('includes Accept: application/json header', () {
      final dio = createSefariaClient();

      expect(dio.options.headers['Accept'], 'application/json');
    });
  });
}
