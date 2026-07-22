/// Integration tests for Bug B6 and Bug B8.
///
/// B6 — Prior-marking writes learn + ALL chazara stages.
///   Given a track with 3 stages (learn, chazara 1, chazara 2),
///   when [BulkPriorCompletionService.execute] is called with stageIds: [1],
///   then completion_events rows must exist for stages 1, 2, and 3 for each
///   marked item (not just stage 1).
///
/// B8 — Expunge API tombstones the correct rows.
///   Given prior-completion records for a sefariaRef (sentinel
///   eventTimestamp = DateTime.utc(2000,1,1)),
///   when [BulkPriorCompletionService.expungePriorCompletions] is called,
///   then all sentinel-dated rows for that ref have purgedAt set (C3 tombstone)
///   and live-learning rows (non-sentinel timestamps) are NOT touched.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../fixtures/content_fixtures.dart';
import '../helpers/fake_clock.dart';

// ── Minimal stubs ────────────────────────────────────────────────────────────

/// Content repo stub — returns whatever items are injected via the factory.
class _StubContentRepository implements ContentRepository {
  final List<ContentItem> items;
  _StubContentRepository(this.items);

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => items;

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => const CurriculumHierarchyConfig(
    curriculumId: 'mishnayos',
    levelLabels: [],
    totalItems: 0,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => const [];

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => null;
}

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Inserts a prior-mark completion into BOTH [completion_events] AND
/// [prior_completion_imports], mirroring the production path in
/// [CompletionWriter.commitBatch] when [priorMarkOnly] = true.
///
/// The [expungePriorCompletions] method identifies which rows to tombstone by
/// querying [prior_completion_imports]; seeding only [completion_events] would
/// make expunge a no-op (W4.26 / B8 fix). Tests that bypass
/// [BulkPriorCompletionService.execute] must call this helper instead of
/// inserting directly into [completion_events].
Future<void> _insertPriorMark(
  UserDatabase db, {
  required int profileId,
  required String curriculumId,
  required String sefariaRef,
  required int stageId,
  required int trackId,
  String trackType = 'personal',
  int points = 0,
}) async {
  final sentinel = kBulkPriorSentinelDate;
  await db
      .into(db.completionEvents)
      .insert(
        CompletionEventsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          trackId: Value(trackId),
          points: Value(points),
          eventTimestamp: sentinel,
        ),
      );
  await db
      .into(db.priorCompletionImports)
      .insert(
        PriorCompletionImportsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          source: 'bulkInTrack',
        ),
      );
}

ContentItem _leaf(String ref, int sortOrder) => ContentItemFixtures.leaf(
  curriculumId: 'mishnayos',
  level1: 'Zeraim',
  sefariaRef: ref,
  sortOrder: sortOrder,
  displayNameHe: ref,
  displayNameEn: ref,
);

/// Seeds a minimal account + learner profile + curriculum track.
/// Returns (profileId, trackId).
Future<({int profileId, int trackId})> _seedProfileAndTrack(
  UserDatabase db,
) async {
  final now = DateTimeFactory.nowUtc();

  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test',
          createdAt: now,
          updatedAt: now,
        ),
      );

  final profileId = await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );

  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          stateChangedAt: now,
          activatedAt: now,
        ),
      );

  return (profileId: profileId, trackId: trackId);
}

/// Seeds [count] stage definitions (stageOrder 1..count) for the given
/// profile + track + curriculum.
Future<void> _seedStages(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required int count,
}) async {
  for (var i = 1; i <= count; i++) {
    await db
        .into(db.stageDefinitions)
        .insert(
          StageDefinitionsCompanion.insert(
            profileId: profileId,
            curriculumId: 'mishnayos',
            trackId: trackId,
            stageOrder: i,
            stageName: i == 1 ? 'Learn' : 'Chazara $i',
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
        );
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;
  late int profileId;
  late int trackId;

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    final seeded = await _seedProfileAndTrack(db);
    profileId = seeded.profileId;
    trackId = seeded.trackId;
  });

  tearDown(() async {
    await db.close();
  });

  // ── B6 ────────────────────────────────────────────────────────────────────

  group('B6 — execute writes all configured stages for prior-marked items', () {
    test('AC1: 2 items × 3 configured stages → 6 completion_events rows '
        'even when caller passes stageIds: [1]', () async {
      await _seedStages(db, profileId: profileId, trackId: trackId, count: 3);

      final items = [_leaf('ref_a', 0), _leaf('ref_b', 1)];
      final bookmarkRepo = MockBookmarkRepository();
      when(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => _fakeBookmark());

      final completionRepo = CompletionRepositoryImpl(
        database: db,
        syncEngine: null,
        contentRepository: _StubContentRepository([...items]),
        activeProfileId: profileId,
      );

      final stageRepo = StageDefinitionRepositoryImpl(
        stageDao: db.stageDao,
        completionDao: db.completionDao,
        pushStageDefinitions: null,
      );

      final service = BulkPriorCompletionService(
        contentRepository: _StubContentRepository([...items]),
        completionRepository: completionRepo,
        bookmarkRepository: bookmarkRepo,
        database: db,
        syncEngine: null,
        stageRepository: stageRepo,
      );

      final result = await service.execute(
        curriculumId: CurriculumId.mishnayos,
        resolvedItems: items,
        stageIds: [1], // caller passes only learn — B6 must add chazara 2 & 3
        profileId: profileId,
      );

      // 2 items × 3 stages = 6 total completions.
      expect(
        result.completionCount,
        6,
        reason: 'B6: 2 items × 3 stages must produce 6 completion records',
      );

      // Verify all 3 stages are present in completion_events for each item.
      final events = await db.completionDao.getCompletionsByProfile(profileId);
      final stagesByRef = <String, Set<int>>{};
      for (final e in events) {
        stagesByRef.putIfAbsent(e.sefariaRef, () => {}).add(e.stageId);
      }
      expect(stagesByRef['ref_a'], containsAll([1, 2, 3]));
      expect(stagesByRef['ref_b'], containsAll([1, 2, 3]));
    });

    // AUD-t-cross-63: the former "AC3" test (plus its _seedStagesWithSuperseded
    // helper) asserted that a stage seeded as "superseded" was excluded from
    // bulk-mark-prior. W3.29 dropped the `supersededAt` column entirely
    // (lifecycle is now managed via `state`), so the helper could no longer
    // create a row the service would treat as superseded — the test had
    // degraded into re-proving AC1's "N stages => N completions" under a
    // misleading name. Removed rather than repurposed: AC1 above already
    // covers "all configured stages receive completion_events" for this
    // service, so no coverage is lost.

    test('AC2: completion_events for all stages carry the sentinel timestamp '
        '(DateTime.utc(2000, 1, 1)) — not today', () async {
      await _seedStages(db, profileId: profileId, trackId: trackId, count: 2);

      final items = [_leaf('ref_x', 0)];
      final bookmarkRepo = MockBookmarkRepository();
      when(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => _fakeBookmark());

      final completionRepo = CompletionRepositoryImpl(
        database: db,
        syncEngine: null,
        contentRepository: _StubContentRepository([...items]),
        activeProfileId: profileId,
      );
      final stageRepo = StageDefinitionRepositoryImpl(
        stageDao: db.stageDao,
        completionDao: db.completionDao,
        pushStageDefinitions: null,
      );
      final service = BulkPriorCompletionService(
        contentRepository: _StubContentRepository([...items]),
        completionRepository: completionRepo,
        bookmarkRepository: bookmarkRepo,
        database: db,
        syncEngine: null,
        stageRepository: stageRepo,
      );

      await service.execute(
        curriculumId: CurriculumId.mishnayos,
        resolvedItems: items,
        stageIds: [1],
        profileId: profileId,
      );

      final events = await (db.select(
        db.completionEvents,
      )..where((t) => t.sefariaRef.equals('ref_x'))).get();

      // Every event must carry the sentinel timestamp.
      // Compare by millisecondsSinceEpoch to avoid UTC vs. local
      // DateTime mismatch introduced by SQLite's DATETIME column type.
      final sentinelMs = kBulkPriorSentinelDate.millisecondsSinceEpoch;
      for (final e in events) {
        expect(
          e.eventTimestamp.millisecondsSinceEpoch,
          equals(sentinelMs),
          reason:
              'Prior-marking rows must use the sentinel date '
              '(DateTime.utc(2000,1,1) = ${sentinelMs}ms), '
              'got ${e.eventTimestamp}',
        );
      }
    });
  });

  // ── B8 ────────────────────────────────────────────────────────────────────

  group('B8 — expungePriorCompletions tombstones only sentinel-dated rows', () {
    test(
      'AC1: sets purgedAt on all sentinel-dated rows for the given sefariaRef',
      () async {
        // Insert 3 prior-mark rows into BOTH completion_events AND
        // prior_completion_imports (W4.26: expunge reads the import table).
        for (var stage = 1; stage <= 3; stage++) {
          await _insertPriorMark(
            db,
            profileId: profileId,
            curriculumId: 'mishnayos',
            sefariaRef: 'ref_target',
            stageId: stage,
            trackId: trackId,
          );
        }

        final bookmarkRepo = MockBookmarkRepository();
        final service = BulkPriorCompletionService(
          contentRepository: _StubContentRepository(const []),
          completionRepository: CompletionRepositoryImpl(
            database: db,
            syncEngine: null,
            contentRepository: _StubContentRepository(const []),
            activeProfileId: profileId,
          ),
          bookmarkRepository: bookmarkRepo,
          database: db,
          syncEngine: null,
        );

        // AUD-t-cross-39: pin the LocalDayClock seam that
        // expungePriorCompletions reads purgedAt from
        // (DateTimeFactory.nowUtc() -> core/time/local_day_clock.dart) to a
        // fixed instant, so purgedAt can be asserted exactly instead of via
        // a wall-clock before/after window (a real, if narrow, flake
        // surface under slow/loaded CI).
        final fixedNow = DateTime.utc(2026, 3, 1, 12, 0, 0);
        installFakeClock(fixedNow);

        await service.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'ref_target',
          curriculumId: CurriculumId.mishnayos,
        );

        final events = await (db.select(
          db.completionEvents,
        )..where((t) => t.sefariaRef.equals('ref_target'))).get();

        // All 3 rows must be tombstoned.
        expect(events, hasLength(3));
        // Compare by millisecondsSinceEpoch to avoid UTC vs. local DateTime
        // mismatch introduced by SQLite's DATETIME column type (same
        // pattern used elsewhere in this file, e.g. the B6 AC2 sentinel
        // check above).
        final fixedNowMs = fixedNow.millisecondsSinceEpoch;
        for (final e in events) {
          expect(
            e.purgedAt,
            isNotNull,
            reason: 'Prior-mark row (stage ${e.stageId}) must be tombstoned',
          );
          // purgedAt must equal the pinned clock instant exactly.
          expect(
            e.purgedAt!.millisecondsSinceEpoch,
            equals(fixedNowMs),
            reason: 'purgedAt must equal the pinned clock instant exactly',
          );
        }
      },
    );

    test('AC2: does NOT touch rows for a different sefariaRef', () async {
      // Insert prior-mark rows for two different refs.
      // Both go into completion_events + prior_completion_imports so expunge
      // can correctly identify only ref_target's row for tombstoning.
      for (final ref in ['ref_target', 'ref_other']) {
        await _insertPriorMark(
          db,
          profileId: profileId,
          curriculumId: 'mishnayos',
          sefariaRef: ref,
          stageId: 1,
          trackId: trackId,
        );
      }

      final service = BulkPriorCompletionService(
        contentRepository: _StubContentRepository(const []),
        completionRepository: CompletionRepositoryImpl(
          database: db,
          syncEngine: null,
          contentRepository: _StubContentRepository(const []),
          activeProfileId: profileId,
        ),
        bookmarkRepository: MockBookmarkRepository(),
        database: db,
        syncEngine: null,
      );

      await service.expungePriorCompletions(
        profileId: profileId,
        sefariaRef: 'ref_target',
        curriculumId: CurriculumId.mishnayos,
      );

      // ref_other must remain active (purgedAt IS NULL).
      final otherRow = await (db.select(
        db.completionEvents,
      )..where((t) => t.sefariaRef.equals('ref_other'))).getSingle();
      expect(
        otherRow.purgedAt,
        isNull,
        reason: 'Unrelated sefariaRef must not be tombstoned',
      );
    });

    test('AC3: does NOT touch live-learning rows (non-sentinel timestamp) '
        'for the same sefariaRef', () async {
      final liveDate = DateTime.utc(2026, 5, 10, 9, 0); // real study date

      // Prior-mark row for stage 1 — goes into BOTH tables (W4.26).
      await _insertPriorMark(
        db,
        profileId: profileId,
        curriculumId: 'mishnayos',
        sefariaRef: 'ref_live',
        stageId: 1,
        trackId: trackId,
      );
      // Live-learning row for stage 2 (non-sentinel timestamp, NOT in
      // prior_completion_imports — must NOT be tombstoned by expunge).
      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'ref_live',
              stageId: 2,
              trackType: 'personal',
              trackId: Value(trackId),
              points: const Value(10),
              eventTimestamp: liveDate,
            ),
          );

      final service = BulkPriorCompletionService(
        contentRepository: _StubContentRepository(const []),
        completionRepository: CompletionRepositoryImpl(
          database: db,
          syncEngine: null,
          contentRepository: _StubContentRepository(const []),
          activeProfileId: profileId,
        ),
        bookmarkRepository: MockBookmarkRepository(),
        database: db,
        syncEngine: null,
      );

      await service.expungePriorCompletions(
        profileId: profileId,
        sefariaRef: 'ref_live',
        curriculumId: CurriculumId.mishnayos,
      );

      final events = await (db.select(
        db.completionEvents,
      )..where((t) => t.sefariaRef.equals('ref_live'))).get();

      final sentinelRow = events.firstWhere((e) => e.stageId == 1);
      final liveRow = events.firstWhere((e) => e.stageId == 2);

      expect(sentinelRow.purgedAt, isNotNull, reason: 'Prior row tombstoned');
      expect(
        liveRow.purgedAt,
        isNull,
        reason: 'Live-learning row must NOT be tombstoned by expunge',
      );
    });

    test('AC4: expunge is idempotent — calling twice does not throw '
        'and purgedAt remains set', () async {
      await _insertPriorMark(
        db,
        profileId: profileId,
        curriculumId: 'mishnayos',
        sefariaRef: 'ref_idem',
        stageId: 1,
        trackId: trackId,
      );

      final service = BulkPriorCompletionService(
        contentRepository: _StubContentRepository(const []),
        completionRepository: CompletionRepositoryImpl(
          database: db,
          syncEngine: null,
          contentRepository: _StubContentRepository(const []),
          activeProfileId: profileId,
        ),
        bookmarkRepository: MockBookmarkRepository(),
        database: db,
        syncEngine: null,
      );

      await service.expungePriorCompletions(
        profileId: profileId,
        sefariaRef: 'ref_idem',
        curriculumId: CurriculumId.mishnayos,
      );
      // Second call must not throw.
      await expectLater(
        service.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'ref_idem',
          curriculumId: CurriculumId.mishnayos,
        ),
        completes,
      );

      final row = await (db.select(
        db.completionEvents,
      )..where((t) => t.sefariaRef.equals('ref_idem'))).getSingle();
      expect(row.purgedAt, isNotNull);
    });

    test('AC5: expunge on a sefariaRef with no prior rows is a no-op '
        '(does not throw)', () async {
      final service = BulkPriorCompletionService(
        contentRepository: _StubContentRepository(const []),
        completionRepository: CompletionRepositoryImpl(
          database: db,
          syncEngine: null,
          contentRepository: _StubContentRepository(const []),
          activeProfileId: profileId,
        ),
        bookmarkRepository: MockBookmarkRepository(),
        database: db,
        syncEngine: null,
      );

      await expectLater(
        service.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'ref_nonexistent',
          curriculumId: CurriculumId.mishnayos,
        ),
        completes,
      );
    });

    test(
      'AC6: does NOT touch rows belonging to a different profileId',
      () async {
        final now = DateTimeFactory.nowUtc();

        // Seed a second account + profile.
        final acct2 = await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'other@example.com',
                tier: 'localBorn',
                displayName: 'Other',
                createdAt: now,
                updatedAt: now,
              ),
            );
        final otherProfileId = await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: acct2,
                displayName: 'Other',
                mode: 'adult',
                createdAt: now,
                updatedAt: now,
              ),
            );
        // Seed a track for the other profile too.
        final otherTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: otherProfileId,
                curriculumId: 'mishnayos',
                stateChangedAt: now,
                activatedAt: now,
              ),
            );

        // Insert a prior-mark row for profile 1 and another for profile 2,
        // seeding BOTH completion_events AND prior_completion_imports (W4.26).
        for (final pid in [profileId, otherProfileId]) {
          final tid = pid == profileId ? trackId : otherTrackId;
          await _insertPriorMark(
            db,
            profileId: pid,
            curriculumId: 'mishnayos',
            sefariaRef: 'ref_shared',
            stageId: 1,
            trackId: tid,
          );
        }

        final service = BulkPriorCompletionService(
          contentRepository: _StubContentRepository(const []),
          completionRepository: CompletionRepositoryImpl(
            database: db,
            syncEngine: null,
            contentRepository: _StubContentRepository(const []),
            activeProfileId: profileId,
          ),
          bookmarkRepository: MockBookmarkRepository(),
          database: db,
          syncEngine: null,
        );

        // Expunge for profileId only.
        await service.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'ref_shared',
          curriculumId: CurriculumId.mishnayos,
        );

        // Profile 1's row must be tombstoned.
        final p1Row =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('ref_shared') &
                      t.profileId.equals(profileId),
                ))
                .getSingle();
        expect(p1Row.purgedAt, isNotNull);

        // Profile 2's row must be untouched.
        final p2Row =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('ref_shared') &
                      t.profileId.equals(otherProfileId),
                ))
                .getSingle();
        expect(
          p2Row.purgedAt,
          isNull,
          reason: 'Other profile rows must not be tombstoned',
        );
      },
    );
  });

  // ── Finding 8 — Cross-curriculum isolation and edge-case tests ─────────────

  group('Finding 8 — per-curriculum expunge isolation', () {
    /// Seeds a curriculum track for [curriculumId] on [profileId].
    /// Returns the new trackId.
    Future<int> seedTrack(UserDatabase db, int pid, String curriculumId) => db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: pid,
            curriculumId: curriculumId,
            stateChangedAt: DateTimeFactory.nowUtc(),
            activatedAt: DateTimeFactory.nowUtc(),
          ),
        );

    ContentItem leafForCurriculum(
      String ref,
      int sortOrder,
      String curriculumId,
    ) => ContentItemFixtures.leaf(
      curriculumId: curriculumId,
      level1: 'Zeraim',
      sefariaRef: ref,
      sortOrder: sortOrder,
      displayNameHe: ref,
      displayNameEn: ref,
    );

    test(
      'Test 1: untick under curriculum A leaves curriculum B completions intact',
      () async {
        // Seed tracks for both curricula on the same profile.
        final bavliTrackId = await seedTrack(db, profileId, 'bavli');

        // Helper: insert a sentinel completion row directly (priorMarkOnly = true).
        // Prior-mark same sefariaRef under BOTH curricula.
        // Must seed BOTH completion_events AND prior_completion_imports (W4.26).
        await _insertPriorMark(
          db,
          profileId: profileId,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1',
          stageId: 1,
          trackId: trackId,
        );
        await _insertPriorMark(
          db,
          profileId: profileId,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 1',
          stageId: 1,
          trackId: bavliTrackId,
        );

        final service = BulkPriorCompletionService(
          contentRepository: _StubContentRepository(const []),
          completionRepository: CompletionRepositoryImpl(
            database: db,
            syncEngine: null,
            contentRepository: _StubContentRepository(const []),
            activeProfileId: profileId,
          ),
          bookmarkRepository: MockBookmarkRepository(),
          database: db,
          syncEngine: null,
        );

        // Expunge ONLY under mishnayos.
        await service.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'Berakhot 1',
          curriculumId: CurriculumId.mishnayos,
        );

        // mishnayos row must be tombstoned.
        final mishnayosRow =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 1') &
                      t.curriculumId.equals('mishnayos') &
                      t.profileId.equals(profileId),
                ))
                .getSingle();
        expect(
          mishnayosRow.purgedAt,
          isNotNull,
          reason: 'mishnayos sentinel row must be tombstoned',
        );

        // bavli row must remain active (purgedAt IS NULL).
        final bavliRow =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 1') &
                      t.curriculumId.equals('bavli') &
                      t.profileId.equals(profileId),
                ))
                .getSingle();
        expect(
          bavliRow.purgedAt,
          isNull,
          reason:
              'bavli completion must NOT be tombstoned by a mishnayos expunge',
        );
      },
    );

    test(
      'Test 2: prior-marking under both A and B creates separate active rows',
      () async {
        await seedTrack(db, profileId, 'bavli');

        final mishnayosItems = [
          leafForCurriculum('Berakhot 2', 0, 'mishnayos'),
        ];
        final bavliItems = [leafForCurriculum('Berakhot 2', 0, 'bavli')];

        final bookmarkRepo = MockBookmarkRepository();
        when(
          () => bookmarkRepo.setBookmark(
            curriculumId: any(named: 'curriculumId'),
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => _fakeBookmark());

        // Prior-mark under mishnayos.
        final mishnayosSvc = BulkPriorCompletionService(
          contentRepository: _StubContentRepository(mishnayosItems),
          completionRepository: CompletionRepositoryImpl(
            database: db,
            syncEngine: null,
            contentRepository: _StubContentRepository(mishnayosItems),
            activeProfileId: profileId,
          ),
          bookmarkRepository: bookmarkRepo,
          database: db,
          syncEngine: null,
        );
        await mishnayosSvc.execute(
          curriculumId: CurriculumId.mishnayos,
          resolvedItems: mishnayosItems,
          stageIds: [1],
          profileId: profileId,
        );

        // Prior-mark under bavli.
        final bavliSvc = BulkPriorCompletionService(
          contentRepository: _StubContentRepository(bavliItems),
          completionRepository: CompletionRepositoryImpl(
            database: db,
            syncEngine: null,
            contentRepository: _StubContentRepository(bavliItems),
            activeProfileId: profileId,
          ),
          bookmarkRepository: bookmarkRepo,
          database: db,
          syncEngine: null,
        );
        await bavliSvc.execute(
          curriculumId: CurriculumId.bavli,
          resolvedItems: bavliItems,
          stageIds: [1],
          profileId: profileId,
        );

        // Query all completion_events for 'Berakhot 2'.
        final rows =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 2') & t.purgedAt.isNull(),
                ))
                .get();

        // Must have exactly one active row per curriculum (2 curricula
        // seeded above) — not merely "2 or more". AUD-t-cross-45:
        // greaterThanOrEqualTo(2) let a duplicate-insert regression (e.g. a
        // double-write bug in execute()) pass silently; exact equality
        // catches it.
        expect(
          rows.length,
          equals(2),
          reason:
              'Should have one active completion per curriculum for Berakhot 2',
        );

        // They must have different curriculumIds.
        final curricula = rows.map((r) => r.curriculumId).toSet();
        expect(
          curricula,
          containsAll(['mishnayos', 'bavli']),
          reason: 'Active rows must span both curricula',
        );
      },
    );

    test(
      'Test 3: untick leaves live-learning row intact (non-sentinel timestamp)',
      () async {
        final liveDate = DateTime.utc(2026, 5, 10, 9, 0);

        // Insert a real-learning row FIRST (non-sentinel timestamp, stage 1).
        // Use a distinct trackType combo to avoid 5-tuple UNIQUE collision:
        // we use stageId=1 for live learning and stageId=2 for the sentinel.
        await db
            .into(db.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: profileId,
                curriculumId: 'mishnayos',
                sefariaRef: 'Berakhot 3',
                stageId: 1,
                trackType: 'personal',
                trackId: Value(trackId),
                points: const Value(10),
                eventTimestamp: liveDate,
              ),
            );

        // Insert a prior-mark row at stageId=2 for the same item.
        // Seeds BOTH completion_events AND prior_completion_imports (W4.26).
        // Different stageId avoids the UNIQUE constraint on completion_events.
        await _insertPriorMark(
          db,
          profileId: profileId,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 3',
          stageId: 2,
          trackId: trackId,
        );

        final service = BulkPriorCompletionService(
          contentRepository: _StubContentRepository(const []),
          completionRepository: CompletionRepositoryImpl(
            database: db,
            syncEngine: null,
            contentRepository: _StubContentRepository(const []),
            activeProfileId: profileId,
          ),
          bookmarkRepository: MockBookmarkRepository(),
          database: db,
          syncEngine: null,
        );

        // Expunge under mishnayos — only the sentinel row (stageId=2) should be
        // tombstoned; the real-learning row (stageId=1, liveDate) must survive.
        await service.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'Berakhot 3',
          curriculumId: CurriculumId.mishnayos,
        );

        final rows = await (db.select(
          db.completionEvents,
        )..where((t) => t.sefariaRef.equals('Berakhot 3'))).get();

        final liveRow = rows.firstWhere((r) => r.stageId == 1);
        final priorRow = rows.firstWhere((r) => r.stageId == 2);

        expect(
          liveRow.purgedAt,
          isNull,
          reason: 'Real-learning row must NOT be tombstoned',
        );
        expect(
          priorRow.purgedAt,
          isNotNull,
          reason: 'Prior-mark (sentinel) row must be tombstoned',
        );
      },
    );

    test(
      'Test 4 (live-learning row survival): prior-mark then real-learning '
      'then expunge — row must survive because priorMarkOnly is upgraded to false',
      () async {
        // B8 fix: Un-ticking a prior-mark MUST leave the item in Lifetime if
        // a real in-app learning event exists for it.
        //
        // Failure sequence this test guards against:
        //   1. Prior-mark writes a completion_events row (priorMarkOnly = true).
        //   2. User genuinely learns the item — CompletionWriter.commit() finds
        //      the existing row, detects priorMarkOnly = true, upgrades the row
        //      (sets priorMarkOnly = false, updates eventTimestamp). No new row.
        //   3. User goes back and un-ticks — expungePriorCompletions() ONLY
        //      tombstones rows where priorMarkOnly = true. The upgraded row
        //      (priorMarkOnly = false) survives.
        //
        // The old buggy path (no priorMarkOnly column): expunge matched on the
        // sentinel eventTimestamp; but after the commit() the timestamp was
        // still sentinel (commit returned isNew: false without changing it), so
        // expunge wiped the row even though real learning had occurred.

        // Step 1: prior-mark 'Berakhot 4' under mishnayos (stageId=1).
        // Use the service path so priorMarkOnly = true is stamped on the row.
        await _seedStages(db, profileId: profileId, trackId: trackId, count: 1);
        final items = [_leaf('Berakhot 4', 0)];
        final bookmarkRepo = MockBookmarkRepository();
        when(
          () => bookmarkRepo.setBookmark(
            curriculumId: any(named: 'curriculumId'),
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => _fakeBookmark());

        final priorSvc = BulkPriorCompletionService(
          contentRepository: _StubContentRepository(items),
          completionRepository: CompletionRepositoryImpl(
            database: db,
            syncEngine: null,
            contentRepository: _StubContentRepository(items),
            activeProfileId: profileId,
          ),
          bookmarkRepository: bookmarkRepo,
          database: db,
          syncEngine: null,
          stageRepository: StageDefinitionRepositoryImpl(
            stageDao: db.stageDao,
            completionDao: db.completionDao,
            pushStageDefinitions: null,
          ),
        );
        await priorSvc.execute(
          curriculumId: CurriculumId.mishnayos,
          resolvedItems: items,
          stageIds: [1],
          profileId: profileId,
        );

        // Verify the prior-mark row has sentinel timestamp (replaces priorMarkOnly).
        final afterPriorMark =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 4') &
                      t.stageId.equals(1) &
                      t.profileId.equals(profileId),
                ))
                .getSingle();
        // Compare via millisecondsSinceEpoch to avoid UTC vs. local
        // DateTime mismatch when the value round-trips through Drift/SQLite.
        expect(
          afterPriorMark.eventTimestamp.millisecondsSinceEpoch,
          kBulkPriorSentinelDate.millisecondsSinceEpoch,
          reason: 'Bulk-prior-mark must use sentinel timestamp',
        );

        // Step 2: genuine in-app learning via CompletionWriter.commit().
        // This must upgrade the row: clear priorMarkOnly, update eventTimestamp.
        final realDate = DateTime.utc(2026, 5, 19, 10, 0);
        final writer = CompletionWriter(db);
        await writer.commit(
          CompletionCommand(
            profileId: profileId,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 4',
            stageId: 1,
            trackType: 'personal',
            trackId: trackId,
            completedAt: realDate,
            points: 10,
            priorMarkOnly: false, // real learning
          ),
        );

        // Verify the row was upgraded: timestamp is no longer the sentinel.
        final afterRealLearning =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 4') &
                      t.stageId.equals(1) &
                      t.profileId.equals(profileId),
                ))
                .getSingle();
        expect(
          afterRealLearning.eventTimestamp,
          isNot(kBulkPriorSentinelDate),
          reason:
              'CompletionWriter must update eventTimestamp when real learning '
              'hits an existing prior-mark row',
        );
        expect(
          afterRealLearning.purgedAt,
          isNull,
          reason: 'Row must still be active after upgrade',
        );

        // Step 3: expunge (un-tick in bulk-mark screen).
        // Only rows with priorMarkOnly = true should be tombstoned.
        // This row has priorMarkOnly = false, so it must survive.
        await priorSvc.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'Berakhot 4',
          curriculumId: CurriculumId.mishnayos,
        );

        final afterExpunge =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 4') &
                      t.stageId.equals(1) &
                      t.profileId.equals(profileId),
                ))
                .getSingle();

        // THE KEY ASSERTION: the row must survive expunge because it was
        // upgraded from a prior-mark to a real-learning row.
        expect(
          afterExpunge.purgedAt,
          isNull,
          reason:
              'B8 fix: real-learning row (priorMarkOnly = false) must NOT be '
              'tombstoned by expungePriorCompletions — item must survive in Lifetime',
        );
      },
    );
  });
}

// AUD-t-cross-39: fixed constant instead of a wall-clock read — this
// value is never asserted on by any test, it only satisfies
// BookmarkEntity's required field for the mocked bookmarkRepository return.
BookmarkEntity _fakeBookmark() => BookmarkEntity(
  curriculumId: CurriculumId.mishnayos,
  sefariaRef: 'ref',
  updatedAt: DateTime.utc(2026, 1, 1),
);
