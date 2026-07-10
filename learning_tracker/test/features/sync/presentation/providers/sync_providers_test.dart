// Regression test for SM-4 (AUD-sync-04): outboxDrainAndRecordAttempt's
// second ref.read (recordDrainAttempt) must never touch a torn-down ref.
//
// ROOT CAUSE: syncWriteFacadeProvider/outboxSyncWriteFacadeProvider's shared
// onEnqueueDrain closure did:
//   await (ref.read(outboxProcessorProvider)?.drain(profileId) ?? ...);
//   await ref.read(syncOrchestratorProvider)?.recordDrainAttempt();
// with no `ref.mounted` guard between the two awaits. Both providers watch
// activeProfileIdProvider/authStateProvider, so a profile switch or
// sign-out arriving mid-drain rebuilds the provider — disposing the OLD
// `ref` — and the second `ref.read` above throws UnmountedRefException on
// that stale ref.
//
// FIX: `outboxDrainAndRecordAttempt` (lib/features/sync/presentation/
// providers/sync_providers.dart) checks `ref.mounted` after the first await
// and returns early (skipping recordDrainAttempt) if the ref was torn down.
//
// This test exercises `outboxDrainAndRecordAttempt` directly against a real
// ProviderContainer (not a fake Ref) so UnmountedRefException — a real
// Riverpod 3 framework exception — is exercised for real, not simulated.
@Tags(['unit', 'sync', 'sm4', 'regression'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockOutboxProcessor extends Mock implements OutboxProcessor {}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  group('outboxDrainAndRecordAttempt (SM-4 / AUD-sync-04)', () {
    late _MockOutboxProcessor mockProcessor;
    late _MockSyncOrchestrator mockOrchestrator;
    late Completer<int> drainCompleter;

    setUp(() {
      mockProcessor = _MockOutboxProcessor();
      mockOrchestrator = _MockSyncOrchestrator();
      drainCompleter = Completer<int>();
      when(
        () => mockProcessor.drain(any()),
      ).thenAnswer((_) => drainCompleter.future);
      when(
        () => mockOrchestrator.recordDrainAttempt(),
      ).thenAnswer((_) async {});
    });

    test('container disposed mid-drain (profile switch/sign-out): the second '
        'ref.read does not throw UnmountedRefException, and '
        'recordDrainAttempt is safely skipped', () async {
      final container = ProviderContainer(
        overrides: [
          outboxProcessorProvider.overrideWithValue(mockProcessor),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
        ],
      );

      // Capture a real Ref sourced from this container (the same kind of
      // Ref a Provider<T>((ref) {...}) closure would capture).
      late Ref capturedRef;
      final hostProvider = Provider<void>((ref) {
        capturedRef = ref;
      });
      container.read(hostProvider);

      // Start the drain — this synchronously does the first ref.read
      // (outboxProcessorProvider) and then suspends on the drain future.
      final resultFuture = outboxDrainAndRecordAttempt(capturedRef, 7);

      // Simulate a profile switch/sign-out tearing this provider tree down
      // WHILE the drain's network round trip is still in flight.
      container.dispose();
      expect(
        capturedRef.mounted,
        isFalse,
        reason:
            'container.dispose() must tear down the captured ref — '
            'this is the exact staleness this test simulates',
      );

      // Let the in-flight drain settle now that the ref is torn down.
      drainCompleter.complete(3);

      // The core assertion: no UnmountedRefException (or any exception)
      // reaches the caller.
      await expectLater(resultFuture, completes);

      // And recordDrainAttempt must never have been called against the
      // stale ref.
      verifyNever(() => mockOrchestrator.recordDrainAttempt());
    });

    test('ref still mounted when the drain settles: recordDrainAttempt '
        'completes normally', () async {
      final container = ProviderContainer(
        overrides: [
          outboxProcessorProvider.overrideWithValue(mockProcessor),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
        ],
      );
      addTearDown(container.dispose);

      late Ref capturedRef;
      final hostProvider = Provider<void>((ref) {
        capturedRef = ref;
      });
      container.read(hostProvider);

      final resultFuture = outboxDrainAndRecordAttempt(capturedRef, 7);

      // No teardown this time — the ref stays mounted throughout.
      drainCompleter.complete(3);
      await expectLater(resultFuture, completes);

      verify(() => mockOrchestrator.recordDrainAttempt()).called(1);
    });
  });
}
