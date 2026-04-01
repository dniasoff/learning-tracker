import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

void main() {
  group('SyncStatus', () {
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

    group('pending', () {
      test('creates pending status with pendingChanges', () {
        const status = SyncStatus.pending(pendingChanges: 3);

        final result = status.maybeWhen(
          pending: (pendingChanges) {
            expect(pendingChanges, equals(3));
            return true;
          },
          orElse: () => false,
        );

        expect(result, isTrue);
      });

      test('allows zero pending changes', () {
        const status = SyncStatus.pending(pendingChanges: 0);

        final result = status.maybeWhen(
          pending: (pendingChanges) {
            expect(pendingChanges, equals(0));
            return true;
          },
          orElse: () => false,
        );

        expect(result, isTrue);
      });
    });

    group('offline', () {
      test('creates offline status with pendingChanges', () {
        const status = SyncStatus.offline(pendingChanges: 5);

        final result = status.maybeWhen(
          offline: (pendingChanges) {
            expect(pendingChanges, equals(5));
            return true;
          },
          orElse: () => false,
        );

        expect(result, isTrue);
      });

      test('allows zero pending changes', () {
        const status = SyncStatus.offline(pendingChanges: 0);

        final result = status.maybeWhen(
          offline: (pendingChanges) {
            expect(pendingChanges, equals(0));
            return true;
          },
          orElse: () => false,
        );

        expect(result, isTrue);
      });
    });

    group('error', () {
      test('creates error status with message and failedAt', () {
        final now = DateTime.now();
        final status = SyncStatus.error(
          message: 'Network error',
          failedAt: now,
        );

        final result = status.maybeWhen(
          error: (message, failedAt) {
            expect(message, equals('Network error'));
            expect(failedAt, equals(now));
            return true;
          },
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

      test('pending and offline are different types', () {
        const pending = SyncStatus.pending(pendingChanges: 3);
        const offline = SyncStatus.offline(pendingChanges: 3);

        expect(pending, isNot(equals(offline)));
      });
    });

    group('pattern matching', () {
      test('when method works correctly', () {
        final status = SyncStatus.syncing(startedAt: DateTime.now());

        final result = status.when(
          localOnly: () => 'localOnly',
          syncing: (_) => 'syncing',
          synced: (_) => 'synced',
          pending: (_) => 'pending',
          offline: (_) => 'offline',
          error: (_, __) => 'error',
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

      test('when handles pending state', () {
        const status = SyncStatus.pending(pendingChanges: 2);

        final result = status.when(
          localOnly: () => 'localOnly',
          syncing: (_) => 'syncing',
          synced: (_) => 'synced',
          pending: (count) => 'pending:$count',
          offline: (_) => 'offline',
          error: (_, __) => 'error',
        );

        expect(result, equals('pending:2'));
      });

      test('Dart 3 switch expression works', () {
        const status = SyncStatus.pending(pendingChanges: 5);

        final label = switch (status) {
          SyncStatusLocalOnly() => 'localOnly',
          SyncStatusSyncing() => 'syncing',
          SyncStatusSynced() => 'synced',
          SyncStatusPending(:final pendingChanges) => 'pending:$pendingChanges',
          SyncStatusOffline() => 'offline',
          SyncStatusError() => 'error',
        };

        expect(label, equals('pending:5'));
      });
    });
  });
}
