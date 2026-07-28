/// Regression tests for the new Lifetime Knowledge screen (W3-C / Task #11).
///
/// Drives data through real [ProviderContainer]s over an in-memory Drift
/// database; the screen is rendered via [pumpWidget] for the CTA navigation
/// check. Covers the four scenarios in the W3-C brief:
///
///   1. Header counter test — N distinct items + M total chazaros across a
///      mix of live + bulkInTrack + lifetimeOnly seeds (All-sources toggle).
///   2. Toggle test — flipping to "Track learning only" drops lifetimeOnly
///      rows from both the header tier provider's underlying summaries
///      (verified via [itemsLearnedSummariesProvider]) and from the
///      per-curriculum tree breakdown.
///   3. Provenance label test — `LifetimeLeafProvenance` reflects how each
///      leaf entered ("Live · N chazaros" / "Bulk-marked" /
///      "Lifetime · imported").
///   4. CTA test — tapping the "Add items I learned previously" card pushes
///      [LifetimeMarkingRoute] (assert via the captured navigation event).
@Tags(['progress', 'lifetime_knowledge'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_knowledge_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/content_fixtures.dart';
import '../../../../helpers/drift_memory.dart';

const _profileId = 1;
const _curriculumKey = 'mishnayos';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _FakeContentRepository extends Fake implements ContentRepository {
  _FakeContentRepository(this._leaves);

  final List<ContentItem> _leaves;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    if (curriculumId.storageKey != _curriculumKey) return const [];
    return _leaves;
  }
}

class _ProfileIdOverride extends ActiveProfileId {
  _ProfileIdOverride(this._id);
  final int _id;
  @override
  int build() => _id;
}

class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

/// Minimal [ProfileModel] fixture for [activeProfileProvider] overrides —
/// only `mode` varies across the CTA-visibility tests below.
ProfileModel _profileModel({required String mode}) => ProfileModel(
  id: _profileId,
  accountId: 1,
  displayName: 'Test User',
  mode: mode,
  avatarIndex: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Seed helpers — mirror the patterns in story_i3_items_learned_test.dart so
// the regression tests exercise the same flow the production wiring uses.
// ---------------------------------------------------------------------------

Future<void> _seedLive(
  UserDatabase db, {
  required int trackId,
  required String ref,
  required int stageId,
  required DateTime at,
}) {
  return db.completionEventDao.appendEvent(
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

Future<void> _seedBulkInTrack(
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
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumKey,
      sefariaRef: ref,
      stageId: stageId,
      trackType: 'personal',
      source: 'bulkInTrack',
    ),
  ]);
}

Future<void> _seedLifetimeOnly(
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

ContentItem _leaf(
  String ref, {
  String level1 = 'Zeraim',
  String level2 = 'Berakhot',
  int sortOrder = 0,
}) {
  return ContentItemFixtures.leaf(
    curriculumId: _curriculumKey,
    level1: level1,
    level2: level2,
    sefariaRef: ref,
    sortOrder: sortOrder,
    displayNameHe: ref,
    displayNameEn: ref,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;
  late _FakeContentRepository fakeRepo;

  // Two distinct refs per provenance class so a "drops one source" toggle
  // produces a counter delta larger than one.
  late List<ContentItem> leaves;

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumKey,
    );

    // 8 leaves in Berakhot, sorted.
    leaves = List.generate(
      8,
      (i) => _leaf('Mishnah Berakhot ${i + 1}:1', sortOrder: i),
    );
    fakeRepo = _FakeContentRepository(leaves);
  });

  tearDown(() => db.close());

  ProviderContainer buildContainer({bool useHebrew = false}) {
    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWith((ref) => db),
        contentRepositoryProvider.overrideWithValue(fakeRepo),
        activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
        useHebrewTermsProvider.overrideWith(
          () => _UseHebrewTermsOverride(useHebrew: useHebrew),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // ─── Test 1 — Header counters ──────────────────────────────────────────

  group('header counters (All sources)', () {
    test(
      'reflects distinct sefariaRefs across live + bulkInTrack + lifetimeOnly '
      'with M total event rows for chazaros',
      () async {
        // 2 live refs, each with 2 events (stage 1 + stage 2) → 4 events,
        // 2 distinct refs.
        for (final i in [0, 1]) {
          await _seedLive(
            db,
            trackId: trackId,
            ref: leaves[i].sefariaRef,
            stageId: 1,
            at: DateTime.utc(2026, 5, 1, 10),
          );
          await _seedLive(
            db,
            trackId: trackId,
            ref: leaves[i].sefariaRef,
            stageId: 2,
            at: DateTime.utc(2026, 5, 2, 10),
          );
        }
        // 1 bulkInTrack ref → 1 event, 1 distinct ref.
        await _seedBulkInTrack(
          db,
          trackId: trackId,
          ref: leaves[2].sefariaRef,
          stageId: 1,
          at: DateTime.utc(2026, 5, 3, 10),
        );
        // 1 lifetimeOnly ref → 1 event, 1 distinct ref.
        await _seedLifetimeOnly(
          db,
          trackId: trackId,
          ref: leaves[3].sefariaRef,
          stageId: 1,
          at: DateTime.utc(2026, 5, 4, 10),
        );

        // Expected: 4 distinct items learned; 2 chazaros total.
        // PP-4 fix: totalChazaros counts only REVIEW events (stageId > 1).
        // Of the seeded rows only the two stage-2 live events are chazaros;
        // the stage-1 live/bulk/lifetime rows are limud and are excluded.
        final container = buildContainer();
        final counters = await container.read(
          lifetimeHeaderCountersProvider(_profileId).future,
        );

        expect(
          counters.itemsLearned,
          4,
          reason:
              'All sources view counts distinct refs from live, bulkInTrack '
              'and lifetimeOnly — including the lifetimeOnly leaf',
        );
        expect(
          counters.totalChazaros,
          2,
          reason:
              'PP-4: only review events (stageId > 1) count as chazaros. '
              'Of 6 event rows only the 2 stage-2 live events are chazaros; '
              'the stage-1 live/bulk/lifetime rows are limud, not chazaros.',
        );
      },
    );
  });

  // ─── Test 2 — Toggle drops lifetimeOnly ───────────────────────────────

  group('source toggle', () {
    test('"Track learning only" excludes lifetimeOnly refs from the counters '
        'AND from the per-curriculum tree breakdown', () async {
      // Use per-ref level2 hierarchy so the tree contains one terminal
      // node per source, making the toggle-driven drop observable.
      final perRefLeaves = [
        _leaf('Mishnah Berakhot 1:1', level2: 'A_live', sortOrder: 0),
        _leaf('Mishnah Berakhot 1:2', level2: 'B_bulk', sortOrder: 1),
        _leaf('Mishnah Berakhot 1:3', level2: 'C_lifetime', sortOrder: 2),
      ];
      fakeRepo = _FakeContentRepository(perRefLeaves);

      await _seedLive(
        db,
        trackId: trackId,
        ref: perRefLeaves[0].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedBulkInTrack(
        db,
        trackId: trackId,
        ref: perRefLeaves[1].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 2, 10),
      );
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: perRefLeaves[2].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 3, 10),
      );

      final container = buildContainer();

      // All sources path (default toggle).
      final allSummaries = await container.read(
        lifetimeViewSummariesProvider(_profileId).future,
      );
      final allMishnayos = allSummaries.firstWhere(
        (s) => s.curriculumId == CurriculumId.mishnayos,
      );
      expect(
        allMishnayos.learnedLeafCount,
        3,
        reason: 'All sources includes live + bulkInTrack + lifetimeOnly = 3',
      );
      final allTerminals = _collectTerminalNodes(allMishnayos.tree);
      final allTerminalValues = allTerminals.map((n) => n.rawValue).toSet();
      expect(
        allTerminalValues,
        containsAll(<String>['A_live', 'B_bulk', 'C_lifetime']),
        reason: 'All sources tree must contain all three terminal nodes',
      );

      // Track learning only path (toggle flipped).
      final trackSummaries = await container.read(
        itemsLearnedSummariesProvider(_profileId).future,
      );
      final trackMishnayos = trackSummaries.firstWhere(
        (s) => s.curriculumId == CurriculumId.mishnayos,
      );
      expect(
        trackMishnayos.learnedLeafCount,
        2,
        reason:
            'Track-only path excludes lifetimeOnly via the '
            'CompletionTierFilter.trackAchievement DAO filter',
      );

      // Inside the tree, every leaf node exists for both toggles (the
      // structure mirrors the curriculum content, not the user's data).
      // The toggle's observable effect on the tree is the per-node STATE:
      //   * lifetime view → C_lifetime is "full" (it counts as learned).
      //   * track-only view → C_lifetime is "none" (the ref is filtered).
      // Lookup terminals by rawValue and assert the state delta.
      final allTerminalByValue = {for (final n in allTerminals) n.rawValue: n};
      expect(
        allTerminalByValue['C_lifetime']?.state,
        LifetimeNodeState.full,
        reason:
            'lifetime view treats C_lifetime as fully learned via the '
            'lifetimeOnly import path',
      );

      final trackTerminals = _collectTerminalNodes(trackMishnayos.tree);
      final trackTerminalByValue = {
        for (final n in trackTerminals) n.rawValue: n,
      };
      expect(
        trackTerminalByValue['A_live']?.state,
        LifetimeNodeState.full,
        reason: 'track-only view keeps the live leaf as full',
      );
      expect(
        trackTerminalByValue['B_bulk']?.state,
        LifetimeNodeState.full,
        reason: 'track-only view keeps the bulkInTrack leaf as full',
      );
      expect(
        trackTerminalByValue['C_lifetime']?.state,
        LifetimeNodeState.none,
        reason:
            'track-only view must report the lifetimeOnly leaf as NONE — '
            'the underlying completion is filtered out at the DAO level',
      );
    });
  });

  // ─── Test 3 — Provenance labels ───────────────────────────────────────

  group('per-leaf provenance', () {
    test('with per-ref level2 hierarchy, terminal nodes carry the correct '
        'LifetimeLeafProvenance for live / bulk / lifetime sources', () async {
      // Override the fixture to use a unique level2 per ref so the tree
      // groups one leaf per terminal node — provenance is unambiguous.
      final perRefLeaves = [
        _leaf('Mishnah Berakhot 1:1', level2: 'A', sortOrder: 0),
        _leaf('Mishnah Berakhot 1:2', level2: 'B', sortOrder: 1),
        _leaf('Mishnah Berakhot 1:3', level2: 'C', sortOrder: 2),
      ];
      fakeRepo = _FakeContentRepository(perRefLeaves);

      // 1 live ref with 3 stage events (live · 3 chazaros).
      for (final stage in [1, 2, 3]) {
        await _seedLive(
          db,
          trackId: trackId,
          ref: perRefLeaves[0].sefariaRef,
          stageId: stage,
          at: DateTime.utc(2026, 5, stage, 10),
        );
      }
      // 1 bulkInTrack ref.
      await _seedBulkInTrack(
        db,
        trackId: trackId,
        ref: perRefLeaves[1].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 4, 10),
      );
      // 1 lifetimeOnly ref.
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: perRefLeaves[2].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 5, 10),
      );

      final container = buildContainer();
      final summary = await container.read(
        lifetimeDataProvider((
          profileId: _profileId,
          curriculumId: CurriculumId.mishnayos,
        )).future,
      );
      expect(summary, isNotNull);

      final terminalNodes = _collectTerminalNodes(summary!.tree);
      // One terminal per level2 group; there are 3 level2 groups (A, B, C).
      expect(terminalNodes, hasLength(3));

      LifetimeTreeNode nodeFor(String rawValue) =>
          terminalNodes.firstWhere((n) => n.rawValue == rawValue);

      final liveNode = nodeFor('A');
      expect(liveNode.provenance, isNotNull);
      expect(liveNode.provenance!.source, LifetimeLeafSource.live);
      expect(
        liveNode.provenance!.chazarosCount,
        3,
        reason: 'three stage events → chazaros = 3',
      );

      final bulkNode = nodeFor('B');
      expect(bulkNode.provenance, isNotNull);
      expect(bulkNode.provenance!.source, LifetimeLeafSource.bulkMarked);

      final lifetimeNode = nodeFor('C');
      expect(lifetimeNode.provenance, isNotNull);
      expect(
        lifetimeNode.provenance!.source,
        LifetimeLeafSource.lifetimeImported,
      );
    });
  });

  // ─── F3 — Toggle-aware header counters ─────────────────────────────────
  //
  // The header counters must follow the source toggle: "All sources" uses
  // `lifetimeHeaderCountersProvider` (lifetimeOnly imports included);
  // "Track only" uses the new `trackOnlyHeaderCountersProvider`
  // (CompletionTierFilter.trackAchievement — lifetimeOnly excluded).
  // Without this fix the header would always show lifetime totals even
  // when the user flips the toggle to Track-only.

  group('F3 — header counters branch on source toggle', () {
    test('trackOnlyHeaderCountersProvider excludes lifetimeOnly imports '
        'while lifetimeHeaderCountersProvider keeps them', () async {
      // Seed: 1 live ref (2 events) + 1 bulkInTrack + 1 lifetimeOnly.
      // PP-4: totalChazaros counts only review events (stageId > 1), so the
      // only chazara here is the single stage-2 live event.
      // All-sources expected: 3 items, 1 chazara.
      // Track-only expected:  2 items, 1 chazara (lifetimeOnly item dropped;
      // the lone chazara is a live event, present in both views).
      await _seedLive(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 1, 10),
      );
      await _seedLive(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: 2,
        at: DateTime.utc(2026, 5, 2, 10),
      );
      await _seedBulkInTrack(
        db,
        trackId: trackId,
        ref: leaves[1].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 3, 10),
      );
      await _seedLifetimeOnly(
        db,
        trackId: trackId,
        ref: leaves[2].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 4, 10),
      );

      final container = buildContainer();

      // All-sources counters: includes lifetimeOnly leaf.
      final all = await container.read(
        lifetimeHeaderCountersProvider(_profileId).future,
      );
      expect(
        all.itemsLearned,
        3,
        reason: '1 live + 1 bulk + 1 lifetimeOnly = 3 distinct items',
      );
      expect(
        all.totalChazaros,
        1,
        reason:
            'PP-4: only review events (stageId > 1) count — the single '
            'stage-2 live event; the stage-1 bulk/lifetime/live rows are limud',
      );

      // Track-only counters: lifetimeOnly excluded at the SQL layer via
      // CompletionTierFilter.trackAchievement.
      final track = await container.read(
        trackOnlyHeaderCountersProvider(_profileId).future,
      );
      expect(
        track.itemsLearned,
        2,
        reason:
            'Track-only must drop the lifetimeOnly ref — 1 live + 1 bulk = 2',
      );
      expect(
        track.totalChazaros,
        1,
        reason:
            'PP-4: Track-only chazaros = the single stage-2 live review event. '
            'The stage-1 bulk row is limud (not a chazara) and the lifetimeOnly '
            'event is filtered out by tier — both views see the same lone '
            'chazara.',
      );

      // Strict delta — flipping the toggle MUST move the items count (the
      // lifetimeOnly leaf is the distinguishing seed). The chazaros count is
      // unaffected here because the only review event is a live event present
      // in both views (PP-4 makes limud rows not contribute to chazaros).
      expect(
        track.itemsLearned,
        lessThan(all.itemsLearned),
        reason:
            'Regression guard: with a lifetimeOnly seed present, the '
            'Track-only items count must be strictly smaller than the '
            'All-sources count',
      );
      expect(track.totalChazaros, lessThanOrEqualTo(all.totalChazaros));
    });
  });

  // ─── F13 — N+1 perf assertion ──────────────────────────────────────────
  //
  // Loading all 9 curricula in parallel via lifetimeSummariesProvider must
  // share the new batched providers — completionsByProfileForLifetimeProvider
  // and priorImportsByProfileProvider — exactly ONCE each, not per
  // curriculum. We assert that via a ProviderObserver that counts
  // `didAddProvider` events for those provider IDs across the 9-curriculum
  // resolution.

  group('F13 — N+1 perf assertion', () {
    test('opening all 9 curricula in parallel resolves the batched providers '
        'exactly once each (shared across consumers)', () async {
      // Make leaves available for every curriculum so the data path runs
      // end-to-end (the legacy fixture only covered mishnayos).
      final allCurriculumRepo = _AllCurriculumFakeRepo(leaves);

      // Seed minimal data so the provider returns non-null summaries.
      await _seedLive(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final observer = _CountingObserver();
      final container = ProviderContainer(
        observers: [observer],
        overrides: [
          userDatabaseProvider.overrideWith((ref) => db),
          contentRepositoryProvider.overrideWithValue(allCurriculumRepo),
          activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
          useHebrewTermsProvider.overrideWith(
            () => _UseHebrewTermsOverride(useHebrew: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Drive the aggregated provider — it expands to all 9 curricula and
      // each one calls lifetimeDataProvider which (post-fix) reads the
      // batched providers.
      await container.read(lifetimeSummariesProvider(_profileId).future);

      // Each batched provider must have been built EXACTLY ONCE across
      // all 9 curriculum resolutions. Before the fix, completions would
      // be queried once per (curriculum + subset) and imports once per
      // curriculum — both well above 1.
      expect(
        observer.batchedCompletionsBuilds,
        1,
        reason:
            'completionsByProfileForLifetimeProvider must be shared across '
            'the 9 lifetimeDataProvider consumers — N+1 fix',
      );
      expect(
        observer.batchedImportsBuilds,
        1,
        reason:
            'priorImportsByProfileProvider must be shared across the 9 '
            'lifetimeDataProvider consumers — N+1 fix',
      );
    });
  });

  // ─── Test 4 — CTA navigates to LifetimeMarkingRoute ───────────────────
  //
  // NOTE on layering (sweep-fix/lifetime-cta): this test drives navigation
  // through [_RecordingRouter], a fake `StackRouter` that records `push()`
  // calls WITHOUT running AutoRoute's real guard pipeline. It only proves
  // the CTA's `onTap` closure calls `router.push(LifetimeMarkingRoute())` —
  // it cannot and does not prove the push actually lands anywhere, because
  // the real `LifetimeMarkingRoute` carries [authGuard, childModeGuard,
  // pinGuard] (see app_router.dart) and childModeGuard fails CLOSED
  // (`resolver.next(false)`, no error/snackbar) whenever the active profile
  // is not in child mode. That is exactly the failure mode two independent
  // on-device sweeps reproduced (byte-identical screen before/after the
  // tap): this test was testing the wrong layer and passed throughout. The
  // real regression coverage is the CTA-visibility test below, which pumps
  // the actual screen (no fake router) against both profile modes and
  // asserts the guard's precondition is honoured *before* the tap — i.e.
  // the CTA is hidden rather than visible-but-dead. This test is kept
  // (now with an explicit child-mode profile, since that's what the guard
  // actually requires) to cover the wiring once the precondition holds.

  group('CTA navigates to LifetimeMarkingRoute', () {
    testWidgets('tapping the "Add items I learned previously" card pushes '
        'LifetimeMarkingRoute on the router', (tester) async {
      // Seed a minimal live entry so the screen renders past loading
      // (empty state would obscure the CTA card).
      await _seedLive(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      final pushed = <String>[];
      final router = _RecordingRouter(pushed);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
            // Real destination route requires childModeGuard — the active
            // profile must be in child mode or the (real, non-faked)
            // navigation silently no-ops. Reflect that precondition here.
            activeProfileProvider.overrideWith(
              (ref) async => _profileModel(mode: 'child'),
            ),
            useHebrewTermsProvider.overrideWith(
              () => _UseHebrewTermsOverride(useHebrew: false),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: const LifetimeKnowledgeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.text('Add items I learned previously');
      expect(ctaFinder, findsOneWidget);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(
        pushed,
        contains('LifetimeMarkingRoute'),
        reason:
            'tapping the CTA must push the existing LifetimeMarkingRoute '
            'on the router',
      );
    });
  });

  // ─── Test 5 — CTA hidden when active profile cannot pass childModeGuard ──
  //
  // BUG-lifetime-cta-dead-tap (sweep-fix/lifetime-cta): two independent
  // on-device sweeps found the CTA visible but permanently unresponsive —
  // uiautomator confirmed the tap landed, but the screen never changed.
  // Root cause: `LifetimeKnowledgeRoute` carries only [authGuard] (reachable
  // by ANY active profile — adult or child; see
  // docs/planning/progress-ia-redesign.md Q5, which explicitly keeps
  // Progress/Lifetime Knowledge available in adult mode), but the CTA's
  // destination `LifetimeMarkingRoute` carries [authGuard, childModeGuard,
  // pinGuard]. childModeGuard fails CLOSED with no user-visible feedback
  // when the active profile is not in child mode — exactly the state an
  // adult self-tracking profile (or a parent viewing their own progress) is
  // in by default. This is also the app-wide default test fixture: the
  // canonical `seedProfile()` helper (test/helpers/drift_memory.dart) seeds
  // profile 1 as `mode: 'adult'` — the same default the two sweeps almost
  // certainly hit.
  group('CTA hidden when active profile is not in child mode', () {
    Future<void> pumpWithMode(WidgetTester tester, String mode) async {
      await _seedLive(
        db,
        trackId: trackId,
        ref: leaves[0].sefariaRef,
        stageId: 1,
        at: DateTime.utc(2026, 5, 1, 10),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            contentRepositoryProvider.overrideWithValue(fakeRepo),
            activeProfileIdProvider.overrideWith(() => _ProfileIdOverride(1)),
            activeProfileProvider.overrideWith(
              (ref) async => _profileModel(mode: mode),
            ),
            useHebrewTermsProvider.overrideWith(
              () => _UseHebrewTermsOverride(useHebrew: false),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LifetimeKnowledgeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'adult-mode active profile: the CTA is not rendered (would be a dead '
      'button — its route requires childModeGuard)',
      (tester) async {
        await pumpWithMode(tester, 'adult');

        expect(
          find.text('Add items I learned previously'),
          findsNothing,
          reason:
              'BUG-lifetime-cta-dead-tap: an adult-mode active profile can '
              'never satisfy childModeGuard on LifetimeMarkingRoute, so the '
              'CTA must be hidden rather than shown-but-permanently-dead',
        );
      },
    );

    testWidgets(
      'child-mode active profile: the CTA renders (guard precondition met)',
      (tester) async {
        await pumpWithMode(tester, 'child');

        expect(
          find.text('Add items I learned previously'),
          findsOneWidget,
          reason:
              'a child-mode active profile satisfies childModeGuard, so the '
              'CTA must still be offered here',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers — collect terminal tree nodes for assertions.
// ---------------------------------------------------------------------------

List<LifetimeTreeNode> _collectTerminalNodes(List<LifetimeTreeNode> tree) {
  final out = <LifetimeTreeNode>[];
  void walk(LifetimeTreeNode n) {
    if (n.children.isEmpty) {
      out.add(n);
    } else {
      for (final c in n.children) {
        walk(c);
      }
    }
  }

  for (final n in tree) {
    walk(n);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Recording router — captures pushed route names so the CTA test can assert
// navigation occurred without mounting the real router stack.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// All-curriculum fake repo — F13 perf assertion needs every curriculum to
// return non-empty content so each `lifetimeDataProvider` instance actually
// runs the data path. The single-curriculum [_FakeContentRepository] returns
// `const []` for non-mishnayos curricula, which short-circuits the data path
// and bypasses the batched-provider reads we want to assert on.
// ---------------------------------------------------------------------------

class _AllCurriculumFakeRepo extends Fake implements ContentRepository {
  _AllCurriculumFakeRepo(this._leaves);

  final List<ContentItem> _leaves;

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    // Same leaves for every curriculum — the assertions don't depend on
    // per-curriculum content, only on provider call-count behaviour.
    return _leaves
        .map(
          (l) => ContentItemFixtures.leaf(
            curriculumId: curriculumId.storageKey,
            level1: l.level1,
            level2: l.level2,
            level3: l.level3,
            level4: l.level4,
            sefariaRef: l.sefariaRef,
            sortOrder: l.sortOrder,
            displayNameHe: l.displayNameHe,
            displayNameEn: l.displayNameEn,
            isLeaf: l.isLeaf,
          ),
        )
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Counting observer — F13 perf assertion. Counts `didAddProvider` events for
// the two new batched providers introduced by the N+1 fix.
// ---------------------------------------------------------------------------

final class _CountingObserver extends ProviderObserver {
  int batchedCompletionsBuilds = 0;
  int batchedImportsBuilds = 0;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    // Match by the family's debug `name` (set explicitly on the provider
    // declaration). Falls back to the provider's own toString in case the
    // provider is non-family (defensive — we declare both targets with
    // explicit names, so this is the expected hit path).
    final familyName = context.provider.from?.name;
    final providerName = context.provider.name;
    final id = familyName ?? providerName ?? context.provider.toString();
    if (id == 'completionsByProfileForLifetimeProvider' ||
        id.contains('completionsByProfileForLifetimeProvider')) {
      batchedCompletionsBuilds++;
    } else if (id == 'priorImportsByProfileProvider' ||
        id.contains('priorImportsByProfileProvider')) {
      batchedImportsBuilds++;
    }
  }
}
