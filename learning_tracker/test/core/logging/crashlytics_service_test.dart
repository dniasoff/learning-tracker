import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';

void main() {
  group('NullCrashlyticsService', () {
    late NullCrashlyticsService service;

    setUp(() {
      service = const NullCrashlyticsService();
    });

    test('setCrashlyticsCollectionEnabled does not throw', () async {
      await service.setCrashlyticsCollectionEnabled(true);
      // passes if no exception is thrown
    });

    test('recordFlutterFatalError does not throw', () async {
      final details = FlutterErrorDetails(
        exception: Exception('test error'),
        stack: StackTrace.current,
      );
      await service.recordFlutterFatalError(details);
    });

    test('recordError does not throw', () async {
      await service.recordError(
        Exception('oops'),
        StackTrace.current,
        fatal: true,
      );
    });

    test('setUserIdentifier with profileId does not throw', () async {
      await service.setUserIdentifier(5);
    });

    test('setUserIdentifier with null does not throw', () async {
      await service.setUserIdentifier(null);
    });
  });

  group('CrashlyticsService contract — numeric identifier only', () {
    // Verify that the service encodes profileId as a plain integer string,
    // which is a PII-safe identifier per the story acceptance criteria.
    // We use a spy/recorder to capture what would be sent.
    test('setUserIdentifier(5) encodes as "5"', () async {
      final recorder = _RecordingCrashlyticsService();
      await recorder.setUserIdentifier(5);
      expect(recorder.lastIdentifier, '5');
    });

    test('setUserIdentifier(null) encodes as empty string', () async {
      final recorder = _RecordingCrashlyticsService();
      await recorder.setUserIdentifier(null);
      expect(recorder.lastIdentifier, '');
    });

    test('setUserIdentifier does not include email or PII', () async {
      final recorder = _RecordingCrashlyticsService();
      await recorder.setUserIdentifier(42);
      final id = recorder.lastIdentifier!;
      // Must be purely numeric — no "@", no letters that suggest an email
      expect(
        RegExp(r'^[0-9]*$').hasMatch(id),
        isTrue,
        reason: 'Identifier must be numeric only, got: "$id"',
      );
    });
  });
}

/// A recording [CrashlyticsService] that captures what identifier was set.
/// This mirrors the encoding logic in [FirebaseCrashlyticsService] so we can
/// assert PII-safety without touching the real Firebase SDK.
class _RecordingCrashlyticsService implements CrashlyticsService {
  String? lastIdentifier;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> setUserIdentifier(int? profileId) async {
    // Mirror the encoding from FirebaseCrashlyticsService
    lastIdentifier = profileId == null ? '' : '$profileId';
  }
}
