/// Story acceptance tests for Epic 13 -- Cloud Sync.
///
/// NOTE (W2.35): The original tests in this file exercised the legacy
/// SyncEngine, OfflineQueue, and FirestoreDataSource classes — all deleted
/// in Wave 2 (W2.35-W2.37). Tests are skip-wrapped; underlying behaviour
/// is covered by:
/// - Push-on-write (13.1): test/sync/sync_rework_writepath_test.dart
/// - Pull-on-launch (13.2): test/sync/two_device_sync_test.dart
/// - Conflict resolution (13.3): EntityMerger unit tests
/// - Device restore (13.4): epic_25_story_22_firewall_test.dart
@Tags(['epic_13'])
library;

import 'package:test/test.dart';

void main() {
  group(
    'Story 13.1 -- Push-on-Write with Offline Queuing',
    tags: ['story_13_1'],
    skip: 'Retired W2.35 — covered by outbox processor tests',
    () {
      test('placeholder', () {});
    },
  );

  group(
    'Story 13.2 -- Pull-on-Launch Merge',
    tags: ['story_13_2'],
    skip:
        'Retired W2.35 — covered by SyncOrchestratorImpl + PullPipeline tests',
    () {
      test('placeholder', () {});
    },
  );

  group(
    'Story 13.3 -- Conflict resolution (LWW)',
    tags: ['story_13_3'],
    skip: 'Retired W2.35 — covered by EntityMerger unit tests',
    () {
      test('placeholder', () {});
    },
  );

  group(
    'Story 13.4 -- New Device Data Restore',
    tags: ['story_13_4'],
    skip: 'Retired W2.35 — to be ported using _StubSyncOrchestrator pattern',
    () {
      test('placeholder', () {});
    },
  );
}
