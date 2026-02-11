/// Story acceptance tests for Epic 5 -- Stages & Order.
/// All 2 stories are backlog (skipped).
@Tags(['epic_5'])
library;

import 'package:test/test.dart';

void main() {
  // ── Story 5.1: Custom stage definitions ───────────────────────

  group(
    'Story 5.1 -- Custom stage definitions',
    tags: ['story_5_1'],
    skip: 'Backlog: custom stage editor not yet implemented',
    () {
      test('user can add a custom chazara stage', () {
        // TODO: verify stage insertion via StageDao
      });

      test('user can reorder stages', () {
        // TODO: verify stageOrder update
      });

      test('user can adjust delay days for a stage', () {
        // TODO: verify delayDays update
      });
    },
  );

  // ── Story 5.2: Custom learning order ──────────────────────────

  group(
    'Story 5.2 -- Custom learning order',
    tags: ['story_5_2'],
    skip: 'Backlog: custom learning order not yet implemented',
    () {
      test('user can reorder content items within a curriculum', () {
        // TODO: verify LearningOrderDao reorder
      });

      test('custom order persists across sessions', () {
        // TODO: verify order survives database close/reopen
      });
    },
  );
}
