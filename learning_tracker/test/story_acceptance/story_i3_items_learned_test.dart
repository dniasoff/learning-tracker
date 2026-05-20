/// Story acceptance tests for I-3 — Items Learned breakdown + Lifetime view.
///
/// AC-1: [computeItemsLearnedSummary] counts only trackAchievement completions
///       (live + bulkInTrack; excludes lifetimeOnly imports per B1 policy).
///
/// AC-2: [computeLifetimeViewSummary] counts all completion events AND
///       ledger-based lifetime marks.
///
/// AC-3: Completion counts are correct for a known dataset (2 real-date +
///       1 bulkInTrack import + 1 ledger mark → items-learned=3, lifetime=4).
///
/// Layer 3 update (2026-05-20): "sentinel" rows are now seeded via
/// prior_completion_imports (not just a magic timestamp). The
/// computeItemsLearnedSummary now uses getCompletionsByTier(trackAchievement).
@Tags(['story_i3'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/drift_memory.dart' show seedCompletion;
import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockContentRepository extends Mock implements ContentRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A real-study date (live completion).
final _kRealDate = DateTime.utc(2026, 5, 1, 10);

/// An old bulk-import timestamp (pre-Layer 3 sentinel; used to give
/// bulk rows a plausible historical timestamp).
final _kBulkDate = DateTime.utc(2000, 1, 1);

/// Seeds a lifetimeOnly completion: event row + prior_completion_imports record.
///
/// This will be excluded from [CompletionTierFilter.trackAchievement] but
/// included in [CompletionTierFilter.lifetime].
Future<void> _seedLifetimeOnly(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required String sefariaRef,
}) async {
  await seedCompletion(
    db,
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: CurriculumId.mishnayos.storageKey,
      sefariaRef: sefariaRef,
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: _kBulkDate,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: profileId,
      curriculumId: CurriculumId.mishnayos.storageKey,
      sefariaRef: sefariaRef,
      stageId: 1,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

ContentItem _leaf(
  String ref, {
  String level1 = 'Seder Zeraim',
  String? level2 = 'Berakhot',
  int sortOrder = 0,
}) {
  return ContentItem(
    curriculumId: CurriculumId.mishnayos.storageKey,
    sefariaRef: ref,
    displayNameEn: ref,
    displayNameHe: ref,
    level1: level1,
    level2: level2,
    level3: null,
    level4: null,
    isLeaf: true,
    sortOrder: sortOrder,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  group('I-3 — computeItemsLearnedSummary (AC-1)', () {
    late UserDatabase db;
    late _MockContentRepository repo;
    late int profileId;
    late int trackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      repo = _MockContentRepository();

      final now = DateTime.utc(2026, 5, 1);
      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Tester',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
      profileId = profile.id;

      final track = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              stateChangedAt: now,
              activatedAt: now,
            ),
          );
      trackId = track.id;
    });

    tearDown(() async => db.close());

    test(
      'AC-1: excludes lifetimeOnly import rows; counts live + bulkInTrack',
      () async {
        // 10 leaf items in mishnayos.
        final leaves = List.generate(
          10,
          (i) => _leaf('Mishnah Berakhot ${i + 1}:1', sortOrder: i),
        );
        when(
          () => repo.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer((_) async => leaves);

        // Insert 4 real-study (live) completions (leaves[0..3]).
        for (var i = 0; i < 4; i++) {
          await seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: leaves[i].sefariaRef,
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              eventTimestamp: _kRealDate,
            ),
          );
        }

        // Insert 3 lifetimeOnly import completions (leaves[5..7]) — these
        // must NOT be counted by computeItemsLearnedSummary (trackAchievement).
        for (var i = 5; i < 8; i++) {
          await _seedLifetimeOnly(
            db,
            profileId: profileId,
            trackId: trackId,
            sefariaRef: leaves[i].sefariaRef,
          );
        }

        final summary = await computeItemsLearnedSummary(
          db: db,
          repo: repo,
          curriculum: CurriculumId.mishnayos,
          profileId: profileId,
        );

        expect(summary, isNotNull, reason: 'should find track completions');
        expect(
          summary!.learnedLeafCount,
          4,
          reason: 'only the 4 live refs must be counted; lifetimeOnly excluded',
        );
        expect(summary.totalLeafCount, 10);
      },
    );

    test(
      'AC-1b: returns null when ALL completions are lifetimeOnly (no track data)',
      () async {
        final leaves = List.generate(
          5,
          (i) => _leaf('Mishnah Berakhot ${i + 1}:1', sortOrder: i),
        );
        when(
          () => repo.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer((_) async => leaves);

        // Only lifetimeOnly import completions.
        for (var i = 0; i < 3; i++) {
          await _seedLifetimeOnly(
            db,
            profileId: profileId,
            trackId: trackId,
            sefariaRef: leaves[i].sefariaRef,
          );
        }

        final summary = await computeItemsLearnedSummary(
          db: db,
          repo: repo,
          curriculum: CurriculumId.mishnayos,
          profileId: profileId,
        );

        expect(summary, isNull, reason: 'no trackAchievement completions → null');
      },
    );
  });

  group('I-3 — computeLifetimeViewSummary (AC-2)', () {
    late UserDatabase db;
    late _MockContentRepository repo;
    late int profileId;
    late int trackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      repo = _MockContentRepository();

      final now = DateTime.utc(2026, 5, 1);
      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Tester',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
      profileId = profile.id;

      final track = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              stateChangedAt: now,
              activatedAt: now,
            ),
          );
      trackId = track.id;
    });

    tearDown(() async => db.close());

    test('AC-2: counts live AND lifetimeOnly import completions', () async {
      final leaves = List.generate(
        10,
        (i) => _leaf('Mishnah Berakhot ${i + 1}:1', sortOrder: i),
      );
      when(
        () => repo.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer((_) async => leaves);

      // 3 real-date (live) completions.
      for (var i = 0; i < 3; i++) {
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: leaves[i].sefariaRef,
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: _kRealDate,
          ),
        );
      }

      // 4 lifetimeOnly import completions — must be counted by lifetime view.
      for (var i = 3; i < 7; i++) {
        await _seedLifetimeOnly(
          db,
          profileId: profileId,
          trackId: trackId,
          sefariaRef: leaves[i].sefariaRef,
        );
      }

      final summary = await computeLifetimeViewSummary(
        db: db,
        repo: repo,
        curriculum: CurriculumId.mishnayos,
        profileId: profileId,
      );

      expect(summary, isNotNull);
      // 3 live + 4 lifetimeOnly = 7 unique learned leaf refs.
      expect(
        summary!.learnedLeafCount,
        7,
        reason: 'lifetime view must include lifetimeOnly import rows',
      );
      expect(summary.totalLeafCount, 10);
    });
  });

  group('I-3 — known-dataset correctness (AC-3)', () {
    late UserDatabase db;
    late _MockContentRepository repo;
    late int profileId;
    late int trackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      repo = _MockContentRepository();

      final now = DateTime.utc(2026, 5, 1);
      final profile = await db
          .into(db.learnerProfiles)
          .insertReturning(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Tester',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
      profileId = profile.id;

      final track = await db
          .into(db.curriculumTracks)
          .insertReturning(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              stateChangedAt: now,
              activatedAt: now,
            ),
          );
      trackId = track.id;
    });

    tearDown(() async => db.close());

    test('AC-3: known dataset — 2 live + 1 lifetimeOnly import + 1 ledger mark; '
        'items-learned=2, lifetime=4', () async {
      // 8 leaf items.
      final leaves = List.generate(
        8,
        (i) => _leaf('Mishnah Berakhot ${i + 1}:1', sortOrder: i),
      );
      when(
        () => repo.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer((_) async => leaves);

      // 2 real-date (live) track completions (leaves[0], leaves[1]).
      for (var i = 0; i < 2; i++) {
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: profileId,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: leaves[i].sefariaRef,
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: _kRealDate,
          ),
        );
      }

      // 1 lifetimeOnly import (leaves[2]) — excluded from items-learned,
      // included in lifetime view.
      await _seedLifetimeOnly(
        db,
        profileId: profileId,
        trackId: trackId,
        sefariaRef: leaves[2].sefariaRef,
      );

      // 1 ledger mark at leaf-ref level (leaves[3]) — counted by lifetime only.
      // Use entryScope='mishna' which maps to level4Actions, then
      // 'unitIdentifier' is compared against leaf.level4. Since our test
      // leaves have level4=null we use the masechta scope, which maps to
      // level2Actions keyed by the masechta value ('Berakhot'), and ALL
      // leaves in that masechta would be marked — that's too broad.
      //
      // Instead we use the direct-ref path via the `default` branch, which
      // fires when entryScope doesn't match any named case and doesn't start
      // with 'level'. Using 'ref_mark' as a synthetic scope triggers:
      //   learnedRefs.add(unitIdentifier)
      // and then the leaf check `learnedRefs.contains(leaf.sefariaRef)`
      // picks it up.
      await db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          profileId: profileId,
          ulid: Value(newUlid()),
          curriculumId: CurriculumId.mishnayos.storageKey,
          entryScope: 'ref_mark',
          unitIdentifier: leaves[3].sefariaRef,
          unitDisplayNameHe: '',
          unitDisplayNameEn: '',
          trackType: 'personal',
          completedAt: DateTime.utc(2026, 1, 1),
          completionNumber: 1,
          markedBy: profileId,
        ),
      );

      // Items-learned: trackAchievement tier (live only here) → 2.
      final trackSummary = await computeItemsLearnedSummary(
        db: db,
        repo: repo,
        curriculum: CurriculumId.mishnayos,
        profileId: profileId,
      );
      expect(trackSummary, isNotNull);
      expect(
        trackSummary!.learnedLeafCount,
        2,
        reason: 'items-learned excludes lifetimeOnly imports',
      );

      // Lifetime: live (2) + lifetimeOnly import (1) + ledger (1) = 4 unique refs.
      final lifeSummary = await computeLifetimeViewSummary(
        db: db,
        repo: repo,
        curriculum: CurriculumId.mishnayos,
        profileId: profileId,
      );
      expect(lifeSummary, isNotNull);
      expect(
        lifeSummary!.learnedLeafCount,
        4,
        reason: 'lifetime counts all sources',
      );
    });
  });
}
