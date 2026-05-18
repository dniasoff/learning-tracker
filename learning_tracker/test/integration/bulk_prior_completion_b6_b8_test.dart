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
        // Insert 3 prior-mark rows (sentinel timestamp) for 'ref_target'.
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

      // Insert prior-mark rows for two different refs.
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

      // Prior-mark row (sentinel).
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
            ),
          );
      // Live-learning row for stage 2 (non-sentinel — must NOT be purged).
      // Insert directly into completionEvents with a different stageId so
      // the natural-key UNIQUE constraint (profileId, sefariaRef, stageId,
      // trackType) is satisfied.
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

        // Insert a prior-mark row for profile 1 and another for profile 2.
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
}

BookmarkEntity _fakeBookmark() => BookmarkEntity(
  curriculumId: CurriculumId.mishnayos,
  trackType: TrackType.personal,
  sefariaRef: 'ref',
  updatedAt: DateTime.now(),
);
