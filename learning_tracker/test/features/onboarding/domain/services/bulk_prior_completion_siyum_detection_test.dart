/// F1 (W7-A) — Bulk-mark wizard must trigger siyum detection.
///
/// The onboarding bulk-mark step funnels through:
///   BulkPriorCompletionService.execute
///     → CompletionRepository.bulkMarkComplete (with creditsAchievement = true)
///       → _bulkMarkCompletePriorOptimized (engagement suppressed)
///         → CompletionDetectionService.checkAndRecordCompletions
///
/// Before W7-A's fix the detection service was only wired into the single-item
/// markComplete path, so a user who bulk-marked every leaf of a masechta
/// received ZERO `learning_ledger` entries — the redesign's "earn the siyum"
/// success criterion silently failed.
///
/// This test drives the REAL production code through an in-memory Drift
/// database, asserts the masechta-level ledger row appears, and serves as the
/// canonical regression guard for the bulkInTrack → achievement-tier wiring.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

/// In-memory ContentRepository — returns the seeded leaves for a small
/// masechta plus the lookup helpers the detection service needs.
class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async =>
      _items.where((i) => i.curriculumId == curriculumId.storageKey).toList();

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const [],
    totalItems: _items.length,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async {
    return _items.where((item) {
      if (item.curriculumId != curriculumId.storageKey) return false;
      if (level1 != null && item.level1 != level1) return false;
      if (level2 != null && item.level2 != level2) return false;
      if (level3 != null && item.level3 != level3) return false;
      if (level4 != null && item.level4 != level4) return false;
      return true;
    }).toList();
  }

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
  }) async {
    for (final item in _items) {
      if (item.curriculumId == curriculumId.storageKey &&
          item.sefariaRef == sefariaRef) {
        return item;
      }
    }
    return null;
  }
}

/// Minimal BookmarkRepository stub — the bulk path tries to set a bookmark
/// after writing completions; for this test we don't care about bookmark
/// behaviour, only the ledger.
class _NoopBookmarkRepository implements BookmarkRepository {
  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async => null;

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => BookmarkEntity(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    updatedAt: DateTime.utc(2026, 5, 13),
  );

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async {}

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) async => BookmarkEntity(
    curriculumId: curriculumId,
    sefariaRef: '',
    updatedAt: DateTime.utc(2026, 5, 13),
  );

  @override
  Future<int> syncFromFirestore() async => 0;
}

Future<int> _seedAccountAndProfile(UserDatabase db) async {
  final now = DateTime.utc(2026, 5, 13, 12, 0, 0);
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: now,
          updatedAt: now,
        ),
      );
  final profileRow = await db
      .into(db.learnerProfiles)
      .insertReturning(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test User',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );
  return profileRow.id;
}

Future<int> _seedTrack(
  UserDatabase db, {
  required int profileId,
  required String curriculumId,
}) async {
  final now = DateTime.utc(2026, 5, 13, 12, 0, 0);
  final trackRow = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: now,
          activatedAt: now,
        ),
      );
  return trackRow.id;
}

Future<void> _seedStageDefinition(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  required String curriculumId,
  required int stageOrder,
}) async {
  await db.stageDao.insertStageDefinition(
    StageDefinitionsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      trackId: trackId,
      stageOrder: stageOrder,
      stageName: 'Stage $stageOrder',
    ),
  );
}

void main() {
  group('F1 (W7-A) — Bulk-mark wizard triggers siyum detection', () {
    late UserDatabase db;
    late int profileId;
    late int trackId;
    late _FakeContentRepository contentRepo;
    late CompletionDetectionService detectionService;
    late CompletionRepositoryImpl completionRepo;
    late BulkPriorCompletionService bulkService;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      profileId = await _seedAccountAndProfile(db);
      trackId = await _seedTrack(
        db,
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos.storageKey,
      );
      await _seedStageDefinition(
        db,
        profileId: profileId,
        trackId: trackId,
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
      );

      // Small masechta — Berakhot with 3 leaves. The bulk-mark wizard will
      // bulk-mark all three, and a single masechta siyum should fire.
      final items = <ContentItem>[
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: 'Berakhot',
          displayNameHe: 'ברכות',
          displayNameEn: 'Berakhot',
          sefariaRef: 'Mishnah_Berakhot_1',
          sortOrder: 0,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: 'Berakhot',
          displayNameHe: 'ברכות',
          displayNameEn: 'Berakhot',
          sefariaRef: 'Mishnah_Berakhot_2',
          sortOrder: 1,
          isLeaf: true,
        ),
        const ContentItem(
          curriculumId: 'mishnayos',
          level1: 'Zeraim',
          level2: 'Berakhot',
          displayNameHe: 'ברכות',
          displayNameEn: 'Berakhot',
          sefariaRef: 'Mishnah_Berakhot_3',
          sortOrder: 2,
          isLeaf: true,
        ),
      ];
      contentRepo = _FakeContentRepository(items);

      // Real ledger repo (no outbox facade — local-only).
      final ledgerRepo = LearningLedgerRepositoryImpl(
        database: db,
        outboxFacade: null,
        activeProfileId: profileId,
        activeProfileMode: ProfileMode.adult,
      );

      // Real stage repo.
      final stageRepo = StageDefinitionRepositoryImpl(
        stageDao: db.stageDao,
        completionDao: db.completionDao,
        pushStageDefinitions: null,
      );

      // Real detection service — this is the production class that produces
      // the ledger row.
      detectionService = CompletionDetectionService(
        database: db,
        contentRepository: contentRepo,
        ledgerRepository: ledgerRepo,
        stageRepository: stageRepo,
      );

      // Real completion repo, with the detection service injected so the new
      // F1 dispatch path can fire.
      completionRepo = CompletionRepositoryImpl(
        database: db,
        syncEngine: null,
        contentRepository: contentRepo,
        completionDetectionService: detectionService,
        activeProfileId: profileId,
      );

      // Real bulk service that powers the onboarding wizard.
      bulkService = BulkPriorCompletionService(
        contentRepository: contentRepo,
        completionRepository: completionRepo,
        bookmarkRepository: _NoopBookmarkRepository(),
        database: db,
        syncEngine: null,
        stageRepository: stageRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('bulk-marking every leaf of a masechta via BulkPriorCompletionService '
        'creates the masechta siyum ledger entry', () async {
      // Resolve every leaf in Berakhot — this is what the wizard does after
      // the user selects the masechta.
      final items = await bulkService.resolveSelections(
        curriculumId: CurriculumId.mishnayos,
        selections: const [
          HierarchySelection(level1: 'Zeraim', level2: 'Berakhot'),
        ],
      );
      expect(items, hasLength(3), reason: 'sanity: 3 leaves resolved');

      // Execute the bulk-mark — this is the production code path.
      final result = await bulkService.execute(
        curriculumId: CurriculumId.mishnayos,
        resolvedItems: items,
        stageIds: const [1],
        profileId: profileId,
      );
      expect(result.completionCount, 3);

      // The headline assertion: a masechta siyum landed in the ledger.
      final entries = await db.learningLedgerDao.getEntriesByProfile(profileId);
      expect(
        entries
            .where(
              (e) =>
                  e.curriculumId == 'mishnayos' &&
                  e.entryScope == 'masechta' &&
                  e.unitIdentifier == 'Berakhot',
            )
            .toList(),
        hasLength(1),
        reason:
            'F1: bulk-marking every leaf must produce exactly one '
            "masechta-level siyum ledger row — without W7-A's fix the "
            'detection service is never invoked and the user gets zero '
            'siyum entries.',
      );
    });

    test(
      'partial bulk-mark (missing one leaf) does NOT create the masechta siyum',
      () async {
        // Mark only 2 of 3 leaves so the parent unit is still incomplete.
        final items = (await bulkService.resolveSelections(
          curriculumId: CurriculumId.mishnayos,
          selections: const [
            HierarchySelection(level1: 'Zeraim', level2: 'Berakhot'),
          ],
        )).take(2).toList();

        await bulkService.execute(
          curriculumId: CurriculumId.mishnayos,
          resolvedItems: items,
          stageIds: const [1],
          profileId: profileId,
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(
          profileId,
        );
        expect(
          entries.where((e) => e.entryScope == 'masechta'),
          isEmpty,
          reason:
              'detection service must not record a siyum until every leaf '
              'is complete',
        );
      },
    );
  });
}
