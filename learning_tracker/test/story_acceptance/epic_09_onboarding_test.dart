/// Story acceptance tests for Epic 9 -- Onboarding.
/// All 5 stories are backlog (skipped).
@Tags(['epic_9'])
library;

import 'package:test/test.dart';

void main() {
  // ── Story 9.1: Welcome flow ───────────────────────────────────

  group(
    'Story 9.1 -- Welcome flow',
    tags: ['story_9_1'],
    skip: 'Backlog: welcome flow not yet implemented',
    () {
      test('first launch shows welcome screen', () {
        // TODO: verify welcome screen appears for new users
      });

      test('welcome screen offers sign-in options', () {
        // TODO: verify email, Google, and passwordless options
      });
    },
  );

  // ── Story 9.2: Curriculum selection ───────────────────────────

  group(
    'Story 9.2 -- Curriculum selection',
    tags: ['story_9_2'],
    skip: 'Backlog: onboarding curriculum selection not yet implemented',
    () {
      test('user selects at least one curriculum during onboarding', () {
        // TODO: verify curriculum selection persists
      });

      test('all 5 curricula are shown as options', () {
        // TODO: verify all CurriculumId values displayed
      });
    },
  );

  // ── Story 9.3: User mode selection ────────────────────────────

  group(
    'Story 9.3 -- User mode selection',
    tags: ['story_9_3'],
    skip: 'Backlog: user mode selection not yet implemented',
    () {
      test('user chooses child or adult mode', () {
        // TODO: verify UserMode selection persists
      });

      test('mode selection affects gamification display', () {
        // TODO: verify UX changes per mode
      });
    },
  );

  // ── Story 9.4: Import existing progress ───────────────────────

  group(
    'Story 9.4 -- Import existing progress',
    tags: ['story_9_4'],
    skip: 'Backlog: progress import not yet implemented',
    () {
      test('user can import progress from a backup file', () {
        // TODO: verify import from JSON/backup
      });

      test('imported completions appear in progress view', () {
        // TODO: verify imported data is queryable
      });
    },
  );

  // ── Story 9.5: Tutorial walkthrough ───────────────────────────

  group(
    'Story 9.5 -- Tutorial walkthrough',
    tags: ['story_9_5'],
    skip: 'Backlog: tutorial walkthrough not yet implemented',
    () {
      test('tutorial highlights key features step by step', () {
        // TODO: verify tutorial overlay sequence
      });

      test('user can skip tutorial', () {
        // TODO: verify skip button exits tutorial
      });
    },
  );
}
