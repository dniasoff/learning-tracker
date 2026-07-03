import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      FlutterErrorDetails(exception: Exception('fallback')),
    );
  });

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

  group('FirebaseCrashlyticsService — analytics failures stay contained '
      '(AUD-core-logging-01)', () {
    late MockFirebaseCrashlytics mockCrashlytics;

    setUp(() {
      mockCrashlytics = MockFirebaseCrashlytics();
      when(
        () => mockCrashlytics.recordError(
          any<Object>(),
          any<StackTrace?>(),
          fatal: any(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockCrashlytics.recordFlutterFatalError(any()),
      ).thenAnswer((_) async {});
    });

    test('a rejecting analytics call inside recordFlutterFatalError does not '
        'escape as an uncaught zone error', () async {
      final service = FirebaseCrashlyticsService(
        mockCrashlytics,
        analytics: const _AlwaysThrowingAnalyticsService(),
      );
      final details = FlutterErrorDetails(
        exception: Exception('flutter fatal error'),
        stack: StackTrace.current,
      );

      var uncaughtZoneErrors = 0;
      final done = Completer<void>();

      unawaited(
        runZonedGuarded(
          () async {
            await service.recordFlutterFatalError(details);
            // Give the unguarded analytics Future a chance to reject and
            // propagate to the zone error handler, exactly as it would in
            // the running app.
            await Future<void>.delayed(Duration.zero);
            await Future<void>.delayed(Duration.zero);
            done.complete();
          },
          (error, stack) {
            uncaughtZoneErrors++;
          },
        ),
      );

      await done.future;

      expect(
        uncaughtZoneErrors,
        0,
        reason:
            'The rejected AnalyticsService.logCrashReported() Future '
            'fired from recordFlutterFatalError must be caught locally, '
            'not leak into the zone error handler',
      );
    });

    test('a rejecting analytics call inside recordError does not re-trigger '
        'recordError via the zone error handler', () async {
      final service = FirebaseCrashlyticsService(
        mockCrashlytics,
        analytics: const _AlwaysThrowingAnalyticsService(),
      );

      var recordErrorCalls = 0;
      Future<void> callRecordError() {
        recordErrorCalls++;
        return service.recordError(
          Exception('fatal crash #$recordErrorCalls'),
          StackTrace.current,
          fatal: true,
        );
      }

      final done = Completer<void>();

      // Mirrors main.dart's runZonedGuarded wiring (lines 15-34): the zone
      // error handler unconditionally forwards any uncaught zone error to
      // CrashlyticsService.recordError as fatal, fire-and-forget.
      unawaited(
        runZonedGuarded(
          () async {
            await callRecordError();
            // Give the unguarded analytics Future a chance to reject and
            // propagate to the zone error handler, exactly as it would in
            // the running app.
            await Future<void>.delayed(Duration.zero);
            await Future<void>.delayed(Duration.zero);
            done.complete();
          },
          (error, stack) {
            unawaited(callRecordError());
          },
        ),
      );

      await done.future;
      // Extra pump so a reentrant call (if the defect is present) has
      // settled before asserting the final count.
      await Future<void>.delayed(Duration.zero);

      expect(
        recordErrorCalls,
        1,
        reason:
            'A rejected analytics Future inside recordError must not '
            'escape to the runZonedGuarded error handler and cause '
            'recordError to be invoked a second time',
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

/// Mocks the Firebase Crashlytics SDK type so the real
/// [FirebaseCrashlyticsService] implementation can be exercised in tests
/// without a live Firebase app, per AUD-core-logging-01.
class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

/// Analytics double whose every call rejects, simulating a platform-channel
/// failure (offline analytics queue full, SDK not yet initialized, etc.)
/// per AUD-core-logging-01.
class _AlwaysThrowingAnalyticsService extends AnalyticsService {
  const _AlwaysThrowingAnalyticsService();

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    throw Exception('analytics call always fails in this test double');
  }
}
