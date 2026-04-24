import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';

enum LifetimeNodeState { none, partial, full }

class LifetimeTreeNode {
  const LifetimeTreeNode({
    required this.label,
    required this.state,
    required this.children,
  });

  final String label;
  final LifetimeNodeState state;
  final List<LifetimeTreeNode> children;
}

class CurriculumLifetimeSummary {
  const CurriculumLifetimeSummary({
    required this.curriculumId,
    required this.learnedLeafCount,
    required this.totalLeafCount,
    required this.percentage,
    required this.tree,
  });

  final CurriculumId curriculumId;
  final int learnedLeafCount;
  final int totalLeafCount;
  final double percentage;
  final List<LifetimeTreeNode> tree;
}

class TrackDualProgressMetric {
  const TrackDualProgressMetric({
    required this.trackId,
    required this.trackLabel,
    required this.curriculumId,
    required this.currentCyclePercentage,
    required this.lifetimePercentage,
    required this.isProgramTrack,
  });

  final int trackId;
  final String trackLabel;
  final CurriculumId curriculumId;
  final double currentCyclePercentage;
  final double lifetimePercentage;
  final bool isProgramTrack;
}

final globalLifetimeCurriculaProvider = FutureProvider.autoDispose
    .family<List<CurriculumLifetimeSummary>, int>((ref, profileId) async {
      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);

      final summaries = <CurriculumLifetimeSummary>[];
      for (final curriculum in CurriculumId.values) {
        final leaves = await _safeLoadLeaves(repo, curriculum);
        if (leaves == null) continue;
        if (leaves.isEmpty) continue;

        final completions = await db.completionDao.getCompletionsByCurriculumAndProfile(
          curriculum.storageKey,
          profileId,
        );
        final ledger = await db.learningLedgerDao.getEntriesByCurriculum(
          profileId,
          curriculum.storageKey,
        );

        final learnedLeafRefs = _learnedLeafRefs(
          leaves: leaves,
          completedRefs: completions.map((c) => c.sefariaRef).toSet(),
          ledgerEntries: ledger,
        );
        if (learnedLeafRefs.isEmpty) continue;

        final tree = _buildTree(leaves, learnedLeafRefs);
        final percentage = leaves.isEmpty
            ? 0.0
            : learnedLeafRefs.length / leaves.length;
        summaries.add(
          CurriculumLifetimeSummary(
            curriculumId: curriculum,
            learnedLeafCount: learnedLeafRefs.length,
            totalLeafCount: leaves.length,
            percentage: percentage.clamp(0.0, 1.0),
            tree: tree,
          ),
        );
      }
      return summaries;
    });

final trackDualProgressMetricsProvider = FutureProvider.autoDispose
    .family<List<TrackDualProgressMetric>, int>((ref, profileId) async {
      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);
      final tracks = await db.trackDao.getAllForProfile(profileId);

      final metrics = <TrackDualProgressMetric>[];
      for (final track in tracks) {
        final curriculum = CurriculumId.values.firstWhere(
          (c) => c.storageKey == track.curriculumId,
          orElse: () => CurriculumId.mishnayos,
        );
        final leaves = await _safeLoadLeaves(repo, curriculum);
        if (leaves == null) continue;
        final denominator = leaves.length;
        if (denominator == 0) continue;

        final trackCompletions = await db.completionDao.getCompletionsByTrackAndProfile(
          track.id,
          profileId,
        );
        final currentCycleRefs = trackCompletions.map((c) => c.sefariaRef).toSet();
        final currentCyclePct = currentCycleRefs.length / denominator;

        final curriculumCompletions = await db.completionDao
            .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);
        final curriculumLedger = await db.learningLedgerDao.getEntriesByCurriculum(
          profileId,
          curriculum.storageKey,
        );
        final lifetimeRefs = _learnedLeafRefs(
          leaves: leaves,
          completedRefs: curriculumCompletions.map((c) => c.sefariaRef).toSet(),
          ledgerEntries: curriculumLedger,
        );
        final lifetimePct = lifetimeRefs.length / denominator;
        final enrollment = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);

        metrics.add(
          TrackDualProgressMetric(
            trackId: track.id,
            trackLabel: '${curriculum.displayNameHe} (${track.trackType})',
            curriculumId: curriculum,
            currentCyclePercentage: currentCyclePct.clamp(0.0, 1.0),
            lifetimePercentage: lifetimePct.clamp(0.0, 1.0),
            isProgramTrack: enrollment != null,
          ),
        );
      }

      return metrics;
    });

Future<List<ContentItem>?> _safeLoadLeaves(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    return content.where((item) => item.isLeaf).toList();
  } catch (_) {
    // Some curricula may not ship local hierarchy assets in this build.
    // Skip them so one missing asset doesn't break the entire view.
    return null;
  }
}

Set<String> _learnedLeafRefs({
  required List<ContentItem> leaves,
  required Set<String> completedRefs,
  required List<dynamic> ledgerEntries,
}) {
  final learnedRefs = <String>{...completedRefs};
  final level1 = <String>{};
  final level2 = <String>{};
  final level3 = <String>{};
  final level4 = <String>{};

  for (final entry in ledgerEntries) {
    final unitType = (entry.unitType ?? '').toString();
    final unitId = (entry.unitIdentifier ?? '').toString();
    if (unitId.isEmpty) continue;
    switch (unitType) {
      case 'seder':
      case 'sefer':
      case 'level1':
        level1.add(unitId);
        break;
      case 'masechta':
      case 'siman':
      case 'level2':
        level2.add(unitId);
        break;
      case 'perek':
      case 'daf':
      case 'halacha':
      case 'pasuk':
      case 'level3':
        level3.add(unitId);
        break;
      case 'mishna':
      case 'amud':
      case 'seif':
      case 'seif_katan':
      case 'level4':
        level4.add(unitId);
        break;
      default:
        learnedRefs.add(unitId);
        break;
    }
  }

  for (final leaf in leaves) {
    if (learnedRefs.contains(leaf.sefariaRef) ||
        learnedRefs.contains(leaf.level4) ||
        learnedRefs.contains(leaf.level3) ||
        learnedRefs.contains(leaf.level2) ||
        learnedRefs.contains(leaf.level1) ||
        (leaf.level4 != null && level4.contains(leaf.level4!)) ||
        (leaf.level3 != null && level3.contains(leaf.level3!)) ||
        (leaf.level2 != null && level2.contains(leaf.level2!)) ||
        level1.contains(leaf.level1)) {
      learnedRefs.add(leaf.sefariaRef);
    }
  }

  return learnedRefs.where((r) => leaves.any((l) => l.sefariaRef == r)).toSet();
}

List<LifetimeTreeNode> _buildTree(List<ContentItem> leaves, Set<String> learnedRefs) {
  LifetimeNodeState stateForLeaves(List<ContentItem> bucket) {
    if (bucket.isEmpty) return LifetimeNodeState.none;
    final learned = bucket.where((l) => learnedRefs.contains(l.sefariaRef)).length;
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

    final nodes = <LifetimeTreeNode>[];
    for (final entry in grouped.entries) {
      final hasDeeper = entry.value.any((item) => levelValue(item) != item.sefariaRef) &&
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
      final children = hasDeeper ? buildAtLevel(entry.value, level + 1) : const <LifetimeTreeNode>[];
      LifetimeNodeState nodeState;
      if (children.isEmpty) {
        nodeState = stateForLeaves(entry.value);
      } else {
        final allFull = children.every((c) => c.state == LifetimeNodeState.full);
        final anyDone = children.any(
          (c) => c.state == LifetimeNodeState.full || c.state == LifetimeNodeState.partial,
        );
        nodeState = allFull
            ? LifetimeNodeState.full
            : (anyDone ? LifetimeNodeState.partial : LifetimeNodeState.none);
      }
      nodes.add(
        LifetimeTreeNode(
          label: entry.key,
          state: nodeState,
          children: children,
        ),
      );
    }
    return nodes;
  }

  return buildAtLevel(leaves, 1);
}
