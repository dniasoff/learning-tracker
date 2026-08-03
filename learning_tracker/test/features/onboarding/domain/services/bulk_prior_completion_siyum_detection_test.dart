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
///
/// ## P0 follow-up (false "Chumash complete!" siyum at 61.6% actual completion)
///
/// Every fixture above (and every fixture this file ever had) is Mishnayos-
/// shaped: leaves sit directly at level2 (`level1: seder, level2: masechta`).
/// That shape can never expose the bug below — **the fixture gap is as
/// important as the bug it hid.** Chumash's real shape (see
/// `assets/content/hierarchy/chumash.json`) is one level deeper: leaves sit
/// at level3 (`level1: sefer, level2: chapter, level3: verse`), and
/// `hierarchyConfig` confirms it (`levelLabels: [Sefer, Chapter, Verse]`).
/// `unitScopeFor`/`_countTotalUnits`/`_hasAggregateLevel` all assumed Chumash/
/// Nach/Tanach/Mussar carry no level2 at all — false for the shipped assets,
/// which populate level2 (the chapter number) on ~97-99% of leaves. Because a
/// chapter number is a bare POSITIONAL label repeated across every sefer
/// (Genesis ch. 1 and Shemos ch. 1 both read `'1'`), treating it as a unit
/// identifier corrupted `journeyViewModelProvider`'s total-units denominator:
/// bulk-marking 3 of 5 Chumash sefarim on-device fired a false
/// "Chumash complete!" curriculum-level milestone after only 61.6% was done.
/// See `hasNamedLevel2Unit` (`completion_detection_service.dart`) for the
/// fix — Chumash/Nach/Tanach/Mussar's level2 is deliberately never used as a
/// siyum unit identifier at all (a chapter is not its own siyum tier by
/// product decision), rather than trying to ancestor-qualify it the way
/// `scopeUnitIdentifier()` (`core/content/content_grouping.dart`) does for
/// the same sibling-id-collision class elsewhere in the codebase — that
/// qualified-identifier approach is the one to reach for if chapter-level
/// siyumim are ever wanted as a deliberate feature.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
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

/// Pins the Hebrew Terms toggle off so journeyViewModelProvider's milestone
/// detector (which reads it via curriculumLabelTextFromRef for the
/// curriculum-complete milestone's display name) doesn't try to hit a real
/// SharedPreferences instance in this binding-less ProviderContainer test —
/// mirrors journey_providers_test.dart's identical override.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride();
  @override
  bool build() => false;
}

/// Pins the nusach for the same reason as [_UseHebrewTermsOverride].
class _VariantOverride extends CurrentTransliterationVariant {
  _VariantOverride();
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
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

      // Real completion repo — storage-only since the completion-
      // orchestrator lift (docs/firestore-rewrite-map.md, owner decision 1).
      completionRepo = CompletionRepositoryImpl(
        database: db,
        activeProfileId: profileId,
      );

      // Real orchestrator, with the detection service injected so the F1
      // dispatch path can fire (siyum detection lives here now, not in
      // CompletionRepositoryImpl).
      final orchestrator = CompletionOrchestrator(
        repository: completionRepo,
        contentRepository: contentRepo,
        activeProfileId: profileId,
        completionDetectionService: detectionService,
      );

      // Real bulk service that powers the onboarding wizard.
      bulkService = BulkPriorCompletionService(
        contentRepository: contentRepo,
        completionRepository: completionRepo,
        bookmarkRepository: _NoopBookmarkRepository(),
        database: db,
        orchestrator: orchestrator,
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

  group(
    'P0 — Chumash-shaped bulk-mark must not fire a false curriculum-complete '
    'siyum',
    () {
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
          curriculumId: CurriculumId.chumash.storageKey,
        );
        await _seedStageDefinition(
          db,
          profileId: profileId,
          trackId: trackId,
          curriculumId: CurriculumId.chumash.storageKey,
          stageOrder: 1,
        );

        contentRepo = _FakeContentRepository(_chumashShapedFixture());

        final ledgerRepo = LearningLedgerRepositoryImpl(
          database: db,
          outboxFacade: null,
          activeProfileId: profileId,
          activeProfileMode: ProfileMode.adult,
        );
        final stageRepo = StageDefinitionRepositoryImpl(
          stageDao: db.stageDao,
          completionDao: db.completionDao,
          pushStageDefinitions: null,
        );
        detectionService = CompletionDetectionService(
          database: db,
          contentRepository: contentRepo,
          ledgerRepository: ledgerRepo,
          stageRepository: stageRepo,
        );
        completionRepo = CompletionRepositoryImpl(
          database: db,
          activeProfileId: profileId,
        );
        final orchestrator = CompletionOrchestrator(
          repository: completionRepo,
          contentRepository: contentRepo,
          activeProfileId: profileId,
          completionDetectionService: detectionService,
        );
        bulkService = BulkPriorCompletionService(
          contentRepository: contentRepo,
          completionRepository: completionRepo,
          bookmarkRepository: _NoopBookmarkRepository(),
          database: db,
          orchestrator: orchestrator,
          stageRepository: stageRepo,
        );
      });

      tearDown(() async {
        await db.close();
      });

      Future<void> markSefarim(List<String> sefarim) async {
        final selections = [
          for (final s in sefarim) HierarchySelection(level1: s),
        ];
        final items = await bulkService.resolveSelections(
          curriculumId: CurriculumId.chumash,
          selections: selections,
        );
        await bulkService.execute(
          curriculumId: CurriculumId.chumash,
          resolvedItems: items,
          stageIds: const [1],
        );
      }

      // Drives the REAL journeyViewModelProvider (the Siyumim & Milestones
      // screen's data source) over the SAME database and content fixture the
      // bulk-mark just wrote to — not just the raw ledger rows — so the
      // denominator/milestone bugs (which live in journey_providers.dart, a
      // different file from the write path) are exercised end to end too.
      Future<JourneyViewModel> readJourneyViewModel() {
        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(contentRepo),
            curriculumContentProvider.overrideWith(
              (ref, curriculumId) =>
                  contentRepo.getContentForCurriculum(curriculumId),
            ),
            useHebrewTermsProvider.overrideWith(_UseHebrewTermsOverride.new),
            currentTransliterationVariantProvider.overrideWith(
              _VariantOverride.new,
            ),
            activeCurriculaProvider.overrideWith(
              (ref) => Future.value(const [CurriculumId.chumash]),
            ),
            // Pin siyum granularity to the finest tier (pass-through gate) so
            // this binding-less container stays off SharedPreferences and the
            // milestone assertions below see the full unfiltered emission —
            // mirrors the useHebrewTerms / variant overrides above.
            siyumGranularityProvider(
              CurriculumId.chumash,
            ).overrideWithValue(MilestoneLevel.unit),
          ],
        );
        addTearDown(container.dispose);
        return container.read(journeyViewModelProvider(profileId).future);
      }

      test(
        '3 of 5 sefarim: no false curriculum-complete milestone, correct '
        '5-sefer denominator, no masechta-mislabeled or duplicate entries',
        () async {
          await markSefarim(['Genesis', 'Exodus', 'Leviticus']);

          final entries = await db.learningLedgerDao.getEntriesByProfile(
            profileId,
          );

          // The bug: chapter completions used to be recorded with
          // entryScope='masechta' and a bare chapter-number unitIdentifier
          // (e.g. '1') — a label this curriculum has no business emitting.
          expect(
            entries.where((e) => e.entryScope == 'masechta'),
            isEmpty,
            reason:
                'Chumash has no named level-2 unit (hasNamedLevel2Unit == '
                'false) — chapter completions must never be recorded as a '
                "'masechta'-scoped siyum.",
          );

          // Exactly one sefer-level entry per completed sefer — the
          // aggregate dispatch used to fire once per distinct chapter
          // touched (2 chapters/sefer here) instead of once per sefer.
          final seferEntries = entries
              .where((e) => e.entryScope == 'sefer')
              .toList();
          expect(
            seferEntries.map((e) => e.unitIdentifier).toSet(),
            {'Genesis', 'Exodus', 'Leviticus'},
            reason: 'one sefer-level siyum per completed sefer',
          );
          for (final sefer in ['Genesis', 'Exodus', 'Leviticus']) {
            expect(
              seferEntries.where((e) => e.unitIdentifier == sefer),
              hasLength(1),
              reason:
                  'F1 duplicate-aggregate-dispatch bug: the sefer-level '
                  'check must fire exactly once per bulk-mark, not once per '
                  'distinct chapter dispatched under $sefer',
            );
          }

          final vm = await readJourneyViewModel();
          final chumashJourney = vm.curricula.firstWhere(
            (c) => c.curriculumId == CurriculumId.chumash,
          );

          expect(
            chumashJourney.totalUnitsAvailable,
            5,
            reason:
                'F22/_countTotalUnits bug: the denominator must be the '
                '5 sefarim, not the 2 distinct chapter-number strings '
                "('1'/'2') this fixture's content carries — the real "
                'chumash.json has 50 distinct chapter numbers (Genesis '
                'alone), which is what actually produced the false '
                'curriculum-complete milestone on device.',
          );
          expect(
            vm.curriculumLevelSiyumimCount,
            0,
            reason:
                'NON-NEGOTIABLE (P0): a bulk-mark of 3 of 5 sefarim (61.6% '
                'in the real on-device scenario) must never fire a '
                'curriculum-level "Chumash complete!" milestone.',
          );
          expect(
            vm.unitLevelSiyumimCount,
            3,
            reason: 'one unit-level (sefer-scoped) siyum per completed sefer',
          );
          expect(
            vm.aggregateLevelSiyumimCount,
            0,
            reason:
                'Chumash has no real aggregate tier above sefer — '
                '_hasAggregateLevel must return false for it, not read the '
                'bare chapter-number groups as a meaningful aggregate tier',
          );
        },
      );

      test('5 of 5 sefarim: DOES fire the real curriculum-complete milestone '
          '(sanity — the fix must not permanently disable it)', () async {
        await markSefarim([
          'Genesis',
          'Exodus',
          'Leviticus',
          'Numbers',
          'Deuteronomy',
        ]);

        final vm = await readJourneyViewModel();

        expect(
          vm.curriculumLevelSiyumimCount,
          1,
          reason:
              'completing all 5 real sefarim must still fire the genuine '
              'curriculum-complete milestone — the P0 fix must not '
              'silently disable curriculum-level detection altogether',
        );
        expect(vm.unitLevelSiyumimCount, 5);
      });
    },
  );
}

/// Chumash-shaped content fixture — 5 sefarim × 2 chapters × 2 verses,
/// mirroring the REAL hierarchy in `assets/content/hierarchy/chumash.json`
/// (`level1`=sefer, `level2`=chapter, `level3`=verse, leaf at level3;
/// `hierarchyConfig: {levelLabels: [Sefer, Chapter, Verse], maxLevels: 3}`).
/// Deliberately reuses the SAME chapter numbers ('1', '2') across every
/// sefer — exactly like the real data, where every sefer's numbering
/// restarts at chapter 1 — so a fix that only works when chapter numbers
/// happen not to collide would still fail this fixture.
List<ContentItem> _chumashShapedFixture() {
  const sefarim = ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'];
  final items = <ContentItem>[];
  var sortOrder = 0;
  for (final sefer in sefarim) {
    for (final chapter in ['1', '2']) {
      for (final verse in ['1', '2']) {
        items.add(
          ContentItem(
            curriculumId: CurriculumId.chumash.storageKey,
            level1: sefer,
            level2: chapter,
            level3: verse,
            displayNameHe: '$sefer $chapter:$verse',
            displayNameEn: '$sefer $chapter:$verse',
            sefariaRef: '$sefer $chapter:$verse',
            sortOrder: sortOrder++,
            isLeaf: true,
          ),
        );
      }
    }
  }
  return items;
}
