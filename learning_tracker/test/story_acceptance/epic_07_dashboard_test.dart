/// Story acceptance tests for Epic 7 -- Dashboard.
/// All 3 stories are backlog (skipped).
@Tags(['epic_7'])
library;

import 'package:test/test.dart';

void main() {
  // ── Story 7.1: Dashboard screen ───────────────────────────────

  group(
    'Story 7.1 -- Dashboard screen',
    tags: ['story_7_1'],
    skip: 'Backlog: dashboard screen not yet implemented',
    () {
      test('dashboard shows active curricula cards', () {
        // TODO: verify curriculum cards render for each active curriculum
      });

      test('tapping a curriculum card navigates to its content', () {
        // TODO: verify navigation
      });

      test('dashboard shows today\'s review count', () {
        // TODO: verify review count widget
      });
    },
  );

  // ── Story 7.2: Progress charts ────────────────────────────────

  group(
    'Story 7.2 -- Progress charts',
    tags: ['story_7_2'],
    skip: 'Backlog: progress charts not yet implemented',
    () {
      test('pie chart shows completion percentage per curriculum', () {
        // TODO: verify chart data matches completion records
      });

      test('line chart shows daily completions over time', () {
        // TODO: verify time-series chart
      });
    },
  );

  // ── Story 7.3: Daily summary ──────────────────────────────────

  group(
    'Story 7.3 -- Daily summary',
    tags: ['story_7_3'],
    skip: 'Backlog: daily summary not yet implemented',
    () {
      test('summary shows items completed today', () {
        // TODO: verify today filter on completions
      });

      test('summary shows points earned today', () {
        // TODO: verify points aggregation
      });
    },
  );
}
