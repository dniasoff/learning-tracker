/// Story acceptance tests for Epic 13 -- Cloud Sync.
/// All 3 stories are backlog (skipped).
@Tags(['epic_13'])
library;

import 'package:test/test.dart';

void main() {
  // ── Story 13.1: Multi-device sync ─────────────────────────────

  group(
    'Story 13.1 -- Multi-device sync',
    tags: ['story_13_1'],
    skip: 'Backlog: multi-device sync UI not yet implemented',
    () {
      test('completions sync across devices via Firestore', () {
        // TODO: verify SyncEngine push/pull round-trip
      });

      test('offline changes queue and sync on reconnect', () {
        // TODO: verify OfflineQueue flush behaviour
      });

      test('sync status indicator shows current state', () {
        // TODO: verify SyncStatus widget rendering
      });
    },
  );

  // ── Story 13.2: Conflict resolution UI ────────────────────────

  group(
    'Story 13.2 -- Conflict resolution UI',
    tags: ['story_13_2'],
    skip: 'Backlog: conflict resolution UI not yet implemented',
    () {
      test('conflicting edits show resolution dialog', () {
        // TODO: verify conflict detection and dialog
      });

      test('last-write-wins is the default resolution', () {
        // TODO: verify LWW merge strategy
      });
    },
  );

  // ── Story 13.3: Backup & restore ──────────────────────────────

  group(
    'Story 13.3 -- Backup & restore',
    tags: ['story_13_3'],
    skip: 'Backlog: backup and restore not yet implemented',
    () {
      test('user can export a full database backup', () {
        // TODO: verify export produces valid JSON
      });

      test('user can restore from a backup file', () {
        // TODO: verify restore overwrites local data
      });
    },
  );
}
