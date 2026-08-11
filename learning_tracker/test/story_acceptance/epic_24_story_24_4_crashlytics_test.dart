/// Story acceptance tests for Epic 24 -- Stop-the-Bleeding (Phase 0).
///
/// Story 24.4: Wire Crashlytics in main.dart.
@Tags(['epic_24'])
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, setUpAll, test;
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Story 24.4 — Crashlytics wired in main.dart',
    tags: ['story_24_4'],
    () {
      late _CapturingCrashlyticsService service;

      setUp(() {
        service = _CapturingCrashlyticsService();
      });

      // AC1: setCrashlyticsCollectionEnabled(true) runs (interface level)
      test('AC1: collection can be enabled without error', () async {
        await service.setCrashlyticsCollectionEnabled(true);
        expect(service.collectionEnabled, isTrue);
      });

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

      // AC3+AC4: setUserIdentifier uses the profileId ULID (AD-24) — no PII.
      //
      // AUD-t-story-acceptance-21: these three tests exercise the REAL
      // FirebaseCrashlyticsService.setUserIdentifier (via a mocked
      // FirebaseCrashlytics SDK object) instead of a hand-duplicated
      // ternary on the fake below. _CapturingCrashlyticsService.
      // setUserIdentifier independently re-implements the same
      // `profileId ?? ''` encoding as FirebaseCrashlyticsService -- if the
      // real class's encoding ever diverged (e.g. an email fallback on a
      // null check gone wrong), the fake's copy would keep this PII-safety
      // suite green while the production Crashlytics identifier leaked PII.
      group('AC3/AC4: setUserIdentifier — exercises the real service', () {
        late MockFirebaseCrashlytics mockCrashlytics;
        late FirebaseCrashlyticsService realService;

        setUp(() {
          mockCrashlytics = MockFirebaseCrashlytics();
          when(
            () => mockCrashlytics.setUserIdentifier(any()),
          ).thenAnswer((_) async {});
          realService = FirebaseCrashlyticsService(mockCrashlytics);
        });

        test(
          'AC3: setUserIdentifier sends the profileId ULID as-is',
          () async {
            await realService.setUserIdentifier('01ARZ3NDEKTSV4RRFFQ69G5FAV');
            verify(
              () => mockCrashlytics.setUserIdentifier(
                '01ARZ3NDEKTSV4RRFFQ69G5FAV',
              ),
            ).called(1);
          },
        );

        test(
          'AC4: setUserIdentifier(null) clears identifier (no PII fallback)',
          () async {
            await realService.setUserIdentifier(
              '01ARZ3NDEKTSV4RRFFQ69G5FAV',
            ); // simulate login
            await realService.setUserIdentifier(null); // simulate logout
            verify(
              () => mockCrashlytics.setUserIdentifier(
                '01ARZ3NDEKTSV4RRFFQ69G5FAV',
              ),
            ).called(1);
            verify(() => mockCrashlytics.setUserIdentifier('')).called(1);
          },
        );

        test('AC4: no email or other PII shape in identifier', () async {
          await realService.setUserIdentifier('01ARZ3NDEKTSV4RRFFQ69G5FAV');
          final captured = verify(
            () => mockCrashlytics.setUserIdentifier(captureAny()),
          ).captured;
          final id = captured.single as String;
          expect(
            RegExp(r'^[0-9A-Z]*$').hasMatch(id),
            isTrue,
            reason: 'Identifier must be a plain ULID. Got: "$id"',
          );
          expect(id.contains('@'), isFalse);
        });
      });

      // AC5: Crash is reported even before any sign-in (no identifier set)
      test('AC5: errors are captured before any profile is selected', () async {
        // Identifier was never set — simulates pre-auth crash
        expect(service.lastIdentifier, isNull);
        await service.recordError(
          Exception('pre-auth crash'),
          StackTrace.current,
          fatal: true,
        );
        expect(service.errors, hasLength(1));
      });

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
          await nullService.setUserIdentifier('01ARZ3NDEKTSV4RRFFQ69G5FAV');
          await nullService.setUserIdentifier(null);
        },
      );
    },
  );
}

/// A capturing [CrashlyticsService] that records every call made to it, for
/// AC1/AC2/AC5 (collection toggling, error recording, pre-auth capture).
///
/// AUD-t-story-acceptance-21: [setUserIdentifier] is implemented only to
/// satisfy the [CrashlyticsService] interface and to let AC5 assert that no
/// identifier has been set yet (`lastIdentifier == null`) -- it is NOT used
/// to verify the PII-safe encoding itself. That verification exercises the
/// real [FirebaseCrashlyticsService] against a mocked [FirebaseCrashlytics]
/// in the "AC3/AC4" group above, so a divergence in the real encoding logic
/// cannot hide behind this fake's independent copy.
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
  Future<void> setUserIdentifier(String? profileId) async {
    lastIdentifier = profileId ?? '';
  }
}

/// Mocks the Firebase Crashlytics SDK type so the real
/// [FirebaseCrashlyticsService] implementation can be exercised in the
/// AC3/AC4 identifier tests above without a live Firebase app, per
/// AUD-t-story-acceptance-21 (mirrors the same pattern already used in
/// test/core/logging/crashlytics_service_test.dart).
class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}
