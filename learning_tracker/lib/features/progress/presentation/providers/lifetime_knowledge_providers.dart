import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/program_calendar_providers.dart';

enum LifetimeNodeState { none, partial, full }

class LifetimeTreeNode {
  const LifetimeTreeNode({
    required this.label,
    required this.labelHe,
    required this.state,
    required this.children,
  });

  /// Latin / English transliteration label (the storage key value used in
  /// content_items.level1..4 — e.g. "Chullin", "Perek 1").
  final String label;

  /// Hebrew display label, sourced from any ContentItem in the same group
  /// (all items at a given level share the same Hebrew name). Falls back
  /// to [label] when no Hebrew is available.
  final String labelHe;
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
    this.todayDueCount,
    this.overdueCount,
  });

  final int trackId;
  final String trackLabel;
  final CurriculumId curriculumId;
  final double currentCyclePercentage;

  /// Learned leaf units ÷ leaf units in this track’s [curriculum_scopes] slice
  /// (falls back to full curriculum when no scope is set).
  final double lifetimePercentage;
  final bool isProgramTrack;
  final int? todayDueCount;
  final int? overdueCount;
}

class LifetimeTotals {
  const LifetimeTotals({
    required this.learnedSections,
    required this.totalSections,
    required this.totalCurricula,
  });

  /// Leaf units marked lifetime-learned, summed across all curricula in scope.
  final int learnedSections;

  /// Total leaf units in scope (all loadable hierarchies for the profile).
  final int totalSections;

  /// Tracked [CurriculumId] count (nine); display copy, not the divisor for %.
  final int totalCurricula;

  /// Pooled completion: completed sections / total sections in app content.
  double get percentage =>
      totalSections > 0 ? learnedSections / totalSections : 0.0;
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

        final completions = await db.completionDao
            .getCompletionsByCurriculumAndProfile(
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

        final heLookup = await _heLabelLookup(repo, curriculum);
        final tree = _buildTree(
          leaves,
          learnedLeafRefs,
          heLabelLookup: heLookup,
        );
        final percentage = leaves.isEmpty
            ? 0.0
            : learnedLeafRefs.length / leaves.length;

        // Include curriculum even if no learned items yet (tree will show all as unlearned)
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
        // Denominator = leaf count **within this track's curriculum scope** (not the
        // whole curriculum), so "lifetime %" reflects completion of *this track's*
        // slice — otherwise full-curriculum denominators yield tiny fractions.
        final leaves = await _safeLoadLeavesForTrack(
          repo,
          db,
          profileId,
          curriculum,
          track.id,
        );
        if (leaves == null) continue;
        final denominator = leaves.length;
        if (denominator == 0) continue;

        final trackCompletions = await db.completionDao
            .getCompletionsByTrackAndProfile(track.id, profileId);
        final currentCycleRefs = trackCompletions
            .map((c) => c.sefariaRef)
            .toSet();
        final currentCyclePct = currentCycleRefs.length / denominator;

        final trackLedger = await db.learningLedgerDao.getEntriesByTrack(
          track.id,
          profileId,
        );
        final lifetimeRefs = _learnedLeafRefs(
          leaves: leaves,
          completedRefs: trackCompletions.map((c) => c.sefariaRef).toSet(),
          ledgerEntries: trackLedger,
        );
        final lifetimePct = lifetimeRefs.length / denominator;
        final enrollment = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(
              profileId,
              curriculum.storageKey,
            );
        int? todayDueCount;
        int? overdueCount;
        if (enrollment != null) {
          try {
            final calendarPos = await ref.read(
              programCalendarPositionProvider(track.id).future,
            );
            final delta = calendarPos.delta;
            overdueCount = delta < 0 ? (-delta - 1).clamp(0, 9999) : 0;
            todayDueCount = delta > 0 ? 0 : 1;
          } catch (_) {
            overdueCount = 0;
            todayDueCount = 0;
          }
        }

        metrics.add(
          TrackDualProgressMetric(
            trackId: track.id,
            trackLabel: '${curriculum.displayNameHe} (${track.trackType})',
            curriculumId: curriculum,
            currentCyclePercentage: currentCyclePct.clamp(0.0, 1.0),
            lifetimePercentage: lifetimePct.clamp(0.0, 1.0),
            isProgramTrack: enrollment != null,
            todayDueCount: todayDueCount,
            overdueCount: overdueCount,
          ),
        );
      }

      return metrics;
    });

final lifetimeTotalsAcrossAllCurriculaProvider = FutureProvider.autoDispose
    .family<LifetimeTotals, int>((ref, profileId) async {
      final summaries = await ref.watch(
        globalLifetimeCurriculaProvider(profileId).future,
      );
      var learnedTotal = 0;
      var sectionTotal = 0;
      for (final s in summaries) {
        learnedTotal += s.learnedLeafCount;
        sectionTotal += s.totalLeafCount;
      }
      return LifetimeTotals(
        learnedSections: learnedTotal,
        totalSections: sectionTotal,
        totalCurricula: CurriculumId.values.length,
      );
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

/// Build a map from `(level1, level2, level3, level4)` path → displayNameHe
/// of the matching intermediate (non-leaf) hierarchy row. Lets the lifetime
/// tree show level-appropriate Hebrew labels (e.g. 'משנה ברכות' at masechta
/// level instead of the first leaf's 'משנה ברכות א:א').
Future<Map<String, String>> _heLabelLookup(
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

/// Leaf items for [trackId]'s scope: same idea as [scopedCurriculumContentProvider],
/// but resolved per track (with legacy fallbacks when [trackId] on scope rows is 0).
Future<List<ContentItem>?> _safeLoadLeavesForTrack(
  ContentRepository repo,
  UserDatabase db,
  int profileId,
  CurriculumId curriculum,
  int trackId,
) async {
  var scopes = await db.curriculumScopeDao.getScopesByTrack(trackId);
  if (scopes.isEmpty) {
    final forProfile = await db.curriculumScopeDao.getScopes(
      profileId,
      curriculum,
    );
    scopes = forProfile.where((s) => s.trackId == trackId).toList();
  }
  if (scopes.isEmpty) {
    final forProfile = await db.curriculumScopeDao.getScopes(
      profileId,
      curriculum,
    );
    if (forProfile.isNotEmpty) {
      final allZero = forProfile.every((s) => s.trackId == 0);
      if (allZero) {
        final inCur = (await db.trackDao.getActiveTracksForProfile(
          profileId,
        )).where((t) => t.curriculumId == curriculum.storageKey).toList();
        if (inCur.length == 1 && inCur.single.id == trackId) {
          scopes = forProfile;
        }
      }
    }
  }

  try {
    if (scopes.isEmpty) {
      return _safeLoadLeaves(repo, curriculum);
    }
    final allItems = await repo.getScopedContent(
      curriculumId: curriculum,
      scopeLevel: scopes.first.scopeLevel,
      scopeValues: scopes.map((s) => s.scopeValue).toList(),
    );
    return allItems.where((item) => item.isLeaf).toList();
  } catch (_) {
    return null;
  }
}

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
    final unitType = entry.unitType;
    final unitId = entry.unitIdentifier;
    if (unitId.isEmpty) continue;
    final isUnmark = unitType.startsWith('unmark_');
    final resolvedType = isUnmark
        ? unitType.substring('unmark_'.length)
        : unitType;
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

List<LifetimeTreeNode> _buildTree(
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
    // Sort groups by the smallest sortOrder of any item within them. Without
    // this, levels keyed on numeric strings ('1', '10', '2', '11', ...)
    // sort lexicographically — chapter 10 ends up before chapter 2 and
    // 'yud' (י) shows ahead of 'aleph' (א).
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
      // Hebrew label: at non-leaf levels look up the intermediate hierarchy
      // row's displayNameHe via [heLabelLookup]; only at leaf level fall
      // back to the item's own displayNameHe (which carries the full
      // ref-form Hebrew). Without this, masechta-level groups were
      // showing '<book> <gematria>:<gematria>' from the first leaf's
      // displayNameHe.
      final levelKey = _levelLookupKey(entry.value.first, level);
      final heFromLookup = heLabelLookup[levelKey];
      final heLabel =
          heFromLookup ??
          (level == 4
              ? (_hebrewLabelForLeafGroup(entry.value) ?? entry.key)
              : entry.key);
      nodes.add(
        LifetimeTreeNode(
          label: entry.key,
          labelHe: heLabel,
          state: nodeState,
          children: children,
        ),
      );
    }
    return nodes;
  }

  return buildAtLevel(leaves, 1);
}

String? _hebrewLabelForLeafGroup(List<ContentItem> bucket) {
  if (bucket.isEmpty) return null;
  final he = bucket.first.displayNameHe;
  return he.isEmpty ? null : he;
}

/// Build the lookup key matching the intermediate hierarchy row at [level]
/// for [item] — same shape used by [_heLabelLookup].
String _levelLookupKey(ContentItem item, int level) {
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
