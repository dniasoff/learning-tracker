import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
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
  final tree = _buildCompletionTree(
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
/// Delegates to [_learnedLeafRefs] which mirrors the logic in
/// [lifetimeDataProvider], giving the same result for consistency.
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
  final ledger = await db.learningLedgerDao.getEntriesByCurriculum(
    profileId,
    curriculum.storageKey,
  );

  final learnedRefs = _learnedLeafRefs(
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
  final tree = _buildCompletionTree(
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

/// Build a leaf-ref set from both direct completions and ledger entries.
/// Mirrors the logic in [lifetimeDataProvider] via [_learnedLeafRefs] in
/// `lifetime_knowledge_providers.dart`.
Set<String> _learnedLeafRefs({
  required List<ContentItem> leaves,
  required Set<String> completedRefs,
  required List<LearningLedgerData> ledgerEntries,
}) {
  final learnedRefs = <String>{...completedRefs};
  final refActions = <String, bool>{};
  final level1Actions = <String, bool>{};
  final level2Actions = <String, bool>{};
  final level3Actions = <String, bool>{};
  final level4Actions = <String, bool>{};

  // Registry mapping every recognised entry-scope string to the action map it
  // populates. Replaces the inline switch; adding a new scope is a 1-line edit.
  const entryScopeLevel = <String, int>{
    'seder': 1,
    'sefer': 1,
    'level1': 1,
    'masechta': 2,
    'siman': 2,
    'level2': 2,
    'perek': 3,
    'daf': 3,
    'halacha': 3,
    'pasuk': 3,
    'level3': 3,
    'mishna': 4,
    'amud': 4,
    'seif': 4,
    'seif_katan': 4,
    'level4': 4,
  };

  for (final entry in ledgerEntries) {
    final entryScope = entry.entryScope;
    final unitId = entry.unitIdentifier;
    if (unitId.isEmpty) continue;
    final isUnmark = entryScope.startsWith('unmark_');
    final resolvedType = isUnmark
        ? entryScope.substring('unmark_'.length)
        : entryScope;
    final action = !isUnmark;

    final levelActions = switch (entryScopeLevel[resolvedType]) {
      1 => level1Actions,
      2 => level2Actions,
      3 => level3Actions,
      4 => level4Actions,
      _ => null,
    };
    if (levelActions != null) {
      levelActions.putIfAbsent(unitId, () => action);
    } else if (resolvedType.startsWith('level')) {
      // Generic "levelN" scope not in the registry → treat as a leaf ref.
      refActions.putIfAbsent(unitId, () => action);
    } else if (action) {
      learnedRefs.add(unitId);
    }
  }

  for (final leaf in leaves) {
    final completedDirectly =
        learnedRefs.contains(leaf.sefariaRef) ||
        learnedRefs.contains(leaf.level4) ||
        learnedRefs.contains(leaf.level3) ||
        learnedRefs.contains(leaf.level2) ||
        learnedRefs.contains(leaf.level1);
    final refAction = refActions[leaf.sefariaRef];
    final level4Action = leaf.level4 != null
        ? level4Actions[leaf.level4!]
        : null;
    final level3Action = leaf.level3 != null
        ? level3Actions[leaf.level3!]
        : null;
    final level2Action = leaf.level2 != null
        ? level2Actions[leaf.level2!]
        : null;
    final level1Action = level1Actions[leaf.level1];
    final scopedAction =
        refAction ??
        level4Action ??
        level3Action ??
        level2Action ??
        level1Action;
    if (completedDirectly || (scopedAction ?? false)) {
      learnedRefs.add(leaf.sefariaRef);
    } else if (scopedAction == false) {
      learnedRefs.remove(leaf.sefariaRef);
    }
  }

  return learnedRefs.where((r) => leaves.any((l) => l.sefariaRef == r)).toSet();
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

List<LifetimeTreeNode> _buildCompletionTree(
  CurriculumId curriculumId,
  List<ContentItem> leaves,
  Set<String> learnedRefs, {
  Map<String, String> heLabelLookup = const {},
  Map<String, LifetimeLeafProvenance> leafProvenance = const {},
}) {
  LifetimeNodeState stateForLeaves(List<ContentItem> bucket) {
    if (bucket.isEmpty) return LifetimeNodeState.none;
    final learned = bucket
        .where((l) => learnedRefs.contains(l.sefariaRef))
        .length;
    if (learned == 0) return LifetimeNodeState.none;
    if (learned == bucket.length) return LifetimeNodeState.full;
    return LifetimeNodeState.partial;
  }

  List<LifetimeTreeNode> buildAtLevel(List<ContentItem> bucket, int level) {
    String? levelValue(ContentItem item) {
      switch (level) {
        case 1:
          return item.level1;
        case 2:
          return item.level2;
        case 3:
          return item.level3;
        case 4:
          return item.level4;
        default:
          return null;
      }
    }

    final grouped = <String, List<ContentItem>>{};
    for (final item in bucket) {
      final key = levelValue(item);
      if (key == null || key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final aMin = a.value
            .map((e) => e.sortOrder)
            .reduce((x, y) => x < y ? x : y);
        final bMin = b.value
            .map((e) => e.sortOrder)
            .reduce((x, y) => x < y ? x : y);
        return aMin.compareTo(bMin);
      });

    final nodes = <LifetimeTreeNode>[];
    for (final entry in sortedEntries) {
      final hasDeeper =
          entry.value.any((item) => levelValue(item) != item.sefariaRef) &&
          level < 4 &&
          entry.value.any((item) {
            switch (level + 1) {
              case 2:
                return item.level2 != null;
              case 3:
                return item.level3 != null;
              case 4:
                return item.level4 != null;
              default:
                return false;
            }
          });

      final children = hasDeeper
          ? buildAtLevel(entry.value, level + 1)
          : const <LifetimeTreeNode>[];

      LifetimeNodeState nodeState;
      if (children.isEmpty) {
        nodeState = stateForLeaves(entry.value);
      } else {
        final allFull = children.every(
          (c) => c.state == LifetimeNodeState.full,
        );
        final anyDone = children.any(
          (c) =>
              c.state == LifetimeNodeState.full ||
              c.state == LifetimeNodeState.partial,
        );
        nodeState = allFull
            ? LifetimeNodeState.full
            : (anyDone ? LifetimeNodeState.partial : LifetimeNodeState.none);
      }

      final levelKey = _levelKey(entry.value.first, level);
      final hebrewName =
          heLabelLookup[levelKey] ??
          (level == 4 ? _hebrewForLeafGroup(entry.value) : null);

      // Attach provenance to terminal nodes that group exactly one leaf.
      LifetimeLeafProvenance? provenance;
      if (children.isEmpty &&
          leafProvenance.isNotEmpty &&
          entry.value.length == 1) {
        provenance = leafProvenance[entry.value.first.sefariaRef];
      }

      nodes.add(
        LifetimeTreeNode(
          curriculumId: curriculumId,
          level: level,
          rawValue: entry.key,
          parentL1Value: entry.value.first.level1,
          hebrewName: hebrewName,
          state: nodeState,
          children: children,
          provenance: provenance,
        ),
      );
    }
    return nodes;
  }

  return buildAtLevel(leaves, 1);
}

String _levelKey(ContentItem item, int level) {
  final parts = <String>[];
  if (item.level1.isNotEmpty) parts.add(item.level1);
  if (level >= 2 && item.level2 != null && item.level2!.isNotEmpty) {
    parts.add(item.level2!);
  }
  if (level >= 3 && item.level3 != null && item.level3!.isNotEmpty) {
    parts.add(item.level3!);
  }
  if (level >= 4 && item.level4 != null && item.level4!.isNotEmpty) {
    parts.add(item.level4!);
  }
  return parts.join('|');
}

String? _hebrewForLeafGroup(List<ContentItem> bucket) {
  if (bucket.isEmpty) return null;
  final he = bucket.first.displayNameHe;
  return he.isEmpty ? null : he;
}
