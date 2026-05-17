import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';

enum LifetimeNodeState { none, partial, full }

/// One node in the lifetime knowledge tree. Carries the structured metadata
/// the renderer needs to produce a level-aware local label ("פרק א", not
/// "משנה דמאי א") — the actual text is rendered by [CurriculumLabel.level]
/// at the UI layer so the Hebrew Terms toggle is respected.
class LifetimeTreeNode {
  const LifetimeTreeNode({
    required this.curriculumId,
    required this.level,
    required this.rawValue,
    required this.parentL1Value,
    required this.hebrewName,
    required this.state,
    required this.children,
  });

  final CurriculumId curriculumId;

  /// Hierarchy level (1..4) — Seder / Masechta / Perek / Mishna for Mishnayos.
  final int level;

  /// Raw value from `content_items.levelN` (e.g. "Chullin", "1" for Perek 1).
  /// Sortable; usable as a node key.
  final String rawValue;

  /// The level-1 value for this branch (needed for curricula whose level
  /// structure varies by top-level book, e.g. Mussar).
  final String parentL1Value;

  /// Optional Hebrew name from the matching intermediate `ContentItem` row.
  /// Null when no intermediate row was found; renderer falls back to raw.
  final String? hebrewName;

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

/// Per-curriculum lazy lifetime data provider.
///
/// Loads lifetime completion data for a single [CurriculumId]. Returns `null`
/// when the curriculum's content asset is missing or empty so callers can skip
/// it without error.
///
/// Keyed by `({int profileId, CurriculumId curriculumId})` so each curriculum
/// is fetched independently and cached/disposed independently.
final lifetimeDataProvider = FutureProvider.autoDispose
    .family<
      CurriculumLifetimeSummary?,
      ({int profileId, CurriculumId curriculumId})
    >((ref, args) async {
      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);
      final curriculum = args.curriculumId;
      final profileId = args.profileId;

      final leaves = await _safeLoadLeaves(repo, curriculum);
      if (leaves == null) return null;
      if (leaves.isEmpty) return null;

      final completions = await db.completionDao
          .getCompletionsByCurriculumAndProfile(
            curriculum.storageKey,
            profileId,
          );
      final ledger = await db.learningLedgerDao.getEntriesByCurriculum(
        profileId,
        curriculum.storageKey,
      );

      // I-4: Union in completions from subset curricula so that, e.g., a ref
      // completed via a Chumash track is also credited to Tanach.  Deduplication
      // is handled by Set semantics — a ref present in both the direct set and a
      // subset set is counted only once.
      final subsets = subsetsOf(curriculum);
      var completedRefs = completions.map((c) => c.sefariaRef).toSet();
      for (final subset in subsets) {
        final subsetCompletions = await db.completionDao
            .getCompletionsByCurriculumAndProfile(subset.storageKey, profileId);
        completedRefs = completedRefs.union(
          subsetCompletions.map((c) => c.sefariaRef).toSet(),
        );
      }

      final learnedLeafRefs = _learnedLeafRefs(
        leaves: leaves,
        completedRefs: completedRefs,
        ledgerEntries: ledger,
      );

      final heLookup = await _heLabelLookup(repo, curriculum);
      final tree = _buildTree(
        curriculum,
        leaves,
        learnedLeafRefs,
        heLabelLookup: heLookup,
      );
      final percentage = leaves.isEmpty
          ? 0.0
          : learnedLeafRefs.length / leaves.length;

      return CurriculumLifetimeSummary(
        curriculumId: curriculum,
        learnedLeafCount: learnedLeafRefs.length,
        totalLeafCount: leaves.length,
        percentage: percentage.clamp(0.0, 1.0),
        tree: tree,
      );
    });

/// Aggregated lifetime summaries across all active curricula.
///
/// Reads from [lifetimeDataProvider] per curriculum lazily — each curriculum
/// is fetched and cached independently, so a single-curriculum tap only loads
/// that curriculum's data.
///
/// This is the single aggregation surface replacing the old eager
/// [globalLifetimeCurriculaProvider] loop.
final lifetimeSummariesProvider = FutureProvider.autoDispose
    .family<List<CurriculumLifetimeSummary>, int>((ref, profileId) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) => ref.watch(
            lifetimeDataProvider((
              profileId: profileId,
              curriculumId: curriculum,
            )).future,
          ),
        ),
      );
      return results.whereType<CurriculumLifetimeSummary>().toList();
    });

/// Compatibility alias for [lifetimeSummariesProvider].
///
/// Retained so existing callers compile without change. Prefer
/// [lifetimeSummariesProvider] in new code.
///
/// When only a single curriculum is needed, prefer
/// [lifetimeDataProvider] to avoid loading all 9 curricula.
@Deprecated('Use lifetimeSummariesProvider or lifetimeDataProvider instead')
final globalLifetimeCurriculaProvider = lifetimeSummariesProvider;

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

        // Current-session completions: only those on or after activatedAt.
        // This ensures a restored track starts at 0% for the new cycle even
        // though pre-restore completions remain in the DB for lifetime stats.
        final sessionCompletions = await db.completionDao
            .getCompletionsByTrackAndProfileSince(
              track.id,
              profileId,
              track.activatedAt,
            );
        final currentCycleRefs = sessionCompletions
            .map((c) => c.sefariaRef)
            .toSet();
        final currentCyclePct = currentCycleRefs.length / denominator;

        // Lifetime completions: all completions for this track, including
        // those from previous learning sessions (before the last restore).
        final allTrackCompletions = await db.completionDao
            .getCompletionsByTrackAndProfile(track.id, profileId);
        final trackLedger = await db.learningLedgerDao.getEntriesByTrack(
          track.id,
          profileId,
        );
        final lifetimeRefs = _learnedLeafRefs(
          leaves: leaves,
          completedRefs: allTrackCompletions.map((c) => c.sefariaRef).toSet(),
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

        final localizedCurriculum = curriculumLabelTextFromRef(
          ref,
          curriculum: curriculum,
        );
        metrics.add(
          TrackDualProgressMetric(
            trackId: track.id,
            trackLabel: '$localizedCurriculum (${track.trackType})',
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
        lifetimeSummariesProvider(profileId).future,
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

List<LifetimeTreeNode> _buildTree(
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
      // Hebrew name source: at non-leaf levels look up the intermediate
      // hierarchy row's displayNameHe via [heLabelLookup]; only at leaf level
      // fall back to the item's own displayNameHe. Renderer ignores it for
      // ordinal levels (Perek, Mishnah, Daf, Pasuk) and strips the structural
      // prefix for named levels (Masechta, Seder).
      final levelKey = _levelLookupKey(entry.value.first, level);
      final hebrewName =
          heLabelLookup[levelKey] ??
          (level == 4 ? _hebrewLabelForLeafGroup(entry.value) : null);
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
