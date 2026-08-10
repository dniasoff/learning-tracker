// Story 1.5 / AD-11: SyncStatus was collapsed from a 7-case union
// (localOnly/syncing/synced/pending/offline/error/degraded) to exactly
// localOnly | syncing | synced | offline. These tests pin the surviving
// shape; the removed states (pending/error/degraded) and their
// `pendingChanges` bookkeeping must not compile back in — see
// sync_status_no_removed_states_test.dart-equivalent coverage below via
// exhaustive switch (a non-exhaustive switch over SyncStatus fails to
// compile, which is itself a standing guard against a state being silently
// re-added).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

void main() {
  group('SyncStatus', () {
    group('localOnly', () {
      test('creates the localOnly state', () {
        const status = SyncStatus.localOnly();
        expect(status, isA<SyncStatusLocalOnly>());
      });
    });

    group('syncing', () {
      test('creates syncing status with startedAt', () {
        final now = DateTime.now();
        final status = SyncStatus.syncing(startedAt: now);

        final result = status.maybeWhen(
          syncing: (startedAt) {
            expect(startedAt, equals(now));
            return true;
          },
          orElse: () => false,
        );

        expect(result, isTrue);
      });
    });

    group('synced', () {
      test('creates synced status with lastSyncedAt', () {
        final now = DateTime.now();
        final status = SyncStatus.synced(lastSyncedAt: now);

        final result = status.maybeWhen(
          synced: (lastSyncedAt) {
            expect(lastSyncedAt, equals(now));
            return true;
          },
          orElse: () => false,
        );

        expect(result, isTrue);
      });
    });

    group('offline', () {
      test('creates the offline state with no pendingChanges field', () {
        // Story 1.5 / AD-11: offline carries no count at all — the status
        // chip only ever answers "is the network up", never "how many rows
        // are queued".
        const status = SyncStatus.offline();

        final result = status.maybeWhen(
          offline: () => true,
          orElse: () => false,
        );

        expect(result, isTrue);
      });
    });

    group('equality', () {
      test('same syncing statuses are equal', () {
        final now = DateTime.now();
        final status1 = SyncStatus.syncing(startedAt: now);
        final status2 = SyncStatus.syncing(startedAt: now);

        expect(status1, equals(status2));
      });

      test('different syncing statuses are not equal', () {
        final now = DateTime.now();
        final later = now.add(const Duration(seconds: 1));
        final status1 = SyncStatus.syncing(startedAt: now);
        final status2 = SyncStatus.syncing(startedAt: later);

        expect(status1, isNot(equals(status2)));
      });

      test('different status types are not equal', () {
        final now = DateTime.now();
        final syncing = SyncStatus.syncing(startedAt: now);
        final synced = SyncStatus.synced(lastSyncedAt: now);

        expect(syncing, isNot(equals(synced)));
      });

      test('offline and localOnly are different types', () {
        const offline = SyncStatus.offline();
        const localOnly = SyncStatus.localOnly();

        expect(offline, isNot(equals(localOnly)));
      });
    });

    group('pattern matching', () {
      test('when method works correctly', () {
        final status = SyncStatus.syncing(startedAt: DateTime.now());

        // Exhaustive switch: if a removed state (pending/error/degraded) were
        // ever re-added without updating every call site, this `when` call
        // would fail to compile until a matching case is supplied here too —
        // a standing guard that the union stays collapsed to exactly four
        // cases.
        final result = status.when(
          localOnly: () => 'localOnly',
          syncing: (_) => 'syncing',
          synced: (_) => 'synced',
          offline: () => 'offline',
        );

        expect(result, equals('syncing'));
      });

      test('maybeWhen provides default case', () {
        final status = SyncStatus.syncing(startedAt: DateTime.now());

        final result = status.maybeWhen(
          synced: (_) => 'synced',
          orElse: () => 'other',
        );

        expect(result, equals('other'));
      });

      test('when handles offline state', () {
        const status = SyncStatus.offline();

        final result = status.when(
          localOnly: () => 'localOnly',
          syncing: (_) => 'syncing',
          synced: (_) => 'synced',
          offline: () => 'offline',
        );

        expect(result, equals('offline'));
      });

      test('Dart 3 switch expression works', () {
        const status = SyncStatus.offline();

        final label = switch (status) {
          SyncStatusLocalOnly() => 'localOnly',
          SyncStatusSyncing() => 'syncing',
          SyncStatusSynced() => 'synced',
          SyncStatusOffline() => 'offline',
        };

        expect(label, equals('offline'));
      });
    });
  });
}
