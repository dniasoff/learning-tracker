/// Story acceptance tests for Epic 14 -- Settings.
/// All 4 stories are backlog (skipped).
@Tags(['epic_14'])
library;

import 'package:test/test.dart';

void main() {
  // ── Story 14.1: Settings screen ───────────────────────────────

  group(
    'Story 14.1 -- Settings screen',
    tags: ['story_14_1'],
    skip: 'Backlog: settings screen not yet implemented',
    () {
      test('settings screen displays all preference categories', () {
        // TODO: verify settings screen structure
      });

      test('user can change user mode (child/adult)', () {
        // TODO: verify mode toggle persists
      });

      test('user can manage active curricula from settings', () {
        // TODO: verify curriculum activation from settings
      });
    },
  );

  // ── Story 14.2: Data export ───────────────────────────────────

  group(
    'Story 14.2 -- Data export',
    tags: ['story_14_2'],
    skip: 'Backlog: data export not yet implemented',
    () {
      test('user can export completions as CSV', () {
        // TODO: verify CSV export content
      });

      test('export includes all curricula and tracks', () {
        // TODO: verify completeness of export
      });
    },
  );

  // ── Story 14.3: Account management ────────────────────────────

  group(
    'Story 14.3 -- Account management',
    tags: ['story_14_3'],
    skip: 'Backlog: account management not yet implemented',
    () {
      test('user can sign out', () {
        // TODO: verify sign-out clears session
      });

      test('user can delete account and all data', () {
        // TODO: verify account deletion cascade
      });
    },
  );

  // ── Story 14.4: App info & legal ──────────────────────────────

  group(
    'Story 14.4 -- App info & legal',
    tags: ['story_14_4'],
    skip: 'Backlog: app info screen not yet implemented',
    () {
      test('about screen shows app version', () {
        // TODO: verify version string display
      });

      test('privacy policy and terms links are accessible', () {
        // TODO: verify link navigation
      });
    },
  );
}
