import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

/// The sentinel [DateTime] used by [BulkPriorCompletionService] to mark
/// items learned in the past ("before this app"). Matches
/// `DateTime.utc(2000, 1, 1)` — compared by millisecondsSinceEpoch so
/// timezone normalization does not cause false positives.
final kBulkPriorSentinelMs = DateTime.utc(2000, 1, 1).millisecondsSinceEpoch;

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

/// Compute track-only curriculum completion summary.
///
/// "Track completions" are rows in the `completions` table whose
/// `completedAt` is NOT the bulk-prior sentinel (`DateTime.utc(2000,1,1)`).
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

  // Load all completions for this curriculum + profile.
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);

  // Filter: exclude bulk-prior sentinel rows.
  final trackCompletions = allCompletions
      .where(
        (c) => c.completedAt.millisecondsSinceEpoch != kBulkPriorSentinelMs,
      )
      .toList();

  if (trackCompletions.isEmpty) return null;

  final completedRefs = trackCompletions.map((c) => c.sefariaRef).toSet();
  final leafRefs = leaves.map((l) => l.sefariaRef).toSet();
  final learnedCount = completedRefs.intersection(leafRefs).length;

  final heLookup = await _heLabelLookupForCurriculum(repo, curriculum);
  final tree = _buildCompletionTree(
    curriculum,
    leaves,
    completedRefs,
    heLabelLookup: heLookup,
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

  final heLookup = await _heLabelLookupForCurriculum(repo, curriculum);
  final tree = _buildCompletionTree(
    curriculum,
    leaves,
    learnedRefs,
    heLabelLookup: heLookup,
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

/// Per-curriculum summary for track completions only (excludes bulk-prior
/// sentinel rows and ledger-based lifetime marks).
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

  for (final entry in ledgerEntries) {
    final entryScope = entry.entryScope;
    final unitId = entry.unitIdentifier;
    if (unitId.isEmpty) continue;
    final isUnmark = entryScope.startsWith('unmark_');
    final resolvedType = isUnmark
        ? entryScope.substring('unmark_'.length)
        : entryScope;
    final action = !isUnmark;
    switch (resolvedType) {
      case 'seder':
      case 'sefer':
      case 'level1':
        level1Actions.putIfAbsent(unitId, () => action);
        break;
      case 'masechta':
      case 'siman':
      case 'level2':
        level2Actions.putIfAbsent(unitId, () => action);
        break;
      case 'perek':
      case 'daf':
      case 'halacha':
      case 'pasuk':
      case 'level3':
        level3Actions.putIfAbsent(unitId, () => action);
        break;
      case 'mishna':
      case 'amud':
      case 'seif':
      case 'seif_katan':
      case 'level4':
        level4Actions.putIfAbsent(unitId, () => action);
        break;
      default:
        if (resolvedType.startsWith('level')) {
          refActions.putIfAbsent(unitId, () => action);
        } else if (action) {
          learnedRefs.add(unitId);
        }
        break;
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

List<LifetimeTreeNode> _buildCompletionTree(
  CurriculumId curriculumId,
  List<ContentItem> leaves,
  Set<String> learnedRefs, {
  Map<String, String> heLabelLookup = const {},
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

      nodes.add(
        LifetimeTreeNode(
          curriculumId: curriculumId,
          level: level,
          rawValue: entry.key,
          parentL1Value: entry.value.first.level1,
          hebrewName: hebrewName,
          state: nodeState,
          children: children,
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
