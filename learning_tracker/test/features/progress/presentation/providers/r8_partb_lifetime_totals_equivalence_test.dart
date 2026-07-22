/// R8 Part B — correctness proof for the memory-bounded
/// `lifetimeTotalsAcrossAllCurriculaProvider` rewrite.
///
/// The rewritten provider computes each curriculum's learned-ref set from
/// ONLY that curriculum's OWN completions + ledger (via
/// `LifetimeTreeBuilder.computeLearnedLeafRefs`), deliberately WITHOUT
/// `lifetimeDataProvider`'s subset-bridging (the "I-4" completions union and
/// the "P0" ledger-derived union that credit Tanach from Chumash/Nach marks).
///
/// This is sound for a GLOBAL union across all 9 curricula specifically:
/// bridging a subset's (Chumash/Nach) marks into its superset (Tanach) only
/// ever re-adds refs that the subset's OWN entry, in this SAME
/// `CurriculumId.values` loop, already contributes — Chumash and Nach have no
/// subsets of their own, so their bridged learned-set equals their own
/// learned-set. Tanach-exclusive direct marks are still captured by Tanach's
/// own (unbridged) entry.
///
/// Each test below computes the SAME scenario two ways and asserts they
/// agree:
///   - "new": `lifetimeTotalsAcrossAllCurriculaProvider` (this rewrite).
///   - "old": the untouched `lifetimeSummariesProvider` (still builds full
///     per-curriculum trees, including subset-bridging), unioned the same way
///     the provider used to before this rewrite.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

import '../../../../helpers/drift_memory.dart';

/// Minimal, controllable [ContentRepository] fixture — implements
/// [LifetimeUnionLeafSource] too, so `_boundedLeavesFor` takes the "real"
/// (non-fallback) branch, exactly as production does.
class _FakeUnionContentRepository
    implements ContentRepository, LifetimeUnionLeafSource {
  _FakeUnionContentRepository(this._leaves);

  final Map<CurriculumId, List<ContentItem>> _leaves;

  @override
  Future<List<ContentItem>> loadLeavesTransient(CurriculumId c) async =>
      _leaves[c] ?? const <ContentItem>[];

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId c) async =>
      _leaves[c] ?? const <ContentItem>[];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId c) =>
      throw UnimplementedError();

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) => throw UnimplementedError();

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) => throw UnimplementedError();

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) => throw UnimplementedError();

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) => throw UnimplementedError();
}

ContentItem _leaf(
  String curriculumId, {
  required String level1,
  String? level2,
  String? level3,
  String? level4,
  required String ref,
}) => ContentItem(
  curriculumId: curriculumId,
  level1: level1,
  level2: level2,
  level3: level3,
  level4: level4,
  displayNameHe: '',
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: 0,
  isLeaf: true,
);

/// Computes totals the OLD way: union `allLeafRefs`/`learnedLeafRefs` straight
/// off `lifetimeSummariesProvider` (unchanged by this rewrite — still builds
/// full per-curriculum trees with subset-bridging).
Future<LifetimeTotals> _oldWayTotals(
  ProviderContainer container,
  int profileId,
) async {
  final summaries = await container.read(
    lifetimeSummariesProvider(profileId).future,
  );
  final allDistinct = <String>{};
  final learnedDistinct = <String>{};
  for (final s in summaries) {
    allDistinct.addAll(s.allLeafRefs);
    learnedDistinct.addAll(s.learnedLeafRefs);
  }
  return LifetimeTotals(
    learnedSections: learnedDistinct.length,
    totalSections: allDistinct.length,
    totalCurricula: CurriculumId.values.length,
  );
}

void main() {
  late UserDatabase db;
  const profileId = 1;

  // Chumash ⊂ Tanach, Nach ⊂ Tanach — the ONLY overlap in the app
  // (curriculum_overlap_registry.dart). Tanach's own item list is built via
  // the REAL CompositeCurriculumStrategy.remap so its level1-4 fields exactly
  // mirror what getContentForCurriculum(tanach) would produce.
  final chumashLeaves = [
    _leaf(
      'chumash',
      level1: 'Bereishis',
      level2: '1',
      level3: '1',
      ref: 'Genesis 1:1',
    ),
    _leaf(
      'chumash',
      level1: 'Bereishis',
      level2: '1',
      level3: '2',
      ref: 'Genesis 1:2',
    ),
  ];
  final nachLeaves = [
    _leaf(
      'nach',
      level1: 'Yehoshua',
      level2: '1',
      level3: '1',
      ref: 'Joshua 1:1',
    ),
  ];
  final tanachStrategy = CompositeCurriculumStrategy.forKey('tanach')!;
  final tanachLeaves = [
    ...chumashLeaves.map(
      (i) => tanachStrategy.remap(item: i, source: 'chumash', offset: 0),
    ),
    ...nachLeaves.map(
      (i) => tanachStrategy.remap(item: i, source: 'nach', offset: 100),
    ),
  ];

  final repoMap = <CurriculumId, List<ContentItem>>{
    CurriculumId.chumash: chumashLeaves,
    CurriculumId.nach: nachLeaves,
    CurriculumId.tanach: tanachLeaves,
  };

  setUp(() async {
    final database = inMemoryDb();
    addTearDown(database.close);
    db = database;
    await seedProfile(db);
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        contentRepositoryProvider.overrideWithValue(
          _FakeUnionContentRepository(repoMap),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('baseline — no completions, no ledger: old == new', () async {
    final container = buildContainer();

    final oldTotals = await _oldWayTotals(container, profileId);
    final newTotals = await container.read(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
    );

    expect(newTotals.totalSections, oldTotals.totalSections);
    expect(newTotals.learnedSections, oldTotals.learnedSections);
    expect(newTotals.totalSections, 3, reason: '{G1:1, G1:2, J1:1}, deduped');
    expect(newTotals.learnedSections, 0);
  });

  test('A — Chumash-only live completion is captured in the global union '
      'WITHOUT subset-bridging (old == new)', () async {
    await db.completionEventDao.appendEvent(
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: 'chumash',
        sefariaRef: 'Genesis 1:1',
        stageId: 1,
        trackType: 'personal',
        eventTimestamp: DateTime.utc(2026, 3, 1),
      ),
    );

    final container = buildContainer();
    final oldTotals = await _oldWayTotals(container, profileId);
    final newTotals = await container.read(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
    );

    expect(newTotals.learnedSections, oldTotals.learnedSections);
    expect(
      newTotals.learnedSections,
      1,
      reason:
          'Genesis 1:1 counted once, via Chumash\'s own top-level entry — '
          'no bridging into Tanach was needed for the GLOBAL union',
    );
  });

  test('B — Tanach-DIRECT completion (absent from Chumash/Nach) is still '
      'captured by Tanach\'s own (unbridged) entry (old == new)', () async {
    await db.completionEventDao.appendEvent(
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: 'tanach',
        sefariaRef: 'Genesis 1:1',
        stageId: 1,
        trackType: 'personal',
        eventTimestamp: DateTime.utc(2026, 3, 1),
      ),
    );

    final container = buildContainer();
    final oldTotals = await _oldWayTotals(container, profileId);
    final newTotals = await container.read(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
    );

    expect(newTotals.learnedSections, oldTotals.learnedSections);
    expect(
      newTotals.learnedSections,
      1,
      reason:
          'a mark made directly via the Tanach UI (no Chumash/Nach-side '
          'completion at all) must still be counted — dropping '
          'subset-bridging must not lose Tanach-exclusive marks',
    );
  });

  test(
    'C — Chumash ledger sefer-scope mark expands to its leaves, credited via '
    'Chumash\'s own entry, WITHOUT needing Tanach\'s P0 bridging (old == new)',
    () async {
      await db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          profileId: profileId,
          curriculumId: 'chumash',
          entryScope: 'sefer',
          unitIdentifier: 'Bereishis',
          unitDisplayNameHe: '',
          unitDisplayNameEn: 'Bereishis',
          trackType: 'personal',
          completedAt: DateTime.utc(2026, 3, 1),
          completionNumber: 1,
          markedBy: profileId,
        ),
      );

      final container = buildContainer();
      final oldTotals = await _oldWayTotals(container, profileId);
      final newTotals = await container.read(
        lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
      );

      expect(newTotals.learnedSections, oldTotals.learnedSections);
      expect(
        newTotals.learnedSections,
        2,
        reason: 'the whole Bereishis sefer-mark expands to both its leaves',
      );
    },
  );

  test('D — a stray synthetic-container ("Torah") level1 ledger mark under '
      'Tanach is dropped by the P0 guard in BOTH the old and new paths — it '
      'must NOT blanket-credit Chumash/Nach\'s leaves (old == new)', () async {
    await db.learningLedgerDao.insertEntry(
      LearningLedgerCompanion.insert(
        profileId: profileId,
        curriculumId: 'tanach',
        entryScope: 'level1',
        unitIdentifier: 'Torah',
        unitDisplayNameHe: '',
        unitDisplayNameEn: 'Torah',
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 3, 1),
        completionNumber: 1,
        markedBy: profileId,
      ),
    );

    final container = buildContainer();
    final oldTotals = await _oldWayTotals(container, profileId);
    final newTotals = await container.read(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
    );

    expect(newTotals.learnedSections, oldTotals.learnedSections);
    expect(
      newTotals.learnedSections,
      0,
      reason:
          'the synthetic Torah container mark must be dropped, not '
          'expanded to every Chumash+Nach leaf',
    );
  });

  test('combined — mixed live + ledger + direct-Tanach marks across curricula '
      '(old == new)', () async {
    await db.completionEventDao.appendEvent(
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: 'nach',
        sefariaRef: 'Joshua 1:1',
        stageId: 1,
        trackType: 'personal',
        eventTimestamp: DateTime.utc(2026, 3, 1),
      ),
    );
    await db.learningLedgerDao.insertEntry(
      LearningLedgerCompanion.insert(
        profileId: profileId,
        curriculumId: 'chumash',
        entryScope: 'sefer',
        unitIdentifier: 'Bereishis',
        unitDisplayNameHe: '',
        unitDisplayNameEn: 'Bereishis',
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 3, 2),
        completionNumber: 1,
        markedBy: profileId,
      ),
    );

    final container = buildContainer();
    final oldTotals = await _oldWayTotals(container, profileId);
    final newTotals = await container.read(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
    );

    expect(newTotals.learnedSections, oldTotals.learnedSections);
    expect(newTotals.totalSections, oldTotals.totalSections);
    expect(
      newTotals.learnedSections,
      3,
      reason: '{Joshua 1:1, Genesis 1:1, Genesis 1:2} — every leaf touched',
    );
  });
}
