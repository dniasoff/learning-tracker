/// W5-A regression tests for the Curriculum Progress screen.
///
/// Covers the Phase E dual-stats split:
///   * `OverallStatsCard` now surfaces two headline percentages — Track
///     progress (current cycle, achievement tier) and Lifetime (% of items
///     ever touched, including bulk-mark / lifetimeOnly imports).
///   * The `PaceIndicator` carries the "Pace tracks track learning only."
///     caption so users can disambiguate pace from lifetime tier.
///   * Hierarchy row subtitles use the new "N chazaros" vocabulary instead
///     of the legacy raw "N completions" suffix.
///
/// Tests drive the real screen against in-memory Drift + fake content +
/// fake stage repository so the dual-stat math is exercised end-to-end.
@Tags(['progress', 'curriculum_progress'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumKey = 'mishnayos';
const CurriculumId _curriculum = CurriculumId.mishnayos;

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeContentRepository implements ContentRepository {
  _FakeContentRepository(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    if (curriculumId != _curriculum) return const [];
    return _items;
  }

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async {
    return CurriculumHierarchyConfig(
      curriculumId: curriculumId.storageKey,
      levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
      totalItems: _items.where((i) => i.isLeaf).length,
    );
  }

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
  }) async => _items;

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

/// Minimal stage repository — `compute` only reads [getStagesForCurriculum].
class _FakeStageDefinitionRepository extends Fake
    implements StageDefinitionRepository {
  _FakeStageDefinitionRepository(this._stages);
  final List<domain_stage.StageDefinition> _stages;

  @override
  Future<List<domain_stage.StageDefinition>> getStagesForCurriculum(
    CurriculumId c,
  ) async => _stages;
}

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

/// Forces the Hebrew Terms toggle to a known value so English assertions
/// remain stable across test environments — the production default is ON.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

class _RecordingRouter extends Fake implements StackRouter {
  _RecordingRouter(this.pushed);
  final List<String> pushed;
  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route.routeName);
    return null;
  }
}

ContentItem _leaf(
  String ref, {
  String level1 = 'Zeraim',
  String level2 = 'Berakhot',
  int sortOrder = 0,
}) => ContentItem(
  curriculumId: _curriculumKey,
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

Future<void> _seedCompletion(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumKey,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: at,
    ),
  );
}

Future<void> _seedLifetimeOnly(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await _seedCompletion(
    db,
    trackId: trackId,
    ref: ref,
    stageId: stageId,
    at: at,
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumKey,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

Widget _pump({
  required UserDatabase db,
  required ContentRepository repo,
  required StageDefinitionRepository stageRepo,
  required StackRouter router,
  bool useHebrew = false,
}) {
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      contentRepositoryProvider.overrideWithValue(repo),
      activeProfileIdProvider.overrideWith(
        () => _ProfileIdOverride(_profileId),
      ),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: useHebrew),
      ),
      stageDefinitionRepositoryProvider.overrideWith((ref, c) => stageRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const CurriculumProgressScreen(curriculumId: _curriculumKey),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;
  // The completion event log accepts arbitrary stageId integers (no FK to
  // stage_definitions), so we pick stable ids and supply matching domain
  // models through the fake stage repo.
  const learnStageId = 1;
  const chazara1StageId = 2;
  late List<ContentItem> leaves;
  late StageDefinitionRepository stageRepo;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumKey,
    );

    // 4 leaves grouped into one Berakhot level — keeps the level-2 row
    // distinct so the hierarchy subtitle assertion has a target.
    leaves = List.generate(
      4,
      (i) => _leaf('Mishnah Berakhot ${i + 1}:1', sortOrder: i),
    );

    stageRepo = _FakeStageDefinitionRepository([
      const domain_stage.StageDefinition(
        id: learnStageId,
        curriculumId: _curriculum,
        stageOrder: 1,
        stageName: 'Learned',
        delayDays: 0,
        isDefault: true,
      ),
      const domain_stage.StageDefinition(
        id: chazara1StageId,
        curriculumId: _curriculum,
        stageOrder: 2,
        stageName: 'Chazara 1',
        delayDays: 1,
        isDefault: true,
      ),
    ]);
  });

  tearDown(() => db.close());

  testWidgets(
    'OverallStatsCard shows both Track progress and Lifetime headline rows',
    (tester) async {
      // 1 ref completed through both stages → counts as Track-progress (1/4
      // fully done) → 25%. Same ref is "lifetime" too. Plus one lifetimeOnly
      // ref that should bump Lifetime to 2/4 (50%) but not Track.
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: chazara1StageId,
        at: DateTime.utc(2026, 5, 2, 10),
      );
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: leaves[1].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 3, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(db: db, repo: repo, stageRepo: stageRepo, router: router),
      );
      await tester.pumpAndSettle();

      // Track-progress: 1 of 4 items has completed both stages → 25%.
      expect(
        find.text('Track progress: 25%'),
        findsOneWidget,
        reason:
            'Track progress shows the % of items that have completed every '
            'stage (the existing "completedAllStages" bucket)',
      );

      // Lifetime: 2 of 4 leaves have at least one completion (live ref +
      // lifetimeOnly ref) → 50%.
      expect(
        find.text('Lifetime: 50%'),
        findsOneWidget,
        reason:
            'Lifetime % includes every completion source (live + bulkInTrack '
            '+ lifetimeOnly) so the lifetimeOnly leaf is counted here even '
            'though it is excluded from Track progress',
      );

      // The legacy breakdown rows remain — the dual-stats row is additive.
      expect(find.text('Total items'), findsOneWidget);
      expect(find.text('Completed all stages'), findsOneWidget);
    },
  );

  testWidgets(
    'PaceIndicator surfaces the "Pace tracks track learning only." caption',
    (tester) async {
      // Seed a goal so the pace provider returns a real PaceStatus rather
      // than null. A target date in the future + zero personal completions
      // is enough to drive the indicator's "behind" branch.
      await db
          .into(db.goals)
          .insert(
            GoalsCompanion.insert(
              profileId: _profileId,
              curriculumId: _curriculumKey,
              trackId: trackId,
              targetDate: Value(DateTime.utc(2026, 12, 31)),
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      // One live completion so the pace calc has something to work with.
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(db: db, repo: repo, stageRepo: stageRepo, router: router),
      );
      await tester.pumpAndSettle();

      // The caption now comes from the l10n key `paceLiveLearningOnlyCaption`
      // (F10 fix — the inline English literal + TODO(l10n) comment was
      // replaced by a real ARB-driven string). The default English template
      // is unchanged, so we still assert against the same text — but the
      // test now exercises the AppLocalizations resolution path.
      expect(
        find.text('Pace tracks track learning only.'),
        findsOneWidget,
        reason:
            'The disambiguating caption must render under the PaceIndicator '
            'so users do not conflate pace with lifetime tier',
      );
    },
  );

  testWidgets(
    'Hierarchy row subtitle uses "N chazaros" instead of the legacy raw '
    'completion suffix',
    (tester) async {
      // 2 stage events under Berakhot — both rows count toward chazaros.
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: chazara1StageId,
        at: DateTime.utc(2026, 5, 2, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(db: db, repo: repo, stageRepo: stageRepo, router: router),
      );
      await tester.pumpAndSettle();

      // Level-1 subtitle: 1/4 unique items touched at 25.00%.
      // The hierarchy subtitle now shows ONLY chazara-stage events (stages
      // after the first learn stage). One chazara event was seeded for
      // leaves[0] (chazara1StageId) → "1 chazaros".
      expect(
        find.textContaining('· 1 chazaros'),
        findsWidgets,
        reason:
            'Hierarchy row subtitle shows chazara-only count (stages after '
            'the first). One chazara event was seeded → "1 chazaros".',
      );
    },
  );

  testWidgets(
    'Hebrew Terms toggle renders the chazaros suffix in Hebrew script',
    (tester) async {
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: chazara1StageId,
        at: DateTime.utc(2026, 5, 2, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(
          db: db,
          repo: repo,
          stageRepo: stageRepo,
          router: router,
          useHebrew: true,
        ),
      );
      await tester.pumpAndSettle();

      // Same as the English test but with Hebrew script. One chazara event
      // seeded → "1 חזרות" (singular-form plural is used in Hebrew for counts
      // per the terms vocab).
      expect(
        find.textContaining('· 1 חזרות'),
        findsWidgets,
        reason:
            'When the Hebrew Terms toggle is ON, the chazaros suffix must '
            'render with the Hebrew plural ("חזרות") instead of the '
            'transliteration. One chazara event seeded → "1 חזרות".',
      );
    },
  );

  // CP-01 regression: 'Breakdown by Level', 'Loading progress...', and
  // 'Failed to load progress: $error' were hard-coded English literals in the
  // screen. They must be driven by l10n keys so Hebrew users see localised
  // text. The tests below assert the English locale renders the correct text
  // from the ARB string (not from a residual literal), and that the Hebrew
  // locale renders the Hebrew translation.
  testWidgets(
    'CP-01: "Breakdown by Level" heading comes from l10n, not a hard-coded literal',
    (tester) async {
      // Seed one completion so the screen renders the data path that shows the
      // hierarchy section with the "Breakdown by Level" heading.
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(db: db, repo: repo, stageRepo: stageRepo, router: router),
      );
      await tester.pumpAndSettle();

      // English locale: the ARB value equals the old hard-coded string, so
      // this passes regardless — but it pins the contract that this text is
      // ARB-driven.
      expect(
        find.text('Breakdown by Level'),
        findsOneWidget,
        reason:
            'CP-01: The hierarchy section heading must come from the '
            'curriculumProgressBreakdownByLevel ARB key, not a hard-coded '
            'English literal.',
      );
    },
  );

  testWidgets(
    'CP-01: "Breakdown by Level" heading renders Hebrew in he locale',
    (tester) async {
      await _seedCompletion(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(repo),
            activeProfileIdProvider.overrideWith(
              () => _ProfileIdOverride(_profileId),
            ),
            useHebrewTermsProvider.overrideWith(
              () => _UseHebrewTermsOverride(useHebrew: false),
            ),
            stageDefinitionRepositoryProvider.overrideWith(
              (ref, c) => stageRepo,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('he'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: const CurriculumProgressScreen(
                curriculumId: _curriculumKey,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hebrew locale must render the Hebrew ARB value, NOT the English literal.
      expect(
        find.text('פירוט לפי רמה'),
        findsOneWidget,
        reason:
            'CP-01: Under the he locale the hierarchy heading must render the '
            'Hebrew translation ("פירוט לפי רמה") not the English literal '
            '"Breakdown by Level". A hard-coded English literal would fail '
            'this assertion.',
      );
      expect(
        find.text('Breakdown by Level'),
        findsNothing,
        reason:
            'CP-01: The English literal must not appear when locale is he.',
      );
    },
  );
}
