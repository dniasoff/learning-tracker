/// Story acceptance tests for Epic 10 -- Parent Mode.
/// All 6 stories are backlog (skipped).
@Tags(['epic_10'])
library;

import 'package:test/test.dart';

void main() {
  // ── Story 10.1: Parent PIN setup ──────────────────────────────

  group(
    'Story 10.1 -- Parent PIN setup',
    tags: ['story_10_1'],
    skip: 'Backlog: parent PIN setup UI not yet implemented',
    () {
      test('parent can set a 4-digit PIN', () {
        // TODO: verify PIN setup flow via PinService
      });

      test('PIN entry screen prompts on parent mode access', () {
        // TODO: verify ParentPinGuard triggers PIN prompt
      });
    },
  );

  // ── Story 10.2: Parent dashboard ──────────────────────────────

  group(
    'Story 10.2 -- Parent dashboard',
    tags: ['story_10_2'],
    skip: 'Backlog: parent dashboard not yet implemented',
    () {
      test('parent dashboard shows child progress summary', () {
        // TODO: verify parent view of child completions
      });

      test('parent can view per-curriculum progress', () {
        // TODO: verify curriculum breakdown view
      });
    },
  );

  // ── Story 10.3: Content restrictions ──────────────────────────

  group(
    'Story 10.3 -- Content restrictions',
    tags: ['story_10_3'],
    skip: 'Backlog: content restrictions not yet implemented',
    () {
      test('parent can restrict specific curricula', () {
        // TODO: verify content hiding/locking
      });

      test('restricted content is hidden from child view', () {
        // TODO: verify filtering in content repository
      });
    },
  );

  // ── Story 10.4: Time limits ───────────────────────────────────

  group(
    'Story 10.4 -- Time limits',
    tags: ['story_10_4'],
    skip: 'Backlog: time limits not yet implemented',
    () {
      test('parent can set daily time limits', () {
        // TODO: verify time limit configuration
      });

      test('app locks after time limit reached', () {
        // TODO: verify lock screen appears
      });
    },
  );

  // ── Story 10.5: Progress reports ──────────────────────────────

  group(
    'Story 10.5 -- Progress reports',
    tags: ['story_10_5'],
    skip: 'Backlog: parent progress reports not yet implemented',
    () {
      test('weekly summary report generated for parent', () {
        // TODO: verify report generation
      });

      test('report can be exported or shared', () {
        // TODO: verify export functionality
      });
    },
  );

  // ── Story 10.6: Multi-child profiles ──────────────────────────

  group(
    'Story 10.6 -- Multi-child profiles',
    tags: ['story_10_6'],
    skip: 'Backlog: multi-child profiles not yet implemented',
    () {
      test('parent can create multiple child profiles', () {
        // TODO: verify profile creation via UserProfileDao
      });

      test('each child has independent progress', () {
        // TODO: verify per-profile scoping
      });

      test('parent can switch between child views', () {
        // TODO: verify profile switching UI
      });
    },
  );
}
