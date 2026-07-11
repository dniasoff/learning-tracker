// Regression test for loop-iter2: feature-layer syncStatusProvider loading
// state must return orchestrator.currentStatus (not SyncStatus.syncing) when
// the broadcast stream has no pending event and a late subscriber attaches.
//
// The bug: sync_providers.dart:47 returned
//   `SyncStatus.syncing(startedAt: DateTimeFactory.nowLocal())`
// when asyncStatus is AsyncLoading.  A late subscriber (e.g. navigating to a
// screen AFTER pullOnLaunch already completed) attaches to a broadcast stream
// with no buffered events; Riverpod's StreamProvider enters the loading state
// and this provider returned a spurious "Syncing…" instead of the actual
// current status ("Synced", "Offline", etc.).
//
// Fix: replace `loading: () => SyncStatus.syncing(...)` with
//      `loading: () => orchestrator.currentStatus`
// mirroring the core-layer canonical provider in
// `core/sync/providers/sync_status_providers.dart`.
//
// RED before fix: the loading branch returns syncing instead of currentStatus.
// GREEN after fix: the loading branch delegates to orchestrator.currentStatus.
@Tags(['l1', 'sync', 'regression'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrchestrator extends Mock implements SyncOrchestrator {}

void main() {
  group('feature-layer syncStatusProvider — loading state must use '
      'orchestrator.currentStatus (loop-iter2 regression)', () {
    // Verify the RED path first: if loading returns syncing, the test would
    // fail because we expect the status to match currentStatus, not syncing.
    // After fix (loading: () => orchestrator.currentStatus) it goes GREEN.

    test('when statusStream is empty (late subscriber), provider returns '
        'orchestrator.currentStatus, not SyncStatus.syncing', () {
      final syncedStatus = SyncStatus.synced(
        lastSyncedAt: DateTime(2026, 6, 9),
      );
      final mockOrch = _MockOrchestrator();
      // The orchestrator's currentStatus is "synced" (pull already ran).
      when(() => mockOrch.currentStatus).thenReturn(syncedStatus);
      // statusStream has no buffered events — late subscriber sees loading.
      when(() => mockOrch.statusStream).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [syncOrchestratorProvider.overrideWith((_) => mockOrch)],
      );
      addTearDown(container.dispose);

      // Read syncStatusProvider — the stream is loading (no buffered event).
      // The provider MUST return currentStatus (synced), not syncing.
      final status = container.read(syncStatusProvider);

      expect(
        status,
        equals(syncedStatus),
        reason:
            'feature-layer syncStatusProvider must return '
            'orchestrator.currentStatus when the status stream has no '
            'buffered event, not a spurious SyncStatus.syncing',
      );
      // Verify it is NOT syncing (the buggy behaviour).
      expect(
        status,
        isNot(isA<SyncStatusSyncing>()),
        reason:
            'A late subscriber must not see a Syncing flash when the '
            'pull already completed and the stream has no pending event',
      );
    });

    test('when statusStream is empty and currentStatus is offline, provider '
        'returns offline (not syncing)', () {
      const offlineStatus = SyncStatus.offline(pendingChanges: 3);
      final mockOrch = _MockOrchestrator();
      when(() => mockOrch.currentStatus).thenReturn(offlineStatus);
      when(() => mockOrch.statusStream).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [syncOrchestratorProvider.overrideWith((_) => mockOrch)],
      );
      addTearDown(container.dispose);

      final status = container.read(syncStatusProvider);

      expect(
        status,
        equals(offlineStatus),
        reason:
            'Offline status must be preserved across a broadcast-stream '
            're-subscribe, not replaced by a syncing flash',
      );
      expect(status, isNot(isA<SyncStatusSyncing>()));
    });

    test(
      'when orchestrator is null, provider returns localOnly regardless',
      () {
        final container = ProviderContainer(
          overrides: [syncOrchestratorProvider.overrideWith((_) => null)],
        );
        addTearDown(container.dispose);

        final status = container.read(syncStatusProvider);
        expect(status, isA<SyncStatusLocalOnly>());
      },
    );
  });
}
