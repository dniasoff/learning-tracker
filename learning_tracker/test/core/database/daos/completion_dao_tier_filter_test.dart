/// Regression tests for [CompletionDao.getCompletionsByTier] — guards the F14
/// defensive rewrite of the tier filter from a `LEFT JOIN
/// prior_completion_imports` pattern to correlated `EXISTS` / `NOT EXISTS`
/// subqueries.
///
/// ### Why this matters
///
/// Under normal operation the `prior_completion_imports` table holds at most
/// one row per natural-key 5-tuple `(profile_id, curriculum_id, sefaria_ref,
/// stage_id, track_type)`. But the schema has no UNIQUE constraint enforcing
/// that — a sync race, a buggy migration, or future schema work could plant
/// duplicate rows for the same natural key. Under the legacy LEFT JOIN
/// pattern that would surface as duplicate `Completion` rows with the same
/// `cv.id`, silently double-counting in downstream aggregates (siyumim,
/// lifetime totals).
///
/// To guarantee this can never happen again we seed TWO import rows for a
/// single completion event via `customStatement` (the DAO's
/// [batchInsertImports] also accepts duplicates today — the helper here uses
/// raw SQL so the seed reads as deliberate rather than incidental) and
/// assert the query still returns exactly ONE completion per event.
@Tags(['completion_dao', 'tier_filter'])
library;

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';

import '../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumId = 'mishnayos';

Future<int> _appendCompletionEvent(
  UserDatabase db, {
  required int trackId,
  required String sefariaRef,
  int stageId = 1,
  DateTime? at,
}) {
  return db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at ?? DateTime.utc(2026, 5, 14),
    ),
  );
}

/// Inserts a `prior_completion_imports` row via raw SQL so we can plant TWO
/// rows with the same natural key. The DAO's [batchInsertImports] would
/// reject the second row under the UNIQUE index; raw SQL with
/// `OR IGNORE` lifted reaches the underlying engine directly.
///
/// NOTE: a row inserted this way will collide with the UNIQUE index on most
/// Drift schema versions — but since we control the engine via
/// `NativeDatabase.memory()` we can probe the defensive contract: the
/// DAO must remain correct even if a second row somehow exists.
Future<void> _forceInsertDuplicateImport(
  UserDatabase db, {
  required String sefariaRef,
  required String source,
  int stageId = 1,
}) async {
  await db.customStatement(
    '''
INSERT INTO prior_completion_imports
  (profile_id, curriculum_id, sefaria_ref, stage_id, track_type, source, imported_at)
VALUES (?, ?, ?, ?, ?, ?, ?)
''',
    <Object?>[
      _profileId,
      _curriculumId,
      sefariaRef,
      stageId,
      'personal',
      source,
      DateTime.utc(2026, 5, 14).millisecondsSinceEpoch ~/ 1000,
    ],
  );
}

/// Counts rows in `prior_completion_imports` for a given natural key — used
/// by the seed precondition assertion so a future schema change that
/// re-enforces the UNIQUE index surfaces immediately as a test failure
/// (rather than the regression test silently becoming a tautology).
Future<int> _countImportsForRef(
  UserDatabase db, {
  required String sefariaRef,
}) async {
  final rows = await db.customSelect(
    '''
SELECT COUNT(*) AS n FROM prior_completion_imports
WHERE profile_id = ?
  AND curriculum_id = ?
  AND sefaria_ref = ?
''',
    variables: [
      Variable.withInt(_profileId),
      Variable.withString(_curriculumId),
      Variable.withString(sefariaRef),
    ],
  ).get();
  return rows.first.read<int>('n');
}

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
    );
  });

  tearDown(() => db.close());

  group(
    'getCompletionsByTier — no double-counting on duplicate import rows',
    () {
      test(
        'liveOnly returns ONE completion when imports table has TWO matching '
        'rows for the same completion event',
        () async {
          // One live completion event. Live means: NO matching row in
          // prior_completion_imports. We will then force TWO rows in (which
          // makes it bulkInTrack from the predicate's perspective) — the
          // liveOnly filter must exclude this event exactly once.
          await _appendCompletionEvent(
            db,
            trackId: trackId,
            sefariaRef: 'Berakhot 1',
          );
          // Add a second event that we WANT to be live (no imports row).
          await _appendCompletionEvent(
            db,
            trackId: trackId,
            sefariaRef: 'Berakhot 2',
          );

          // Plant TWO import rows for "Berakhot 1" via raw SQL — both with
          // source=bulkInTrack so the natural key matches twice.
          await _forceInsertDuplicateImport(
            db,
            sefariaRef: 'Berakhot 1',
            source: 'bulkInTrack',
          );
          await _forceInsertDuplicateImport(
            db,
            sefariaRef: 'Berakhot 1',
            source: 'bulkInTrack',
          );

          // Precondition: there really are two import rows for that key.
          // (If a future schema change re-enforces the UNIQUE index this
          // assertion will trip and the test must be revisited.)
          expect(
            await _countImportsForRef(db, sefariaRef: 'Berakhot 1'),
            2,
            reason: 'seed produced two import rows for Berakhot 1',
          );

          final liveCompletions = await db.completionDao.getCompletionsByTier(
            profileId: _profileId,
            tier: CompletionTierFilter.liveOnly,
          );

          // The live-only set must contain ONLY "Berakhot 2" — exactly once.
          // The defensive EXISTS pattern guarantees one membership decision
          // per parent row, so duplicate import rows can't ever multiply
          // the parent.
          expect(liveCompletions, hasLength(1));
          expect(liveCompletions.single.sefariaRef, 'Berakhot 2');
        },
      );

      test(
        'trackAchievement returns ONE completion (not two) when imports '
        'table has TWO bulkInTrack rows for the same completion event',
        () async {
          // One completion event that we want to be credited as
          // trackAchievement via bulkInTrack.
          await _appendCompletionEvent(
            db,
            trackId: trackId,
            sefariaRef: 'Shabbat 1',
          );

          // Plant TWO bulkInTrack import rows so a duplicate would surface
          // as TWO joined rows under the legacy LEFT JOIN pattern.
          await _forceInsertDuplicateImport(
            db,
            sefariaRef: 'Shabbat 1',
            source: 'bulkInTrack',
          );
          await _forceInsertDuplicateImport(
            db,
            sefariaRef: 'Shabbat 1',
            source: 'bulkInTrack',
          );

          expect(
            await _countImportsForRef(db, sefariaRef: 'Shabbat 1'),
            2,
            reason: 'seed produced two import rows for Shabbat 1',
          );

          final completions = await db.completionDao.getCompletionsByTier(
            profileId: _profileId,
            tier: CompletionTierFilter.trackAchievement,
          );

          expect(
            completions,
            hasLength(1),
            reason:
                'EXISTS predicate must return exactly one completion '
                'regardless of how many matching import rows exist',
          );
          expect(completions.single.sefariaRef, 'Shabbat 1');
        },
      );

      test(
        'lifetime tier is unaffected by duplicates (no join performed)',
        () async {
          await _appendCompletionEvent(
            db,
            trackId: trackId,
            sefariaRef: 'Pesachim 1',
          );
          await _forceInsertDuplicateImport(
            db,
            sefariaRef: 'Pesachim 1',
            source: 'lifetimeOnly',
          );
          await _forceInsertDuplicateImport(
            db,
            sefariaRef: 'Pesachim 1',
            source: 'lifetimeOnly',
          );

          final completions = await db.completionDao.getCompletionsByTier(
            profileId: _profileId,
            tier: CompletionTierFilter.lifetime,
          );

          // The lifetime tier intentionally does NOT join the imports
          // table — it returns every completion event row. Duplicate
          // imports must therefore have zero effect on the result.
          expect(completions, hasLength(1));
          expect(completions.single.sefariaRef, 'Pesachim 1');
        },
      );
    },
  );

  group('getCompletionsByTier — baseline (no duplicates)', () {
    test('liveOnly returns events with NO matching import', () async {
      await _appendCompletionEvent(
        db,
        trackId: trackId,
        sefariaRef: 'A',
      );
      await _appendCompletionEvent(
        db,
        trackId: trackId,
        sefariaRef: 'B',
      );
      // B is bulk-in-track — should be excluded from liveOnly.
      await _forceInsertDuplicateImport(
        db,
        sefariaRef: 'B',
        source: 'bulkInTrack',
      );

      final live = await db.completionDao.getCompletionsByTier(
        profileId: _profileId,
        tier: CompletionTierFilter.liveOnly,
      );
      expect(live.map((c) => c.sefariaRef).toList(), ['A']);
    });

    test('trackAchievement includes live + bulkInTrack, excludes lifetimeOnly',
        () async {
      await _appendCompletionEvent(
        db,
        trackId: trackId,
        sefariaRef: 'live_x',
      );
      await _appendCompletionEvent(
        db,
        trackId: trackId,
        sefariaRef: 'bulk_y',
      );
      await _appendCompletionEvent(
        db,
        trackId: trackId,
        sefariaRef: 'lifetime_z',
      );
      await _forceInsertDuplicateImport(
        db,
        sefariaRef: 'bulk_y',
        source: 'bulkInTrack',
      );
      await _forceInsertDuplicateImport(
        db,
        sefariaRef: 'lifetime_z',
        source: 'lifetimeOnly',
      );

      final achievement = await db.completionDao.getCompletionsByTier(
        profileId: _profileId,
        tier: CompletionTierFilter.trackAchievement,
      );
      final refs = achievement.map((c) => c.sefariaRef).toSet();
      expect(refs, {'live_x', 'bulk_y'});
      expect(refs.contains('lifetime_z'), isFalse);
    });
  });
}
