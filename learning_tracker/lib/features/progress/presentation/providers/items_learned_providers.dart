import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

/// Summary of per-curriculum completion data for the Items Learned /
/// Lifetime View screens.
class CurriculumCompletionSummary {
  const CurriculumCompletionSummary({
    required this.curriculumId,
    required this.learnedLeafCount,
    required this.totalLeafCount,
    required this.tree,
  });

  final CurriculumId curriculumId;
  final int learnedLeafCount;
  final int totalLeafCount;
  final List<LifetimeTreeNode> tree;

  double get percentage =>
      totalLeafCount > 0 ? learnedLeafCount / totalLeafCount : 0.0;
}

// ---------------------------------------------------------------------------
// Testable service functions — used by providers below and by tests directly.
// ---------------------------------------------------------------------------

/// Compute track-achievement curriculum completion summary.
///
/// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) via the
/// tier-filtered DAO, so lifetimeOnly imports are excluded per B1 policy.
/// Replaces the former kBulkPriorSentinelMs magic-constant filter (Layer 3).
///
/// Returns `null` when the curriculum has no content or no track completions.
Future<CurriculumCompletionSummary?> computeItemsLearnedSummary({
  required UserDatabase db,
  required ContentRepository repo,
  required CurriculumId curriculum,
  required int profileId,
}) async {
  // Load all leaves for this curriculum.
  List<ContentItem> leaves;
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    leaves = content.where((item) => item.isLeaf).toList();
  } catch (_) {
    return null;
  }
  if (leaves.isEmpty) return null;

  // Layer 3: use trackAchievement tier (excludes lifetimeOnly).
  final trackCompletions = await db.completionDao.getCompletionsByTier(
    profileId: profileId,
    tier: CompletionTierFilter.trackAchievement,
    curriculumId: curriculum,
  );

  if (trackCompletions.isEmpty) return null;

  final completedRefs = trackCompletions.map((c) => c.sefariaRef).toSet();
  final leafRefs = leaves.map((l) => l.sefariaRef).toSet();
  final learnedCount = completedRefs.intersection(leafRefs).length;

  // Per-leaf provenance for the "Track learning only" view. lifetimeOnly is
  // excluded by the trackAchievement filter so only live and bulkMarked
  // entries appear here.
  final leafProvenance = await _trackProvenanceForCurriculum(
    db,
    curriculum,
    profileId,
    trackCompletions,
  );

  final heLookup = await _heLabelLookupForCurriculum(repo, curriculum);
  const builder = LifetimeTreeBuilder();
  final tree = builder.buildTree(
    curriculum,
    leaves,
    completedRefs,
    heLabelLookup: heLookup,
    leafProvenance: leafProvenance,
  );

  return CurriculumCompletionSummary(
    curriculumId: curriculum,
    learnedLeafCount: learnedCount,
    totalLeafCount: leaves.length,
    tree: tree,
  );
}

/// Compute lifetime curriculum completion summary (all sources: track
/// completions + sentinel rows + ledger-based bulk marks).
///
/// Delegates to [LifetimeTreeBuilder.computeLearnedLeafRefs] — the SAME
/// algorithm [lifetimeDataProvider] uses — rather than a private
/// reimplementation, so the P0 composite-over-credit guard below (and any
/// future fix to the shared algorithm) applies to both surfaces from one
/// implementation.
///
/// Returns `null` when the curriculum has no content or nothing learned.
Future<CurriculumCompletionSummary?> computeLifetimeViewSummary({
  required UserDatabase db,
  required ContentRepository repo,
  required CurriculumId curriculum,
  required int profileId,
}) async {
  List<ContentItem> leaves;
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    leaves = content.where((item) => item.isLeaf).toList();
  } catch (_) {
    return null;
  }
  if (leaves.isEmpty) return null;

  final completions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);

  // P0 (composite over-credit) READ-TIME guard — mirrors
  // lifetimeDataProvider's guard in lifetime_knowledge_providers.dart. A
  // COMPOSITE curriculum (Tanach) re-parents its source leaves under a
  // SYNTHETIC level1 container (e.g. 'Torah') that exists in no real
  // curriculum. A stray `tanach/level1/'Torah'` ledger row blanket-credits
  // the ENTIRE Torah from a single-book mark — and the v32 migration that
  // deletes it only runs once per account DB, so it cannot be relied on (a
  // row that survived an earlier-upgraded DB persists). Defensively DROP any
  // synthetic-container level1 (and its unmark_) row here so the shared
  // learned-refs computation never credits it.
  final rawLedger = await db.learningLedgerDao.getEntriesByCurriculum(
    profileId,
    curriculum.storageKey,
  );
  final ledger = rawLedger.where((e) {
    final scope = e.entryScope.startsWith('unmark_')
        ? e.entryScope.substring('unmark_'.length)
        : e.entryScope;
    if (scope != 'level1') return true;
    return !CompositeCurriculumStrategy.isSyntheticContainerLevel1(
      curriculum.storageKey,
      e.unitIdentifier,
    );
  }).toList();

  const builder = LifetimeTreeBuilder();
  final learnedRefs = builder.computeLearnedLeafRefs(
    leaves: leaves,
    completedRefs: completions.map((c) => c.sefariaRef).toSet(),
    ledgerEntries: ledger,
  );

  if (learnedRefs.isEmpty) return null;

  // Per-leaf provenance for the "All sources" view — includes lifetimeOnly
  // imports and ledger-derived lifetime marks.
  final leafProvenance = await _allSourcesProvenanceForCurriculum(
    db,
    curriculum,
    profileId,
    completions,
    ledger,
    learnedRefs,
  );

  final heLookup = await _heLabelLookupForCurriculum(repo, curriculum);
  final tree = builder.buildTree(
    curriculum,
    leaves,
    learnedRefs,
    heLabelLookup: heLookup,
    leafProvenance: leafProvenance,
  );

  return CurriculumCompletionSummary(
    curriculumId: curriculum,
    learnedLeafCount: learnedRefs.length,
    totalLeafCount: leaves.length,
    tree: tree,
  );
}

// ---------------------------------------------------------------------------
// Riverpod providers — thin wrappers around the service functions above.
// ---------------------------------------------------------------------------

/// Per-curriculum summary for track-achievement completions only
/// (live + bulkInTrack; excludes lifetimeOnly and ledger-based lifetime marks).
///
/// Keyed by `({int profileId, CurriculumId curriculumId})`.
final itemsLearnedDataProvider = FutureProvider.autoDispose
    .family<
      CurriculumCompletionSummary?,
      ({int profileId, CurriculumId curriculumId})
    >((ref, args) async {
      // ILP-01: recompute whenever a completion is committed so the Items
      // Learned and Lifetime View screens stay live without pull-to-refresh.
      ref.watch<int>(completionCommittedProvider);
      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);
      return computeItemsLearnedSummary(
        db: db,
        repo: repo,
        curriculum: args.curriculumId,
        profileId: args.profileId,
      );
    });

/// Aggregated track-only summaries across all curricula for [profileId].
final itemsLearnedSummariesProvider = FutureProvider.autoDispose
    .family<List<CurriculumCompletionSummary>, int>((ref, profileId) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) => ref.watch(
            itemsLearnedDataProvider((
              profileId: profileId,
              curriculumId: curriculum,
            )).future,
          ),
        ),
      );
      return results.whereType<CurriculumCompletionSummary>().toList();
    });

/// Per-curriculum summary for ALL completions — track completions plus
/// bulk-prior sentinel completions and ledger-based lifetime marks.
///
/// Delegates to [computeLifetimeViewSummary].
/// Keyed by `({int profileId, CurriculumId curriculumId})`.
final lifetimeViewDataProvider = FutureProvider.autoDispose
    .family<
      CurriculumCompletionSummary?,
      ({int profileId, CurriculumId curriculumId})
    >((ref, args) async {
      // ILP-01: recompute whenever a completion is committed so the Lifetime
      // View screen stays live without pull-to-refresh.
      ref.watch<int>(completionCommittedProvider);
      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);
      return computeLifetimeViewSummary(
        db: db,
        repo: repo,
        curriculum: args.curriculumId,
        profileId: args.profileId,
      );
    });

/// Aggregated lifetime summaries across all curricula for [profileId].
final lifetimeViewSummariesProvider = FutureProvider.autoDispose
    .family<List<CurriculumCompletionSummary>, int>((ref, profileId) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) => ref.watch(
            lifetimeViewDataProvider((
              profileId: profileId,
              curriculumId: curriculum,
            )).future,
          ),
        ),
      );
      return results.whereType<CurriculumCompletionSummary>().toList();
    });

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

Future<Map<String, String>> _heLabelLookupForCurriculum(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    final out = <String, String>{};
    for (final it in content) {
      if (it.isLeaf) continue;
      final key = [
        it.level1,
        it.level2,
        it.level3,
        it.level4,
      ].where((s) => s != null && s.isNotEmpty).join('|');
      if (key.isEmpty) continue;
      if (it.displayNameHe.isEmpty) continue;
      out[key] = it.displayNameHe;
    }
    return out;
  } catch (_) {
    return const {};
  }
}

/// Computes per-leaf provenance for the "Track learning only" tier.
///
/// Loads `prior_completion_imports` rows for the curriculum (filtered to
/// `source = 'bulkInTrack'`; lifetimeOnly rows are deliberately ignored
/// because they're already excluded from the trackAchievement filter). Maps
/// each [trackCompletions] row to `LifetimeLeafSource.live` unless an import
/// row with the same `sefariaRef` exists — then it's `bulkMarked`.
Future<Map<String, LifetimeLeafProvenance>> _trackProvenanceForCurriculum(
  UserDatabase db,
  CurriculumId curriculum,
  int profileId,
  List<Completion> trackCompletions,
) async {
  final imports =
      await (db.select(db.priorCompletionImports)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals(curriculum.storageKey),
          ))
          .get();
  final bulkRefs = <String>{};
  for (final row in imports) {
    if (row.source == 'bulkInTrack') {
      bulkRefs.add(row.sefariaRef);
    }
  }

  // Count events per ref so live entries can show "Live · N chazaros".
  final eventCount = <String, int>{};
  for (final c in trackCompletions) {
    eventCount[c.sefariaRef] = (eventCount[c.sefariaRef] ?? 0) + 1;
  }

  final out = <String, LifetimeLeafProvenance>{};
  for (final entry in eventCount.entries) {
    final ref = entry.key;
    final count = entry.value;
    if (bulkRefs.contains(ref)) {
      // Pure bulkInTrack — no live event upgraded it (upgrade removes the
      // import row, so its presence here means the row is still imported).
      out[ref] = LifetimeLeafProvenance(
        source: LifetimeLeafSource.bulkMarked,
        chazarosCount: count,
      );
    } else {
      out[ref] = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: count,
      );
    }
  }
  return out;
}

/// Computes per-leaf provenance for the "All sources" tier.
///
/// Mirrors [LifetimeTreeBuilder.computeLeafProvenance] semantics: queries
/// the imports table and reconciles event vs import counts so a live upgrade
/// (event exists but import row was deleted) classifies as `live`. Ledger-
/// only marks fall back to `lifetimeImported` with `chazarosCount = 0`.
Future<Map<String, LifetimeLeafProvenance>> _allSourcesProvenanceForCurriculum(
  UserDatabase db,
  CurriculumId curriculum,
  int profileId,
  List<Completion> completions,
  List<LearningLedgerData> ledger,
  Set<String> learnedRefs,
) async {
  final imports =
      await (db.select(db.priorCompletionImports)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals(curriculum.storageKey),
          ))
          .get();
  final bulkRefs = <String>{};
  final lifetimeRefs = <String>{};
  for (final row in imports) {
    switch (row.source) {
      case 'bulkInTrack':
        bulkRefs.add(row.sefariaRef);
      case 'lifetimeOnly':
        lifetimeRefs.add(row.sefariaRef);
    }
  }

  // Ledger-only refs: any ref in [learnedRefs] not covered by completions
  // or import rows. Treat them as lifetimeImported (chazarosCount = 0).
  final eventRefs = completions.map((c) => c.sefariaRef).toSet();
  final ledgerOnly = learnedRefs.difference(
    eventRefs.union(bulkRefs).union(lifetimeRefs),
  );

  return LifetimeTreeBuilder.computeLeafProvenance(
    completionEventRefs: completions.map((c) => c.sefariaRef).toList(),
    bulkImportedRefs: bulkRefs,
    lifetimeImportedRefs: lifetimeRefs,
    ledgerLearnedRefs: ledgerOnly,
  );
}
