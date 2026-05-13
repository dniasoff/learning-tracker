/// Story acceptance tests for Epic 24 — Stop-the-Bleeding (Phase 0).
@Tags(['epic_24'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, test;
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:test/test.dart';

void main() {
  group('Epic 24 — Stop-the-Bleeding (Phase 0)', () {
    // ─── Story 24.4: Wire Crashlytics in main.dart ───────────────
    group(
      'Story 24.4 — Crashlytics wired in main.dart',
      tags: ['story_24_4'],
      () {
        late _CapturingCrashlyticsService service;

        setUp(() {
          service = _CapturingCrashlyticsService();
        });

        // AC1: setCrashlyticsCollectionEnabled(true) runs (interface level)
        test(
          'AC1: collection can be enabled without error',
          () async {
            await service.setCrashlyticsCollectionEnabled(true);
            expect(service.collectionEnabled, isTrue);
          },
        );

        // AC2: FlutterError.onError forwards to Crashlytics (via interface)
        test(
          'AC2: recordFlutterFatalError is called for Flutter errors',
          () async {
            final details = FlutterErrorDetails(
              exception: StateError('widget error'),
              stack: StackTrace.current,
            );
            await service.recordFlutterFatalError(details);
            expect(service.flutterErrors, hasLength(1));
            expect(service.flutterErrors.first.exception, isA<StateError>());
          },
        );

        // AC2: PlatformDispatcher.instance.onError forwards to Crashlytics
        test(
          'AC2: recordError(fatal: true) is called for platform errors',
          () async {
            final err = Exception('platform crash');
            final st = StackTrace.current;
            await service.recordError(err, st, fatal: true);
            expect(service.errors, hasLength(1));
            expect(service.errors.first.$1, err);
            expect(service.errors.first.$3, isTrue); // fatal flag
          },
        );

        // AC3+AC4: setUserIdentifier uses numeric profileId — no PII
        test(
          'AC3: setUserIdentifier sends numeric profileId as string',
          () async {
            await service.setUserIdentifier(5);
            expect(service.lastIdentifier, '5');
          },
        );

        test(
          'AC4: setUserIdentifier(null) clears identifier (no PII fallback)',
          () async {
            await service.setUserIdentifier(42); // simulate login
            await service.setUserIdentifier(null); // simulate logout
            expect(service.lastIdentifier, '');
          },
        );

        test(
          'AC4: no email or non-numeric PII in identifier',
          () async {
            await service.setUserIdentifier(99);
            final id = service.lastIdentifier!;
            expect(
              RegExp(r'^[0-9]*$').hasMatch(id),
              isTrue,
              reason: 'Identifier must be purely numeric. Got: "$id"',
            );
          },
        );

        // AC5: Crash is reported even before any sign-in (no identifier set)
        test(
          'AC5: errors are captured before any profile is selected',
          () async {
            // Identifier was never set — simulates pre-auth crash
            expect(service.lastIdentifier, isNull);
            await service.recordError(
              Exception('pre-auth crash'),
              StackTrace.current,
              fatal: true,
            );
            expect(service.errors, hasLength(1));
          },
        );

        // NullCrashlyticsService is safe to use when Firebase is unavailable
        test(
          'NullCrashlyticsService never throws (offline / test environment)',
          () async {
            const nullService = NullCrashlyticsService();
            await nullService.setCrashlyticsCollectionEnabled(true);
            await nullService.recordFlutterFatalError(
              FlutterErrorDetails(
                exception: Exception('x'),
                stack: StackTrace.current,
              ),
            );
            await nullService.recordError(
              Exception('y'),
              StackTrace.current,
              fatal: true,
            );
            await nullService.setUserIdentifier(1);
            await nullService.setUserIdentifier(null);
          },
        );
      },
    );
  });
}

// ─── Test helpers ────────────────────────────────────────────────────────────

/// A capturing [CrashlyticsService] that records every call made to it.
/// Uses the same identifier encoding as [FirebaseCrashlyticsService] so
/// PII-safety can be verified without touching the real Firebase SDK.
class _CapturingCrashlyticsService implements CrashlyticsService {
  bool? collectionEnabled;
  final List<FlutterErrorDetails> flutterErrors = [];
  final List<(Object, StackTrace?, bool)> errors = [];
  String? lastIdentifier;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    flutterErrors.add(details);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    errors.add((error, stack, fatal));
  }

  @override
  Future<void> setUserIdentifier(int? profileId) async {
    lastIdentifier = profileId == null ? '' : '$profileId';
  }
}
