/// Unit tests for [MergeRouter]: dispatches a page of pulled rows to the
/// [EntityMerger] wired up for its `kind` in the constructor's `mergers`
/// map, halting the pull loop for a kind with no wired merger (a
/// configuration error) or a kind the exhaustive switch does not recognise
/// at all.
///
/// test/story_acceptance/epic_25_story_13_merge_router_test.dart also
/// exercises [MergeRouter] but is a story-acceptance suite (AG-5 exempt);
/// this file is the AG-5-mirrored unit-test home for
/// lib/core/sync/merge/merge_router.dart.
///
/// AG-5 (AUD-app-05): new file — no prior mirrored or unmirrored test
/// existed for this file specifically (only the exempt story-acceptance
/// suite referenced it).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';

class _FakeMerger implements EntityMerger {
  _FakeMerger(this.kind);

  @override
  final String kind;

  final List<List<Map<String, dynamic>>> calls = [];

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    calls.add(rows);
  }
}

void main() {
  group('MergeRouter.dispatch', () {
    test(
      'empty rows page returns continueNext without touching mergers',
      () async {
        final bookmark = _FakeMerger(EntityKind.bookmark);
        final router = MergeRouter(mergers: {EntityKind.bookmark: bookmark});

        final outcome = await router.dispatch(
          profileId: 1,
          kind: EntityKind.bookmark,
          rows: const [],
        );

        expect(outcome, MergeOutcome.continueNext);
        expect(bookmark.calls, isEmpty);
      },
    );

    test(
      'a recognised kind with a wired merger dispatches and returns continueNext',
      () async {
        final bookmark = _FakeMerger(EntityKind.bookmark);
        final router = MergeRouter(mergers: {EntityKind.bookmark: bookmark});
        final rows = [
          {'curriculum_id': 'bavli', 'sefaria_ref': 'Berakhot 2a'},
        ];

        final outcome = await router.dispatch(
          profileId: 7,
          kind: EntityKind.bookmark,
          rows: rows,
        );

        expect(outcome, MergeOutcome.continueNext);
        expect(bookmark.calls, [rows]);
      },
    );

    test(
      'a recognised kind with NO wired merger halts (configuration error)',
      () async {
        // EntityKind.goal is a real, recognised kind, but the router's
        // `mergers` map only has an entry for bookmark — this is the
        // "recognised but not wired up" branch.
        final router = MergeRouter(
          mergers: {EntityKind.bookmark: _FakeMerger(EntityKind.bookmark)},
        );

        final outcome = await router.dispatch(
          profileId: 1,
          kind: EntityKind.goal,
          rows: [
            {'curriculum_id': 'bavli'},
          ],
        );

        expect(outcome, MergeOutcome.halt);
      },
    );

    test('a completely unknown kind halts', () async {
      final router = MergeRouter(mergers: const {});

      final outcome = await router.dispatch(
        profileId: 1,
        kind: 'not_a_real_kind',
        rows: [
          {'x': 1},
        ],
      );

      expect(outcome, MergeOutcome.halt);
    });

    test('every EntityKind.all member is handled by the exhaustive switch '
        '(dispatches when wired, rather than falling to the unknown-kind '
        'halt branch for a lack-of-case reason)', () async {
      // Wire every kind to its own fake merger, then confirm each dispatch
      // reaches continueNext (i.e. the switch's case label exists for it —
      // if a future EntityKind were added without a case label, this test
      // would start failing with MergeOutcome.halt for that kind).
      final mergers = {
        for (final kind in EntityKind.all) kind: _FakeMerger(kind),
      };
      final router = MergeRouter(mergers: mergers);

      for (final kind in EntityKind.all) {
        final outcome = await router.dispatch(
          profileId: 1,
          kind: kind,
          rows: [
            {'k': 'v'},
          ],
        );
        expect(
          outcome,
          MergeOutcome.continueNext,
          reason: '"$kind" must have a case label in MergeRouter\'s switch',
        );
      }
    });
  });
}
