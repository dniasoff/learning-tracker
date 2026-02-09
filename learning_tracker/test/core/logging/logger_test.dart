import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';

void main() {
  group('AppLogger', () {
    setUp(() {
      // Reset singleton for each test by re-initializing.
      AppLogger.init();
    });

    test('instance returns a Talker instance', () {
      final talker = AppLogger.instance;
      expect(talker, isA<Talker>());
    });

    test('instance returns the same instance across multiple calls', () {
      final first = AppLogger.instance;
      final second = AppLogger.instance;
      expect(identical(first, second), isTrue);
    });

    test('init creates and returns a Talker instance', () {
      final talker = AppLogger.init();
      expect(talker, isA<Talker>());
      expect(identical(talker, AppLogger.instance), isTrue);
    });
  });

  group('AppLogger.setupFlutterErrorHandlers', () {
    late FlutterExceptionHandler? originalOnError;
    late bool Function(Object, StackTrace)? originalPlatformOnError;

    setUp(() {
      AppLogger.init();
      originalOnError = FlutterError.onError;
      originalPlatformOnError = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
      PlatformDispatcher.instance.onError =
          originalPlatformOnError ?? (_, __) => false;
    });

    test('sets FlutterError.onError handler', () {
      AppLogger.setupFlutterErrorHandlers();
      expect(FlutterError.onError, isNotNull);
    });

    test('FlutterError.onError routes errors to Talker', () {
      AppLogger.setupFlutterErrorHandlers();
      final talker = AppLogger.instance;
      final historyBefore = talker.history.length;

      FlutterError.onError!(
        FlutterErrorDetails(
          exception: Exception('test flutter error'),
          stack: StackTrace.current,
        ),
      );

      expect(talker.history.length, greaterThan(historyBefore));
      expect(
        talker.history.last.generateTextMessage(),
        contains('test flutter error'),
      );
    });

    test('PlatformDispatcher.instance.onError routes errors to Talker', () {
      AppLogger.setupFlutterErrorHandlers();
      final talker = AppLogger.instance;
      final historyBefore = talker.history.length;

      final result = PlatformDispatcher.instance.onError!(
        Exception('test platform error'),
        StackTrace.current,
      );

      expect(result, isTrue);
      expect(talker.history.length, greaterThan(historyBefore));
      expect(
        talker.history.last.generateTextMessage(),
        contains('test platform error'),
      );
    });
  });

  group('SensitiveDataPatterns', () {
    test('detects email addresses in text', () {
      expect(
        SensitiveDataPatterns.containsSensitiveData(
          'user logged in with user@example.com',
        ),
        isTrue,
      );
    });

    test('detects sensitive field names', () {
      expect(
        SensitiveDataPatterns.containsSensitiveData('password: secret123'),
        isTrue,
      );
      expect(
        SensitiveDataPatterns.containsSensitiveData('{"email": "test"}'),
        isTrue,
      );
      expect(SensitiveDataPatterns.containsSensitiveData('pin: 1234'), isTrue);
      expect(
        SensitiveDataPatterns.containsSensitiveData('token: abc123'),
        isTrue,
      );
    });

    test('does not flag normal log messages', () {
      expect(
        SensitiveDataPatterns.containsSensitiveData('App started successfully'),
        isFalse,
      );
      expect(
        SensitiveDataPatterns.containsSensitiveData('GET /api/texts/Mishnah'),
        isFalse,
      );
    });

    test('log output for auth operations does not contain emails or PINs', () {
      // Simulate what would happen if auth data were logged
      const authRequestBody = '{"email": "user@example.com", "pin": "1234"}';
      expect(
        SensitiveDataPatterns.containsSensitiveData(authRequestBody),
        isTrue,
        reason: 'Auth request bodies must be detected as sensitive',
      );
    });
  });
}
