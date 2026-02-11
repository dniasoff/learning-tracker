/// Story acceptance tests for Epic 8 -- Gamification.
/// All 3 stories are backlog (skipped).
@Tags(['epic_8'])
library;

import 'package:test/test.dart';

void main() {
  // ── Story 8.1: Points system ──────────────────────────────────

  group(
    'Story 8.1 -- Points system',
    tags: ['story_8_1'],
    skip: 'Backlog: points system not yet implemented',
    () {
      test('completing a content item awards points', () {
        // TODO: verify points column on Completions table
      });

      test('points vary by stage (later stages worth more)', () {
        // TODO: verify point scaling
      });

      test('total points aggregated across all curricula', () {
        // TODO: verify sum query
      });
    },
  );

  // ── Story 8.2: Rewards & badges ───────────────────────────────

  group(
    'Story 8.2 -- Rewards & badges',
    tags: ['story_8_2'],
    skip: 'Backlog: rewards and badges not yet implemented',
    () {
      test('reward is revealed when point threshold reached', () {
        // TODO: verify isRevealed flag flips
      });

      test('reward is earned when user claims it', () {
        // TODO: verify isEarned flag
      });

      test('curriculum-specific rewards filter correctly', () {
        // TODO: verify curriculumId filter on Rewards table
      });
    },
  );

  // ── Story 8.3: Child mode animations ──────────────────────────

  group(
    'Story 8.3 -- Child mode animations',
    tags: ['story_8_3'],
    skip: 'Backlog: child mode animations not yet implemented',
    () {
      test('child mode shows celebratory animation on completion', () {
        // TODO: verify animation widget renders in child UserMode
      });

      test('adult mode shows subtle confirmation instead', () {
        // TODO: verify no animation in adult UserMode
      });
    },
  );
}
