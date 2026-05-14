// Extra coverage for AppLogger — calls the uncovered structured/legacy
// log methods: critical, debugMsg, warningMsg, errorMsg, criticalMsg, log, handle.
//
// AppLogger.instance returns a Talker; the AppLogger instance methods are on
// AppLogger(talker) — so we construct a fresh AppLogger wrapping a Talker.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';

void main() {
  late AppLogger logger;

  setUp(() {
    final talker = AppLogger.init();
    logger = AppLogger(talker);
  });

  group('AppLogger structured methods', () {
    test('critical() does not throw', () {
      expect(
        () => logger.critical(event: 'test_critical', fields: {'key': 'value'}),
        returnsNormally,
      );
    });

    test('critical() with exception does not throw', () {
      expect(
        () => logger.critical(
          event: 'test_critical_with_ex',
          exception: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });
  });

  group('AppLogger legacy string methods', () {
    test('debugMsg() does not throw', () {
      expect(() => logger.debugMsg('debug message'), returnsNormally);
    });

    test('warningMsg() does not throw', () {
      expect(() => logger.warningMsg('warning message'), returnsNormally);
    });

    test('warningMsg() with exception does not throw', () {
      expect(
        () => logger.warningMsg('warn', Exception('ex'), StackTrace.current),
        returnsNormally,
      );
    });

    test('errorMsg() does not throw', () {
      expect(() => logger.errorMsg('error message'), returnsNormally);
    });

    test('errorMsg() with exception does not throw', () {
      expect(
        () => logger.errorMsg('err', Exception('ex'), StackTrace.current),
        returnsNormally,
      );
    });

    test('criticalMsg() does not throw', () {
      expect(() => logger.criticalMsg('critical message'), returnsNormally);
    });

    test('criticalMsg() with exception does not throw', () {
      expect(
        () => logger.criticalMsg('crit', Exception('ex'), StackTrace.current),
        returnsNormally,
      );
    });

    test('log() at info level does not throw', () {
      expect(
        () => logger.log('log message', level: LogLevel.info),
        returnsNormally,
      );
    });

    test('handle() does not throw', () {
      expect(
        () => logger.handle(Exception('handled'), StackTrace.current, 'ctx'),
        returnsNormally,
      );
    });

    test('talker getter returns non-null Talker', () {
      expect(logger.talker, isA<Talker>());
    });
  });
}
