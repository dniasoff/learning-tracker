import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/tri_state.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';

/// Pure presentation builder for the lifetime knowledge tree (DNI-474).
///
/// It lays the curriculum's ContentIndex hierarchy out as a
/// [LifetimeTreeNode] tree and marks each node with the engine's learnt
/// state: [learnedRefs] is the engine's learnt-leaf set (AD-32; from
/// `LearnerState`, every source and date state), and each node's
/// empty / partial / complete state and count follow the engine's
/// [triStateOf] rule over its leaves (FR-15). It derives no learnt state
/// of its own: no completions, no ledger, no unmark replay.
class LifetimeTreeBuilder {
  const LifetimeTreeBuilder();

  /// Builds a [CurriculumLifetimeSummary].
  ///
  /// [curriculum] — the curriculum being summarised.
  /// [leaves] — all leaf [ContentItem]s in the curriculum.
  /// [learnedRefs] — the engine's learnt leaves (unioned across subset
  ///   curricula by the caller for a composite curriculum).
  /// [heLabelLookup] — Hebrew name lookup map (from [buildHeLabelLookup]).
  /// [leafProvenance] — optional per-`sefariaRef` provenance (see
  ///   [provenanceFromActivity]); only refs present in [leaves] are used.
  CurriculumLifetimeSummary build({
    required CurriculumId curriculum,
    required List<ContentItem> leaves,
    required Set<String> learnedRefs,
    required Map<String, String> heLabelLookup,
    Map<String, LifetimeLeafProvenance> leafProvenance = const {},
  }) {
    final leafRefs = leaves.map((l) => l.sefariaRef).toSet();
    final learned = learnedRefs.where(leafRefs.contains).toSet();
    final tree = buildTree(
      curriculum,
      leaves,
      learned,
      heLabelLookup: heLabelLookup,
      leafProvenance: leafProvenance,
    );
    final percentage = leaves.isEmpty ? 0.0 : learned.length / leaves.length;
    return CurriculumLifetimeSummary(
      curriculumId: curriculum,
      learnedLeafCount: learned.length,
      totalLeafCount: leaves.length,
      percentage: percentage.clamp(0.0, 1.0),
      tree: tree,
      learnedLeafRefs: learned,
      allLeafRefs: leafRefs,
    );
  }

  /// Builds the hierarchy tree of [leaves] (grouped by their `levelN`
  /// values, in ContentIndex `sortOrder`), each node marked by the
  /// engine's tri-state rule over its leaves and carrying its learnt and
  /// total leaf counts.
  List<LifetimeTreeNode> buildTree(
    CurriculumId curriculumId,
    List<ContentItem> leaves,
    Set<String> learnedRefs, {
    Map<String, String> heLabelLookup = const {},
    Map<String, LifetimeLeafProvenance> leafProvenance = const {},
  }) {
    List<LifetimeTreeNode> buildAtLevel(List<ContentItem> bucket, int level) {
      String? levelValue(ContentItem item) {
        return switch (level) {
          1 => item.level1,
          2 => item.level2,
          3 => item.level3,
          4 => item.level4,
          _ => null,
        };
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
              return switch (level + 1) {
                2 => item.level2 != null,
                3 => item.level3 != null,
                4 => item.level4 != null,
                _ => false,
              };
            });
        final children = hasDeeper
            ? buildAtLevel(entry.value, level + 1)
            : const <LifetimeTreeNode>[];
        final refs = entry.value.map((l) => l.sefariaRef);
        final learnt = refs.where(learnedRefs.contains).length;
        final levelKey = _levelLookupKey(entry.value.first, level);
        final hebrewName =
            heLabelLookup[levelKey] ??
            (level == 4 ? _hebrewLabelForLeafGroup(entry.value) : null);

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
            state: lifetimeNodeStateOf(triStateOf(refs, learnedRefs)),
            children: children,
            provenance: provenance,
            leafRef: children.isEmpty && entry.value.length == 1
                ? entry.value.first.sefariaRef
                : null,
            learntCount: learnt,
            totalCount: entry.value.length,
          ),
        );
      }
      return nodes;
    }

    return buildAtLevel(leaves, 1);
  }

  /// Per-leaf provenance from the engine's counted learning: a leaf first
  /// learnt before tracking is [LifetimeLeafSource.bulkMarked] (a
  /// `before_tracking` backfill), any other is [LifetimeLeafSource.live];
  /// `chazarosCount` is the leaf's counted learn events (the label shows
  /// "· N chazaros" from two events on).
  static Map<String, LifetimeLeafProvenance> provenanceFromActivity(
    Map<String, LeafActivity> activity,
  ) => {
    for (final MapEntry(key: ref, value: a) in activity.entries)
      ref: LifetimeLeafProvenance(
        source: a.firstBeforeTracking && a.trackedEvents == 0
            ? LifetimeLeafSource.bulkMarked
            : LifetimeLeafSource.live,
        chazarosCount: a.events,
      ),
  };

  /// Builds a Hebrew-label lookup keyed by the `|`-joined level path
  /// (`level1|level2|...`) of each non-leaf [content] item.
  static Map<String, String> buildHeLabelLookup(List<ContentItem> content) {
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
  }

  static String? _hebrewLabelForLeafGroup(List<ContentItem> bucket) {
    if (bucket.isEmpty) return null;
    final he = bucket.first.displayNameHe;
    return he.isEmpty ? null : he;
  }

  static String _levelLookupKey(ContentItem item, int level) {
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
}

/// The [LifetimeNodeState] of an engine [TriState].
LifetimeNodeState lifetimeNodeStateOf(TriState state) => switch (state) {
  TriState.complete => LifetimeNodeState.full,
  TriState.partial => LifetimeNodeState.partial,
  TriState.empty => LifetimeNodeState.none,
};

/// The engine [TriState] of a [LifetimeNodeState].
TriState triStateOfNode(LifetimeNodeState state) => switch (state) {
  LifetimeNodeState.full => TriState.complete,
  LifetimeNodeState.partial => TriState.partial,
  LifetimeNodeState.none => TriState.empty,
};
