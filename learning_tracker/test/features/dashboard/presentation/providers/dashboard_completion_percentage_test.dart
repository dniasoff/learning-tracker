/// Unit tests for the item-based completion logic used by
/// [dashboardTrackCompletionPercentageProvider] and
/// [dashboardCompletionPercentageProvider].
///
/// The algorithm is exercised as a pure function so no database or Riverpod
/// container is required.  The logic under test:
///   • An item is "done" only when ALL required stageIds have a completion.
///   • An item with only the learn stage done (but chazara stages still
///     outstanding) is NOT complete.
///   • An item with no chazara stages configured needs only learn.
///   • percentage = doneItems / totalItems  (no stage multiplier).
library;

import 'package:flutter_test/flutter_test.dart';

// ── Helper that mirrors the provider logic ─────────────────────────────────

/// Returns the fraction of [totalItems] that are fully done according to
/// [completedStagesByRef] and [requiredStageIds].
///
/// This is the identical algorithm used inside
/// [dashboardTrackCompletionPercentageProvider].
double _computeTrackCompletion({
  required Map<String, Set<int>> completedStagesByRef,
  required Set<int> requiredStageIds,
  required int totalItems,
}) {
  if (totalItems == 0) return 0.0;
  if (requiredStageIds.isEmpty) return 0.0;
  final doneItems = completedStagesByRef.values
      .where((done) => requiredStageIds.every(done.contains))
      .length;
  return (doneItems / totalItems).clamp(0.0, 1.0);
}

/// Returns the fraction of [totalItems] that are "done" across all tracks.
///
/// This mirrors the per-curriculum logic in
/// [dashboardCompletionPercentageProvider]: an item (sefariaRef) counts once
/// as done if it is fully complete in ANY of its tracks.
double _computeCurriculumCompletion({
  // trackId → sefariaRef → Set<stageId>
  required Map<int, Map<String, Set<int>>> byTrack,
  // trackId → Set<requiredStageIds>
  required Map<int, Set<int>> requiredStagesByTrack,
  required int totalItems,
}) {
  if (totalItems == 0) return 0.0;
  final doneRefs = <String>{};
  for (final entry in byTrack.entries) {
    final trackId = entry.key;
    if (trackId == 0) continue; // bulk-mark sentinel
    final requiredStageIds = requiredStagesByTrack[trackId];
    if (requiredStageIds == null || requiredStageIds.isEmpty) continue;
    for (final refEntry in entry.value.entries) {
      if (requiredStageIds.every(refEntry.value.contains)) {
        doneRefs.add(refEntry.key);
      }
    }
  }
  return (doneRefs.length / totalItems).clamp(0.0, 1.0);
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // Stage IDs used throughout the tests.
  const learnStageId = 1;
  const chazara1StageId = 2;
  const chazara2StageId = 3;

  // ── Track-level logic ─────────────────────────────────────────────────────

  group('dashboardTrackCompletionPercentage — item-based rule', () {
    // Track with 3 required stages: learn + 2 chazaras.
    const requiredStages = {learnStageId, chazara1StageId, chazara2StageId};

    test('0.0 when no completions exist', () {
      final pct = _computeTrackCompletion(
        completedStagesByRef: {},
        requiredStageIds: requiredStages,
        totalItems: 10,
      );
      expect(pct, 0.0);
    });

    test('0.0 when totalItems is 0', () {
      final pct = _computeTrackCompletion(
        completedStagesByRef: {
          'ref/1': {learnStageId, chazara1StageId, chazara2StageId},
        },
        requiredStageIds: requiredStages,
        totalItems: 0,
      );
      expect(pct, 0.0);
    });

    test('item is NOT done when only learn stage is completed', () {
      // Learn done but chazaras outstanding → should NOT count.
      final pct = _computeTrackCompletion(
        completedStagesByRef: {
          'ref/1': {learnStageId}, // only learn
        },
        requiredStageIds: requiredStages,
        totalItems: 5,
      );
      expect(pct, 0.0, reason: 'item missing chazara stages must not be done');
    });

    test('item is NOT done when only learn + one chazara is completed', () {
      final pct = _computeTrackCompletion(
        completedStagesByRef: {
          'ref/1': {learnStageId, chazara1StageId}, // chazara2 missing
        },
        requiredStageIds: requiredStages,
        totalItems: 5,
      );
      expect(pct, 0.0, reason: 'chazara2 still outstanding — not done');
    });

    test('item IS done when ALL required stages are completed', () {
      final pct = _computeTrackCompletion(
        completedStagesByRef: {
          'ref/1': {learnStageId, chazara1StageId, chazara2StageId},
        },
        requiredStageIds: requiredStages,
        totalItems: 5,
      );
      expect(pct, 1 / 5);
    });

    test('item with no chazara configured needs only learn to be done', () {
      // Track configured with learn-only (stageOrder 1 only).
      const learnOnly = {learnStageId};
      final pct = _computeTrackCompletion(
        completedStagesByRef: {
          'ref/1': {learnStageId},
        },
        requiredStageIds: learnOnly,
        totalItems: 4,
      );
      expect(pct, 1 / 4, reason: 'learn-only track: item is done after learn');
    });

    test('counts only fully-done items out of many', () {
      // 2 done, 1 partial, 1 untouched, 1 not in completedStagesByRef.
      final pct = _computeTrackCompletion(
        completedStagesByRef: {
          'ref/1': {learnStageId, chazara1StageId, chazara2StageId}, // done
          'ref/2': {learnStageId, chazara1StageId, chazara2StageId}, // done
          'ref/3': {learnStageId}, // learn only — not done
          'ref/4': {learnStageId, chazara1StageId}, // partial — not done
          // ref/5 not started
        },
        requiredStageIds: requiredStages,
        totalItems: 5,
      );
      expect(pct, 2 / 5);
    });

    test('result is clamped to 1.0 when more completions than items', () {
      // Edge case: completions > totalItems (e.g. scope narrowed after completion).
      final pct = _computeTrackCompletion(
        completedStagesByRef: {
          'ref/1': {learnStageId, chazara1StageId, chazara2StageId},
          'ref/2': {learnStageId, chazara1StageId, chazara2StageId},
          'ref/3': {learnStageId, chazara1StageId, chazara2StageId},
        },
        requiredStageIds: requiredStages,
        totalItems: 2,
      );
      expect(pct, 1.0);
    });
  });

  // ── Curriculum-level logic ─────────────────────────────────────────────────

  group(
    'dashboardCompletionPercentage — item-based rule (curriculum-wide)',
    () {
      test('0.0 when no completions exist', () {
        final pct = _computeCurriculumCompletion(
          byTrack: {},
          requiredStagesByTrack: {},
          totalItems: 10,
        );
        expect(pct, 0.0);
      });

      test('bulk-mark sentinel (trackId 0) is excluded', () {
        final pct = _computeCurriculumCompletion(
          byTrack: {
            0: {
              'ref/1': {learnStageId},
            },
          },
          requiredStagesByTrack: {
            0: {learnStageId},
          },
          totalItems: 5,
        );
        expect(
          pct,
          0.0,
          reason: 'trackId 0 is a bulk-mark sentinel; must not count',
        );
      });

      test('item done in one track counts once even if in multiple tracks', () {
        // Same sefariaRef appears in track 1 (all done) and track 2 (partial).
        final pct = _computeCurriculumCompletion(
          byTrack: {
            1: {
              'ref/shared': {
                learnStageId,
                chazara1StageId,
              }, // all done for 2-stage track
            },
            2: {
              'ref/shared': {learnStageId}, // partial in track 2
            },
          },
          requiredStagesByTrack: {
            1: {learnStageId, chazara1StageId},
            2: {learnStageId, chazara1StageId, chazara2StageId},
          },
          totalItems: 4,
        );
        // ref/shared is done in track 1, so it counts once.
        expect(pct, 1 / 4);
      });

      test('item only counted once even if done in two different tracks', () {
        final pct = _computeCurriculumCompletion(
          byTrack: {
            1: {
              'ref/a': {learnStageId}, // done in learn-only track
            },
            2: {
              'ref/a': {
                learnStageId,
                chazara1StageId,
              }, // also done in 2-stage track
            },
          },
          requiredStagesByTrack: {
            1: {learnStageId},
            2: {learnStageId, chazara1StageId},
          },
          totalItems: 10,
        );
        // ref/a is done in both tracks — counted only once.
        expect(pct, 1 / 10);
      });

      test('correct fraction when mix of done and partial items', () {
        final pct = _computeCurriculumCompletion(
          byTrack: {
            1: {
              'ref/1': {learnStageId, chazara1StageId}, // done
              'ref/2': {learnStageId}, // partial — missing chazara1
              'ref/3': {learnStageId, chazara1StageId}, // done
            },
          },
          requiredStagesByTrack: {
            1: {learnStageId, chazara1StageId},
          },
          totalItems: 5,
        );
        expect(pct, 2 / 5);
      });
    },
  );
}
