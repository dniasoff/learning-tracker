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
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show ActiveProfileDocId, activeProfileDocIdProvider;
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/curriculum_progress_screen.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/content_fixtures.dart';
import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

const _uid = 'curriculum-progress-screen-user';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curriculumKey = 'mishnayos';
const CurriculumId _curriculum = CurriculumId.mishnayos;

class _MockFirebaseApp extends Mock implements FirebaseApp {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) =>
    AccountFirebaseHandles(
      app: _MockFirebaseApp(),
      firestore: firestore,
      auth: _MockFirebaseAuth(),
      uid: _uid,
    );

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
  @override
  String? build() => _profileId;
}

class _ActiveProfileDocIdOverride extends ActiveProfileDocId {
  @override
  String? build() => _profileId;
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
}) => ContentItemFixtures.leaf(
  curriculumId: _curriculumKey,
  level1: level1,
  level2: level2,
  sefariaRef: ref,
  sortOrder: sortOrder,
  displayNameHe: ref,
  displayNameEn: ref,
);

Future<void> _seedCompletion(
  FakeFirebaseFirestore firestore, {
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: _curriculum,
    sefariaRef: ref,
    stageId: stageId,
    completedAt: at,
    source: CompletionSource.live,
  );
}

Future<void> _seedLifetimeOnly(
  FakeFirebaseFirestore firestore, {
  required String ref,
  required int stageId,
  required DateTime at,
}) async {
  await seedLedgerEntry(
    firestore,
    uid: _uid,
    profileId: _profileId,
    ulid: '01ARZ3NDEKTSV4RRFFQ69G5FB0',
    curriculumId: _curriculum,
    entryScope: 'item',
    unitIdentifier: ref,
    unitDisplayNameEn: ref,
    completedAt: at,
    source: CompletionSource.lifetimeOnly,
  );
}

/// Default "Track progress" fixture used by every test in this file except
/// the one that pins the dual-stats percentages explicitly. An empty list
/// means `CurriculumProgressScreen`'s `dualMetric` lookup misses, so
/// `trackProgressFraction` is null and the row shows an em-dash — fine for
/// the tests below that don't assert on this value.
const _noDualMetrics = <TrackDualProgressMetric>[];

Widget _pump({
  required FakeFirebaseFirestore firestore,
  required ContentRepository repo,
  required StageDefinitionRepository stageRepo,
  required StackRouter router,
  bool useHebrew = false,
  List<TrackDualProgressMetric> dualMetrics = _noDualMetrics,
}) {
  return ProviderScope(
    overrides: [
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => _handles(firestore),
      ),
      activeProfileDocIdProvider.overrideWith(
        () => _ActiveProfileDocIdOverride(),
      ),
      contentRepositoryProvider.overrideWithValue(repo),
      activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
      useHebrewTermsProvider.overrideWith(
        () => _UseHebrewTermsOverride(useHebrew: useHebrew),
      ),
      stageDefinitionRepositoryProvider.overrideWith((ref, c) => stageRepo),
      // Data-consistency fix (run-9 audit): CurriculumProgressScreen now
      // watches trackDualProgressMetricsProvider so its "Track progress" row
      // agrees with the Progress hub / Track Detail. Overriding it directly
      // (rather than seeding real stage_definitions rows to drive the real
      // computation) mirrors the established pattern in
      // track_detail_screen_test.dart and avoids the provider's dependency
      // chain reaching FirebaseAuth (unavailable under `flutter test`).
      trackDualProgressMetricsProvider.overrideWith((ref) async => dualMetrics),
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
  late FakeFirebaseFirestore firestore;
  // The completion event log accepts arbitrary stageId integers (no FK to
  // stage_definitions), so we pick stable ids and supply matching domain
  // models through the fake stage repo.
  const learnStageId = 1;
  const chazara1StageId = 2;
  late List<ContentItem> leaves;
  late StageDefinitionRepository stageRepo;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);

    // 4 leaves grouped into one Berakhot level — keeps the level-2 row
    // distinct so the hierarchy subtitle assertion has a target.
    leaves = List.generate(
      4,
      (i) => _leaf('Mishnah Berakhot ${i + 1}:1', sortOrder: i),
    );

    stageRepo = _FakeStageDefinitionRepository([
      const domain_stage.StageDefinition(
        curriculumId: _curriculum,
        stageOrder: 1,
        stageName: 'Learned',
        delayDays: 0,
        isDefault: true,
      ),
      const domain_stage.StageDefinition(
        curriculumId: _curriculum,
        stageOrder: 2,
        stageName: 'Chazara 1',
        delayDays: 1,
        isDefault: true,
      ),
    ]);
  });

  tearDown(() {});

  testWidgets(
    'OverallStatsCard shows both Track progress and Lifetime headline rows',
    (tester) async {
      // Lifetime: 2 of 4 leaves touched (live ref + lifetimeOnly ref) → 50%.
      // (These completions no longer drive "Track progress" — see below —
      // but they still exercise the real lifetimeDataProvider computation.)
      await _seedCompletion(
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedCompletion(
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: chazara1StageId,
        at: DateTime.utc(2026, 5, 2, 10),
      );
      await _seedLifetimeOnly(
        firestore,
        ref: leaves[1].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 3, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      // Data-consistency fix (run-9 audit): "Track progress" is now sourced
      // from trackDualProgressMetricsProvider's currentCyclePercentage — the
      // SAME metric the Progress hub and Track Detail label "Track progress"
      // — rather than this screen's own completedAllStages/totalItems (the
      // pre-fix computation, which showed a DIFFERENT number under the
      // identical label; see curriculum_progress_screen.dart). Overriding the
      // provider directly (rather than driving the real time-gated
      // computation through seeded completions + track.activatedAt) keeps
      // the test deterministic and focused on what THIS test actually
      // verifies: the screen renders whatever the shared metric provider
      // says, under the shared label. The provider's own computation is
      // covered by track_dual_progress_metrics_batch_test.dart.
      await tester.pumpWidget(
        _pump(
          firestore: firestore,
          repo: repo,
          stageRepo: stageRepo,
          router: router,
          dualMetrics: [
            TrackDualProgressMetric(
              trackLabel: 'Mishnayos',
              curriculumId: CurriculumId.mishnayos,
              currentCyclePercentage: 0.25,
              lifetimePercentage: 0.9, // unused by this screen — see below
              isProgramTrack: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The dual-stats cell renders the label and the big percentage value as
      // two separate lines (W5-A layout fix), so we assert each independently.
      expect(
        find.text('Track progress'),
        findsOneWidget,
        reason:
            'Track progress shows the time-gated currentCyclePercentage from '
            'trackDualProgressMetricsProvider — the same source Progress hub '
            'and Track Detail use for the identical label.',
      );
      expect(
        find.descendant(
          of: find.byType(OverallStatsCard),
          matching: find.text('25%'),
        ),
        findsOneWidget,
      );

      // Lifetime: 2 of 4 leaves have at least one completion (live ref +
      // lifetimeOnly ref) → 50%.
      expect(
        find.text('Lifetime'),
        findsOneWidget,
        reason:
            'Lifetime % includes every completion source (live + bulkInTrack '
            '+ lifetimeOnly) so the lifetimeOnly leaf is counted here even '
            'though it is excluded from Track progress',
      );
      expect(
        find.descendant(
          of: find.byType(OverallStatsCard),
          matching: find.text('50%'),
        ),
        findsOneWidget,
      );

      // The legacy breakdown rows remain — the dual-stats row is additive.
      expect(find.text('Total items'), findsOneWidget);
      expect(find.text('Completed all stages'), findsOneWidget);
    },
  );

  // Data-consistency fix (run-9 audit) — dedicated regression pin.
  //
  // Run-9 found "Track progress: 0.1%" on the Progress hub / Track Detail
  // but "Track progress: 3%" on THIS screen for the identical track — a
  // ~30x discrepancy under one label. Root cause: this screen computed its
  // own all-time `completedAllStages / totalItems` fraction instead of
  // reading the same `trackDualProgressMetricsProvider.currentCyclePercentage`
  // the other two surfaces use.
  //
  // This test seeds exactly ONE leaf fully complete (both stages, live). The
  // pre-fix formula (completedAllStages/totalItems = 1/4) and the real
  // lifetimeDataProvider computation (1 of 4 leaves ever touched = 1/4) both
  // land on the SAME 25% — a deliberate coincidence that makes this a strong
  // negative check: under the pre-fix code, BOTH "Track progress" and
  // "Lifetime" would read 25% (two matches for "25%" in the card). The fixed
  // metric is pinned via override to a different value (10%), so the fixed
  // card must show "25%" exactly ONCE (under Lifetime only) and "10%" exactly
  // once (under Track progress) — proving the screen no longer falls back to
  // its own all-time recomputation under the shared label.
  testWidgets(
    'Track progress shows the time-gated currentCyclePercentage, NOT the '
    'all-time completedAllStages/totalItems figure, when the two diverge',
    (tester) async {
      await _seedCompletion(
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedCompletion(
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: chazara1StageId,
        at: DateTime.utc(2026, 5, 2, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(
          firestore: firestore,
          repo: repo,
          stageRepo: stageRepo,
          router: router,
          dualMetrics: [
            TrackDualProgressMetric(
              trackLabel: 'Mishnayos',
              curriculumId: CurriculumId.mishnayos,
              currentCyclePercentage: 0.10,
              lifetimePercentage: 0.9, // unused by this screen — see above
              isProgramTrack: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // "25%" must appear exactly ONCE — under Lifetime only. Under the
      // pre-fix code it would ALSO appear under Track progress (findsNWidgets
      // would be 2), since completedAllStages/totalItems coincides with the
      // real lifetime fraction for this fixture.
      expect(
        find.descendant(
          of: find.byType(OverallStatsCard),
          matching: find.text('25%'),
        ),
        findsOneWidget,
        reason:
            'The all-time completedAllStages/totalItems figure (25% here) '
            'must not ALSO render under "Track progress" — that was the '
            'run-9 mislabel. It should only appear once, under Lifetime.',
      );
      expect(
        find.descendant(
          of: find.byType(OverallStatsCard),
          matching: find.text('10%'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'PaceIndicator surfaces the "Pace tracks track learning only." caption',
    (tester) async {
      // The pace provider requires both a goal and an active curriculum track
      // before it can compute a real PaceStatus rather than returning null.
      await seedTrack(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: _curriculum,
        activatedAt: DateTime.utc(2026, 1, 1),
      );
      await seedGoal(
        firestore,
        uid: _uid,
        profileId: _profileId,
        curriculumId: _curriculum,
        targetDate: DateTime.utc(2026, 12, 31),
        createdAt: DateTime.utc(2026, 1, 1),
      );

      // One live completion so the pace calc has something to work with.
      await _seedCompletion(
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(
          firestore: firestore,
          repo: repo,
          stageRepo: stageRepo,
          router: router,
        ),
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
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedCompletion(
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: chazara1StageId,
        at: DateTime.utc(2026, 5, 2, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(
          firestore: firestore,
          repo: repo,
          stageRepo: stageRepo,
          router: router,
        ),
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
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedCompletion(
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: chazara1StageId,
        at: DateTime.utc(2026, 5, 2, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(
          firestore: firestore,
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
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        _pump(
          firestore: firestore,
          repo: repo,
          stageRepo: stageRepo,
          router: router,
        ),
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
        firestore,
        ref: leaves[0].sefariaRef,
        stageId: learnStageId,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final repo = _FakeContentRepository(leaves);
      final router = _RecordingRouter([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => _handles(firestore),
            ),
            activeProfileDocIdProvider.overrideWith(
              () => _ActiveProfileDocIdOverride(),
            ),
            contentRepositoryProvider.overrideWithValue(repo),
            activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
            useHebrewTermsProvider.overrideWith(
              () => _UseHebrewTermsOverride(useHebrew: false),
            ),
            stageDefinitionRepositoryProvider.overrideWith(
              (ref, c) => stageRepo,
            ),
            trackDualProgressMetricsProvider.overrideWith(
              (ref) async => _noDualMetrics,
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
        reason: 'CP-01: The English literal must not appear when locale is he.',
      );
    },
  );

  // AUD-progress-12 regression: the settings-gear IconButton's `tooltip:`
  // parameter was a hard-coded English literal ('Curriculum settings'),
  // so a Hebrew-locale user long-pressing the gear saw English in an
  // otherwise fully-Hebrew screen. It must come from the
  // `curriculumProgressSettingsTooltip` ARB key instead.
  testWidgets('AUD-progress-12: settings gear tooltip comes from l10n, not a '
      'hard-coded literal', (tester) async {
    final repo = _FakeContentRepository(leaves);
    final router = _RecordingRouter([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountFirebaseProvider.overrideWith(
            (ref) async => _handles(firestore),
          ),
          activeProfileDocIdProvider.overrideWith(
            () => _ActiveProfileDocIdOverride(),
          ),
          contentRepositoryProvider.overrideWithValue(repo),
          activeProfileIdProvider.overrideWith(() => _ProfileIdOverride()),
          useHebrewTermsProvider.overrideWith(
            () => _UseHebrewTermsOverride(useHebrew: false),
          ),
          stageDefinitionRepositoryProvider.overrideWith((ref, c) => stageRepo),
          trackDualProgressMetricsProvider.overrideWith(
            (ref) async => _noDualMetrics,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('he'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StackRouterScope(
            controller: router,
            stateHash: 0,
            child: const CurriculumProgressScreen(curriculumId: _curriculumKey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Under the he locale the settings gear tooltip must render the
    // Hebrew ARB value, not the English literal. A hard-coded English
    // literal would fail this assertion.
    expect(
      find.byTooltip('הגדרות קורס הלימוד'),
      findsOneWidget,
      reason:
          'AUD-progress-12: the settings gear tooltip must come from the '
          'curriculumProgressSettingsTooltip ARB key so Hebrew-locale '
          'users see a localized tooltip, not the English literal '
          '"Curriculum settings".',
    );
    expect(
      find.byTooltip('Curriculum settings'),
      findsNothing,
      reason:
          'AUD-progress-12: the English literal tooltip must not appear '
          'when locale is he.',
    );
  });

  // ── P2 fix (deferred/track-rename-propagation) ────────────────────────────
  // This screen is reached exclusively from the Progress-hub per-track row
  // for one specific track (W3.22: one track per {profileId, curriculumId}),
  // so its AppBar title is that track's own identity label — it must honour
  // a custom track name the same way Track Detail does (B-EDIT-NAME,
  // commit 00048c68) instead of always showing the raw curriculum label.
  group('P2 — AppBar title surfaces a custom track name', () {
    testWidgets(
      'a track renamed via Goal.description shows the custom name in the '
      'AppBar title, not the curriculum label',
      (tester) async {
        await seedGoal(
          firestore,
          uid: _uid,
          profileId: _profileId,
          curriculumId: _curriculum,
          description: 'My Shas Journey',
          createdAt: DateTimeFactory.nowUtc(),
        );

        final repo = _FakeContentRepository(leaves);
        final router = _RecordingRouter([]);

        await tester.pumpWidget(
          _pump(
            firestore: firestore,
            repo: repo,
            stageRepo: stageRepo,
            router: router,
            dualMetrics: [
              TrackDualProgressMetric(
                trackLabel: 'Mishnayos',
                curriculumId: CurriculumId.mishnayos,
                currentCyclePercentage: 0.25,
                lifetimePercentage: 0.5,
                isProgramTrack: false,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Pre-fix the header always showed the curriculum label and ignored
        // the edited name. The custom name must now surface in the title.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('My Shas Journey'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Mishnayos'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'no custom name (no goal seeded) → AppBar title falls back to the '
      'curriculum label',
      (tester) async {
        final repo = _FakeContentRepository(leaves);
        final router = _RecordingRouter([]);

        await tester.pumpWidget(
          _pump(
            firestore: firestore,
            repo: repo,
            stageRepo: stageRepo,
            router: router,
            dualMetrics: [
              TrackDualProgressMetric(
                trackLabel: 'Mishnayos',
                curriculumId: CurriculumId.mishnayos,
                currentCyclePercentage: 0.25,
                lifetimePercentage: 0.5,
                isProgramTrack: false,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Mishnayos'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
