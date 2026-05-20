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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/screens/lifetime_knowledge_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

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
  return ContentItem(
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

        // Expected: 4 distinct items learned; 6 chazaros total (4 live events
        // + 1 bulk + 1 lifetime).
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
          6,
          reason:
              'Every completion_event row counts; 4 live (2 refs × 2 stages) '
              '+ 1 bulk + 1 lifetime = 6',
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

  // ─── Test 4 — CTA navigates to LifetimeMarkingRoute ───────────────────

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
