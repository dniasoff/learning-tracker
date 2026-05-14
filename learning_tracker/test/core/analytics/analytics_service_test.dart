// Tests for LoggingAnalyticsService and FakeAnalyticsService.
// Covers LoggingAnalyticsService.logEvent (lines 131-137)
// and FakeAnalyticsService.events getter (line 149).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';

void main() {
  // =========================================================================
  // LoggingAnalyticsService
  // =========================================================================

  group('LoggingAnalyticsService', () {
    late AppLogger logger;
    late LoggingAnalyticsService service;

    setUp(() {
      final talker = AppLogger.init();
      logger = AppLogger(talker);
      service = LoggingAnalyticsService(logger);
    });

    test('logEvent completes without error', () async {
      await expectLater(service.logEvent('test_event'), completes);
    });

    test('logEvent with parameters completes without error', () async {
      await expectLater(
        service.logEvent(
          'test_event',
          parameters: {'key': 'value', 'count': 3},
        ),
        completes,
      );
    });

    test('logEvent without parameters completes without error', () async {
      await expectLater(service.logEvent('screen_view'), completes);
    });
  });

  // =========================================================================
  // FakeAnalyticsService — events getter
  // =========================================================================

  group('FakeAnalyticsService.events', () {
    test('events returns a non-null list with the right length', () async {
      final fake = FakeAnalyticsService();
      await fake.logEvent('event_one');
      await fake.logEvent('event_two');

      final eventList = fake.events;
      expect(eventList, hasLength(2));
      expect(eventList, isNotNull);
    });

    test('events reflects all fired events in order', () async {
      final fake = FakeAnalyticsService();
      await fake.logEvent('first');
      await fake.logEvent('second');
      await fake.logEvent('third');

      expect(fake.events.map((e) => e.name).toList(), [
        'first',
        'second',
        'third',
      ]);
    });
  });
}
