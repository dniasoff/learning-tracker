import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() {
  late Talker talker;

  setUp(() {
    talker = AppLogger.init();
  });

  group('TalkerRiverpodObserver', () {
    test('logs provider create events', () {
      final observer = TalkerRiverpodObserver(
        talker: talker,
        settings: const TalkerRiverpodLoggerSettings(
          printProviderDisposed: true,
        ),
      );
      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      final testProvider = Provider<String>((ref) => 'test value');

      final historyBefore = talker.history.length;
      container.read(testProvider);

      expect(talker.history.length, greaterThan(historyBefore));

      final lastLog = talker.history.last.generateTextMessage();
      expect(lastLog, contains('initialized'));
    });

    test('logs provider dispose events', () {
      final observer = TalkerRiverpodObserver(
        talker: talker,
        settings: const TalkerRiverpodLoggerSettings(
          printProviderDisposed: true,
        ),
      );
      final container = ProviderContainer(observers: [observer]);

      final testProvider = Provider<String>((ref) => 'test value');

      // Create the provider.
      container.read(testProvider);
      final countAfterAdd = talker.history.length;
      expect(
        countAfterAdd,
        greaterThan(0),
        reason: 'Add event should be logged',
      );

      // Dispose the entire container, which disposes all providers.
      container.dispose();

      // Check for dispose log entry.
      final allLogs = talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      final hasDisposeLog = allLogs.any((log) => log.contains('disposed'));
      expect(
        hasDisposeLog,
        isTrue,
        reason:
            'Provider dispose event should be logged when container '
            'is disposed and printProviderDisposed is enabled',
      );
    });

    test('logs multiple provider lifecycle events', () {
      final observer = TalkerRiverpodObserver(
        talker: talker,
        settings: const TalkerRiverpodLoggerSettings(
          printProviderDisposed: true,
        ),
      );
      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      final provider1 = Provider<String>((ref) => 'first');
      final provider2 = Provider<int>((ref) => 42);
      final provider3 = Provider<bool>((ref) => true);

      container.read(provider1);
      container.read(provider2);
      container.read(provider3);

      expect(talker.history.length, equals(3));

      final logs = talker.history.map((e) => e.generateTextMessage()).toList();

      expect(logs[0], contains('initialized'));
      expect(logs[1], contains('initialized'));
      expect(logs[2], contains('initialized'));
    });
  });
}
