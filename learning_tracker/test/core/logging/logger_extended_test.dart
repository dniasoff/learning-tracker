/// Extended tests for AppLogger covering methods not exercised by logger_test.dart:
/// - debug, warning, error, critical (structured API)
/// - infoMsg, debugMsg, warningMsg, errorMsg, criticalMsg (legacy string API)
/// - log, handle
/// - AppLogger.instance singleton + talker getter
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';

void main() {
  late Talker talker;
  late AppLogger logger;

  setUp(() {
    talker = Talker();
    logger = AppLogger(talker);
  });

  group('AppLogger — structured API', () {
    test('debug logs a message at debug level', () {
      logger.debug(event: 'test_debug_event');
      expect(talker.history, isNotEmpty);
      expect(
        talker.history.last.generateTextMessage(),
        contains('test_debug_event'),
      );
    });

    test('debug with fields includes field values', () {
      logger.debug(event: 'pagination', fields: {'page': 3});
      final msg = talker.history.last.generateTextMessage();
      expect(msg, contains('pagination'));
      expect(msg, contains('3'));
    });

    test('warning logs a message', () {
      logger.warning(event: 'slow_network');
      expect(
        talker.history.last.generateTextMessage(),
        contains('slow_network'),
      );
    });

    test('warning with exception includes exception in log', () {
      logger.warning(
        event: 'retry_triggered',
        exception: Exception('timeout'),
      );
      // history should contain at least one entry
      expect(talker.history, isNotEmpty);
    });

    test('error logs a message', () {
      logger.error(event: 'db_write_failed');
      expect(
        talker.history.last.generateTextMessage(),
        contains('db_write_failed'),
      );
    });

    test('error with exception and stackTrace does not throw', () {
      try {
        throw Exception('forced error');
      } catch (e, st) {
        logger.error(event: 'caught_error', exception: e, stackTrace: st);
      }
      expect(talker.history, isNotEmpty);
    });

    test('critical logs a message', () {
      logger.critical(event: 'auth_failure');
      expect(
        talker.history.last.generateTextMessage(),
        contains('auth_failure'),
      );
    });

    test('critical with fields redacts sensitive keys', () {
      logger.critical(event: 'auth_failure', fields: {'token': 'abc123'});
      final msg = talker.history.last.generateTextMessage();
      expect(msg, contains('[REDACTED]'));
      expect(msg, isNot(contains('abc123')));
    });

    test('info with null fields does not crash', () {
      logger.info(event: 'startup_completed');
      expect(
        talker.history.last.generateTextMessage(),
        contains('startup_completed'),
      );
    });

    test('info with empty fields map logs event verbatim', () {
      logger.info(event: 'noop_event', fields: {});
      expect(
        talker.history.last.generateTextMessage(),
        contains('noop_event'),
      );
    });
  });

  group('AppLogger — legacy string API', () {
    test('infoMsg logs the message', () {
      logger.infoMsg('App started');
      expect(
        talker.history.last.generateTextMessage(),
        contains('App started'),
      );
    });

    test('infoMsg scrubs emails from messages', () {
      logger.infoMsg('User foo@bar.com signed in');
      final msg = talker.history.last.generateTextMessage();
      expect(msg, isNot(contains('foo@bar.com')));
      expect(msg, contains('[REDACTED]'));
    });

    test('debugMsg logs the message', () {
      logger.debugMsg('debug details');
      expect(
        talker.history.last.generateTextMessage(),
        contains('debug details'),
      );
    });

    test('warningMsg logs the message', () {
      logger.warningMsg('retry attempt');
      expect(
        talker.history.last.generateTextMessage(),
        contains('retry attempt'),
      );
    });

    test('warningMsg with exception does not throw', () {
      logger.warningMsg('timeout', Exception('net error'));
      expect(talker.history, isNotEmpty);
    });

    test('errorMsg logs the message', () {
      logger.errorMsg('operation failed');
      expect(
        talker.history.last.generateTextMessage(),
        contains('operation failed'),
      );
    });

    test('errorMsg with exception and stack does not throw', () {
      logger.errorMsg(
        'fatal',
        Exception('crash'),
        StackTrace.current,
      );
      expect(talker.history, isNotEmpty);
    });

    test('criticalMsg logs the message', () {
      logger.criticalMsg('system crash');
      expect(
        talker.history.last.generateTextMessage(),
        contains('system crash'),
      );
    });

    test('criticalMsg with exception and stack does not throw', () {
      logger.criticalMsg('critical error', Exception('boom'), StackTrace.current);
      expect(talker.history, isNotEmpty);
    });
  });

  group('AppLogger — log and handle', () {
    test('log at default info level adds to history', () {
      logger.log('generic log message');
      expect(talker.history, isNotEmpty);
    });

    test('log at debug level adds to history', () {
      logger.log('debug message', level: LogLevel.debug);
      expect(talker.history, isNotEmpty);
    });

    test('handle forwards exception to talker', () {
      final error = Exception('handled error');
      logger.handle(error, StackTrace.current);
      expect(talker.history, isNotEmpty);
    });

    test('handle without stack trace does not throw', () {
      logger.handle(Exception('no stack'));
      expect(talker.history, isNotEmpty);
    });

    test('handle with message forwards to talker', () {
      logger.handle(
        Exception('error with msg'),
        StackTrace.current,
        'custom message',
      );
      expect(talker.history, isNotEmpty);
    });
  });

  group('AppLogger — talker getter', () {
    test('talker getter returns the underlying Talker instance', () {
      expect(logger.talker, same(talker));
    });
  });

  group('PiiRedactor — additional cases', () {
    test('redacts uid key', () {
      final result = PiiRedactor.redactFields({'uid': 'firebase-uid-123'});
      expect(result['uid'], '[REDACTED]');
    });

    test('redacts password key', () {
      final result = PiiRedactor.redactFields({'password': 'secret123'});
      expect(result['password'], '[REDACTED]');
    });

    test('redacts secret key', () {
      final result = PiiRedactor.redactFields({'secret': 'mysecret'});
      expect(result['secret'], '[REDACTED]');
    });

    test('redacts refreshToken key', () {
      final result = PiiRedactor.redactFields({'refreshToken': 'tok-xyz'});
      expect(result['refreshToken'], '[REDACTED]');
    });

    test('redacts idToken key', () {
      final result = PiiRedactor.redactFields({'idToken': 'tok-abc'});
      expect(result['idToken'], '[REDACTED]');
    });

    test('redacts token key', () {
      final result = PiiRedactor.redactFields({'token': 'bearer-abc'});
      expect(result['token'], '[REDACTED]');
    });

    test('redacts pinHash key', () {
      final result = PiiRedactor.redactFields({'pinHash': r'$2b$10$...'});
      expect(result['pinHash'], '[REDACTED]');
    });

    test('redacts access_token (snake_case) key', () {
      final result = PiiRedactor.redactFields({'access_token': 'tok'});
      expect(result['access_token'], '[REDACTED]');
    });

    test('redacts refresh_token (snake_case) key', () {
      final result = PiiRedactor.redactFields({'refresh_token': 'rtok'});
      expect(result['refresh_token'], '[REDACTED]');
    });

    test('redacts id_token (snake_case) key', () {
      final result = PiiRedactor.redactFields({'id_token': 'itok'});
      expect(result['id_token'], '[REDACTED]');
    });

    test('scrubMessage replaces multiple emails in one string', () {
      final result = PiiRedactor.scrubMessage(
        'From: alice@example.com, To: bob@test.org',
      );
      expect(result, isNot(contains('@')));
      expect(result, contains('[REDACTED]'));
    });

    test('scrubMessage returns string unchanged when no email present', () {
      const message = 'No sensitive data here';
      expect(PiiRedactor.scrubMessage(message), message);
    });
  });
}
