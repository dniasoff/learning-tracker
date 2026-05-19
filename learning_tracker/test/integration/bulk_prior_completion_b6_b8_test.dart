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
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

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

ContentItem _leaf(String ref, int sortOrder) => ContentItem(
  curriculumId: 'mishnayos',
  level1: 'Zeraim',
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: true,
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
          userMode: 'adult',
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
          trackType: 'personal',
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
            delayDays: 0,
          ),
        );
  }
}

/// Seeds [count] active stages plus one extra superseded stage at
/// stageOrder [count + 1] (supersededAt set to a past timestamp).
/// Used to verify that M1 fix excludes superseded stages from bulk-mark.
Future<void> _seedStagesWithSuperseded(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required int count,
}) async {
  await _seedStages(db, profileId: profileId, trackId: trackId, count: count);
  // Insert one superseded stage at stageOrder count+1.
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: count + 1,
          stageName: 'Old Chazara (superseded)',
          delayDays: 0,
          supersededAt: Value(DateTime.utc(2026, 1, 1)),
        ),
      );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;
  late int profileId;
  late int trackId;

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(TrackType.personal);
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
          trackType: any(named: 'trackType'),
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
        pushSettings: null,
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

    test('AC3 (M1): superseded stages are excluded — '
        'only active stages receive completion_events', () async {
      // Seed 2 active stages + 1 superseded stage at stageOrder 3.
      await _seedStagesWithSuperseded(
        db,
        profileId: profileId,
        trackId: trackId,
        count: 2,
      );

      final items = [_leaf('ref_m1', 0)];
      final bookmarkRepo = MockBookmarkRepository();
      when(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          trackType: any(named: 'trackType'),
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
        pushSettings: null,
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
        stageIds: [1],
        profileId: profileId,
      );

      // 1 item × 2 active stages = 2 completions; superseded stage 3 excluded.
      expect(
        result.completionCount,
        2,
        reason:
            'M1: superseded stage must be excluded; only 2 active stages '
            'produce completions',
      );

      final events = await db.completionDao.getCompletionsByProfile(profileId);
      final stageIds = events.map((e) => e.stageId).toSet();
      expect(
        stageIds,
        equals({1, 2}),
        reason:
            'Only active stageOrders (1, 2) must appear; '
            'superseded stageOrder 3 must be absent',
      );
    });

    test('AC2: completion_events for all stages carry the sentinel timestamp '
        '(DateTime.utc(2000, 1, 1)) — not today', () async {
      await _seedStages(db, profileId: profileId, trackId: trackId, count: 2);

      final items = [_leaf('ref_x', 0)];
      final bookmarkRepo = MockBookmarkRepository();
      when(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          trackType: any(named: 'trackType'),
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
        pushSettings: null,
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
        // Insert 3 prior-mark rows (sentinel timestamp, priorMarkOnly = true)
        // for 'ref_target'.
        final sentinel = kBulkPriorSentinelDate;
        for (var stage = 1; stage <= 3; stage++) {
          await db
              .into(db.completionEvents)
              .insert(
                CompletionEventsCompanion.insert(
                  profileId: profileId,
                  curriculumId: 'mishnayos',
                  sefariaRef: 'ref_target',
                  stageId: stage,
                  trackType: 'personal',
                  trackId: Value(trackId),
                  points: const Value(0),
                  eventTimestamp: sentinel,
                  priorMarkOnly: const Value(true),
                ),
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

        final before = DateTime.now().toUtc();
        await service.expungePriorCompletions(
          profileId: profileId,
          sefariaRef: 'ref_target',
          curriculumId: CurriculumId.mishnayos,
        );
        final after = DateTime.now().toUtc();

        final events = await (db.select(
          db.completionEvents,
        )..where((t) => t.sefariaRef.equals('ref_target'))).get();

        // All 3 rows must be tombstoned.
        expect(events, hasLength(3));
        for (final e in events) {
          expect(
            e.purgedAt,
            isNotNull,
            reason: 'Prior-mark row (stage ${e.stageId}) must be tombstoned',
          );
          // purgedAt must be between the before/after timestamps.
          expect(
            e.purgedAt!.isAfter(before.subtract(const Duration(seconds: 1))),
            isTrue,
          );
          expect(
            e.purgedAt!.isBefore(after.add(const Duration(seconds: 1))),
            isTrue,
          );
        }
      },
    );

    test('AC2: does NOT touch rows for a different sefariaRef', () async {
      final sentinel = kBulkPriorSentinelDate;

      // Insert prior-mark rows (priorMarkOnly = true) for two different refs.
      for (final ref in ['ref_target', 'ref_other']) {
        await db
            .into(db.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: profileId,
                curriculumId: 'mishnayos',
                sefariaRef: ref,
                stageId: 1,
                trackType: 'personal',
                trackId: Value(trackId),
                points: const Value(0),
                eventTimestamp: sentinel,
                priorMarkOnly: const Value(true),
              ),
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
      final sentinel = kBulkPriorSentinelDate;
      final liveDate = DateTime.utc(2026, 5, 10, 9, 0); // real study date

      // Prior-mark row (sentinel, priorMarkOnly = true).
      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'ref_live',
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              points: const Value(0),
              eventTimestamp: sentinel,
              priorMarkOnly: const Value(true),
            ),
          );
      // Live-learning row for stage 2 (non-sentinel, priorMarkOnly = false
      // by default — must NOT be purged). Insert directly into completionEvents
      // with a different stageId so the natural-key UNIQUE constraint
      // (profileId, sefariaRef, stageId, trackType) is satisfied.
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
      final sentinel = kBulkPriorSentinelDate;

      await db
          .into(db.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: 'mishnayos',
              sefariaRef: 'ref_idem',
              stageId: 1,
              trackType: 'personal',
              trackId: Value(trackId),
              points: const Value(0),
              eventTimestamp: sentinel,
              priorMarkOnly: const Value(true),
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
        final sentinel = kBulkPriorSentinelDate;
        final now = DateTimeFactory.nowUtc();

        // Seed a second account + profile.
        final acct2 = await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'other@example.com',
                tier: 'localBorn',
                displayName: 'Other',
                userMode: 'adult',
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
                trackType: 'personal',
                activatedAt: now,
              ),
            );

        // Insert a prior-mark row (priorMarkOnly = true) for profile 1 and
        // another for profile 2.
        for (final pid in [profileId, otherProfileId]) {
          final tid = pid == profileId ? trackId : otherTrackId;
          await db
              .into(db.completionEvents)
              .insert(
                CompletionEventsCompanion.insert(
                  profileId: pid,
                  curriculumId: 'mishnayos',
                  sefariaRef: 'ref_shared',
                  stageId: 1,
                  trackType: 'personal',
                  trackId: Value(tid),
                  points: const Value(0),
                  eventTimestamp: sentinel,
                  priorMarkOnly: const Value(true),
                ),
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
            trackType: 'personal',
            activatedAt: DateTimeFactory.nowUtc(),
          ),
        );

    ContentItem leafForCurriculum(
      String ref,
      int sortOrder,
      String curriculumId,
    ) => ContentItem(
      curriculumId: curriculumId,
      level1: 'Zeraim',
      displayNameHe: ref,
      displayNameEn: ref,
      sefariaRef: ref,
      sortOrder: sortOrder,
      isLeaf: true,
    );

    test(
      'Test 1: untick under curriculum A leaves curriculum B completions intact',
      () async {
        // Seed tracks for both curricula on the same profile.
        final bavliTrackId = await seedTrack(db, profileId, 'bavli');

        // Helper: insert a sentinel completion row directly (priorMarkOnly = true).
        Future<void> insertSentinel(
          String sefariaRef,
          String curriculumId,
          int tid,
        ) => db
            .into(db.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: profileId,
                curriculumId: curriculumId,
                sefariaRef: sefariaRef,
                stageId: 1,
                trackType: 'personal',
                trackId: Value(tid),
                points: const Value(0),
                eventTimestamp: kBulkPriorSentinelDate,
                priorMarkOnly: const Value(true),
              ),
            );

        // Prior-mark same sefariaRef under BOTH curricula.
        await insertSentinel('Berakhot 1', 'mishnayos', trackId);
        await insertSentinel('Berakhot 1', 'bavli', bavliTrackId);

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
            trackType: any(named: 'trackType'),
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

        // Must have 2+ active rows — one per curriculum.
        expect(
          rows.length,
          greaterThanOrEqualTo(2),
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

        // Insert a prior-mark row at stageId=2 for the same item (sentinel
        // timestamp, priorMarkOnly = true). Different stageId avoids the UNIQUE
        // constraint.
        await db
            .into(db.completionEvents)
            .insert(
              CompletionEventsCompanion.insert(
                profileId: profileId,
                curriculumId: 'mishnayos',
                sefariaRef: 'Berakhot 3',
                stageId: 2,
                trackType: 'personal',
                trackId: Value(trackId),
                points: const Value(0),
                eventTimestamp: kBulkPriorSentinelDate,
                priorMarkOnly: const Value(true),
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
            trackType: any(named: 'trackType'),
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
            pushSettings: null,
          ),
        );
        await priorSvc.execute(
          curriculumId: CurriculumId.mishnayos,
          resolvedItems: items,
          stageIds: [1],
          profileId: profileId,
        );

        // Verify the prior-mark row has priorMarkOnly = true.
        final afterPriorMark =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 4') &
                      t.stageId.equals(1) &
                      t.profileId.equals(profileId),
                ))
                .getSingle();
        expect(
          afterPriorMark.priorMarkOnly,
          isTrue,
          reason: 'Bulk-prior-mark must set priorMarkOnly = true',
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
            trackType: TrackType.personal.storageKey,
            trackId: trackId,
            completedAt: realDate,
            points: 10,
            priorMarkOnly: false, // real learning
          ),
        );

        // Verify the row was upgraded: priorMarkOnly = false.
        final afterRealLearning =
            await (db.select(db.completionEvents)..where(
                  (t) =>
                      t.sefariaRef.equals('Berakhot 4') &
                      t.stageId.equals(1) &
                      t.profileId.equals(profileId),
                ))
                .getSingle();
        expect(
          afterRealLearning.priorMarkOnly,
          isFalse,
          reason:
              'CompletionWriter must clear priorMarkOnly when real learning '
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

BookmarkEntity _fakeBookmark() => BookmarkEntity(
  curriculumId: CurriculumId.mishnayos,
  trackType: TrackType.personal,
  sefariaRef: 'ref',
  updatedAt: DateTime.now(),
);
