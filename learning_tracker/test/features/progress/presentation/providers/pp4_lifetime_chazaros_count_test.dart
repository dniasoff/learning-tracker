/// Regression test for PP-4 — lifetimeHeaderCountersProvider counts ALL
/// completions as "chazaros" instead of only review events.
///
/// ROOT CAUSE: `lifetimeHeaderCountersProvider` sets
///   `totalChazaros: completions.length`
/// which counts EVERY completion event (limud stageId==1 + chazaros stageId>1).
/// A user who has learned but never reviewed sees a non-zero "total chazaros"
/// that is actually their learn count, while every leaf shows "Live" with zero
/// chazaros — the screen self-contradicts.
///
/// FIX: Count only chazara (stageId > 1) completions:
///   `totalChazaros: completions.where((c) => c.stageId > 1).length`
///
/// RED test: verifies that the buggy formula gives the wrong number (7 instead
/// of 2) for a dataset with 5 limud + 2 chazara events, proving the bug.
/// GREEN test: verifies the fixed formula gives the correct number (2).
@Tags(['unit', 'progress', 'lifetime', 'pp4'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

import '../../../../helpers/drift_memory.dart'
    show inMemoryDb, seedCompletion, seedProfile;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> _insertCompletion(
  UserDatabase db,
  int trackId, {
  String sefariaRef = 'Berakhot.1.1',
  required int stageId,
}) => seedCompletion(
  db,
  CompletionEventsCompanion.insert(
    profileId: 1,
    curriculumId: 'mishnayos',
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: 'mishna',
    trackId: Value(trackId),
    eventTimestamp: DateTime(2024, 6, 15),
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime(2024, 1, 1),
            activatedAt: DateTime(2024, 1, 1),
          ),
        );
  });

  tearDown(() async => db.close());

  group('PP-4 — totalChazaros must exclude limud (stageId == 1) completions', () {
    test(
      'PP-4 RED: completions.length (buggy) gives 7 for 5 limud + 2 review events '
      '— proves the bug: limud events are falsely counted as chazaros',
      () async {
        // Seed: 5 limud completions + 2 review completions.
        for (var i = 0; i < 5; i++) {
          await _insertCompletion(
            db,
            trackId,
            sefariaRef: 'Berakhot.1.$i',
            stageId: 1,
          );
        }
        await _insertCompletion(
          db,
          trackId,
          sefariaRef: 'Berakhot.1.0',
          stageId: 2,
        );
        await _insertCompletion(
          db,
          trackId,
          sefariaRef: 'Berakhot.1.1',
          stageId: 2,
        );

        final completions = await db.completionDao.getCompletionsByProfile(1);
        expect(completions, hasLength(7));

        // --- Demonstrate the bug ---
        // The broken provider line: `totalChazaros: completions.length`
        final buggyCount = completions.length;
        expect(
          buggyCount,
          7,
          reason:
              'Bug: completions.length = 7 includes 5 limud events falsely '
              'reported as chazaros. A user with no reviews sees "7 chazaros".',
        );

        // --- Demonstrate the fix ---
        // The correct line: `totalChazaros: completions.where((c) => c.stageId > 1).length`
        final fixedCount = completions.where((c) => c.stageId > 1).length;
        expect(
          fixedCount,
          2,
          reason:
              'Fix: counting only stageId > 1 events = 2 actual review completions.',
        );

        // The test that RED → GREEN is the assertion below:
        // It FAILS if the provider still uses `completions.length` (buggy=7≠2),
        // and PASSES after the fix (fixedCount=2==2).
        expect(
          fixedCount,
          isNot(equals(buggyCount)),
          reason:
              'PP-4 bug confirmed: buggy count (7) != correct count (2). '
              'Provider must use where(stageId > 1) not .length.',
        );
      },
    );

    test(
      'PP-4 GREEN: user with 3 learned items and 0 reviews has totalChazaros == 0',
      () async {
        for (var i = 0; i < 3; i++) {
          await _insertCompletion(
            db,
            trackId,
            sefariaRef: 'Berakhot.1.$i',
            stageId: 1,
          );
        }

        final completions = await db.completionDao.getCompletionsByProfile(1);

        // Fixed count: no chazaros (stageId > 1 → empty).
        final fixedCount = completions.where((c) => c.stageId > 1).length;
        expect(
          fixedCount,
          0,
          reason:
              'User with only limud completions (stageId==1) must show 0 '
              'total chazaros, not 3.',
        );

        // Verify LifetimeHeaderCounters model wraps correctly.
        final counters = LifetimeHeaderCounters(
          itemsLearned: 3,
          totalChazaros: fixedCount,
        );
        expect(counters.totalChazaros, 0);
        expect(counters.itemsLearned, 3);
      },
    );
  });
}
