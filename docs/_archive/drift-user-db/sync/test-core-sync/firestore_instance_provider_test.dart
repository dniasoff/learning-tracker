/// Regression tests for [resetFirestoreNetwork] (AUD-core-sync-14).
///
/// Nygard-lens: `resetFirestoreNetwork()` disables then re-enables the
/// Firestore network with no guard. If `enableNetwork()` throws AFTER
/// `disableNetwork()` already succeeded (plugin-channel error, terminated
/// instance, or exactly the flaky-network condition this helper exists to
/// recover from), the failure must be caught and logged rather than
/// propagating unhandled — and it must not derail whatever sequence awaited
/// it, in particular the lifecycle-resume chain
/// (`redetectTimezone` → `invalidateSacredCache` → `triggerPull`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/lifecycle_observer.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────
// Mocking the Firestore SDK type directly mirrors the established pattern in
// test/core/auth/firebase_auth_gateway_impl_test.dart — this file exercises
// the real `resetFirestoreNetwork()` production function against a stubbed
// FirebaseFirestore instead of duplicating its logic.
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseFirestore mockFirestore;
  late Talker talker;
  late AppLogger logger;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    talker = Talker();
    logger = AppLogger(talker);
  });

  group('resetFirestoreNetwork — error handling (AUD-core-sync-14)', () {
    test(
      'catches and logs when enableNetwork() throws after disableNetwork() succeeds',
      () async {
        when(() => mockFirestore.disableNetwork()).thenAnswer((_) async {});
        when(
          () => mockFirestore.enableNetwork(),
        ).thenThrow(Exception('channel busy'));

        // Must complete normally — the failure is swallowed, not propagated.
        await resetFirestoreNetwork(firestore: mockFirestore, logger: logger);

        verify(() => mockFirestore.disableNetwork()).called(1);
        verify(() => mockFirestore.enableNetwork()).called(1);
        expect(
          talker.history.any(
            (e) => e.generateTextMessage().contains(
              'sync_firestore_network_reset_failed',
            ),
          ),
          isTrue,
          reason: 'the enableNetwork() failure must be logged via AppLogger',
        );
      },
    );

    test('also catches and logs when disableNetwork() itself throws', () async {
      when(
        () => mockFirestore.disableNetwork(),
      ).thenThrow(Exception('disable failed'));

      await expectLater(
        resetFirestoreNetwork(firestore: mockFirestore, logger: logger),
        completes,
      );

      verifyNever(() => mockFirestore.enableNetwork());
      expect(
        talker.history.any(
          (e) => e.generateTextMessage().contains(
            'sync_firestore_network_reset_failed',
          ),
        ),
        isTrue,
      );
    });

    test('logs nothing when both calls succeed', () async {
      when(() => mockFirestore.disableNetwork()).thenAnswer((_) async {});
      when(() => mockFirestore.enableNetwork()).thenAnswer((_) async {});

      await resetFirestoreNetwork(firestore: mockFirestore, logger: logger);

      expect(talker.history, isEmpty);
    });
  });

  group('LifecycleObserver resume sequence survives a reset failure '
      '(AUD-core-sync-14)', () {
    test('timezone redetect, sacred-cache invalidation, and resume pull '
        'still run after enableNetwork() throws', () async {
      when(() => mockFirestore.disableNetwork()).thenAnswer((_) async {});
      when(() => mockFirestore.enableNetwork()).thenThrow(Exception('boom'));

      final calls = <String>[];
      final observer = LifecycleObserver(
        resetFirestoreNetwork: () =>
            resetFirestoreNetwork(firestore: mockFirestore, logger: logger),
        redetectTimezone: () async => calls.add('tz'),
        invalidateSacredCache: () async => calls.add('cache'),
        triggerPull: () async => calls.add('pull'),
      );

      // A non-resumed event first, so the observer treats the following
      // resume as a real foreground return (cold-start resumes skip the
      // Firestore reset entirely).
      await observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      await observer.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(
        calls,
        equals(['tz', 'cache', 'pull']),
        reason:
            'a failed Firestore reset must not abort the rest of the '
            'resume sequence',
      );
      expect(
        talker.history.any(
          (e) => e.generateTextMessage().contains(
            'sync_firestore_network_reset_failed',
          ),
        ),
        isTrue,
        reason: 'the reset failure must still be logged',
      );
    });
  });
}
