import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';

/// Pure computation service for building the lifetime knowledge tree.
///
/// Converts raw completion events + learning ledger entries + curriculum
/// content hierarchy into a [CurriculumLifetimeSummary] with a
/// [LifetimeTreeNode] tree for UI rendering.
///
/// This service owns the B1 lifetime-tier subscriber role: it is the
/// single place that unifies live completions (from [completionDao]),
/// bulk-prior completions (from [learningLedger]), and lifetime-only marks
/// (also from [learningLedger]) into one coherent learned-refs set.
class LifetimeTreeBuilder {
  const LifetimeTreeBuilder();

  /// Builds a [CurriculumLifetimeSummary] from raw data.
  ///
  /// [curriculum] — the curriculum being summarised.
  /// [leaves] — all leaf [ContentItem]s in the curriculum.
  /// [completedRefs] — set of `sefariaRef` strings completed via live/bulk
  ///   completions (already unioned across subset curricula by the caller).
  /// [ledgerEntries] — bulk/lifetime ledger entries for this curriculum.
  /// [heLabelLookup] — Hebrew name lookup map (from [buildHeLabelLookup]).
  /// [leafProvenance] — optional per-`sefariaRef` provenance map. When
  ///   supplied, terminal tree nodes receive a [LifetimeLeafProvenance] for
  ///   the matching leaf so the Lifetime Knowledge screen can render a
  ///   "how was this learned" label. Keys are leaf `sefariaRef` strings; only
  ///   refs present in [leaves] are honoured.
  CurriculumLifetimeSummary build({
    required CurriculumId curriculum,
    required List<ContentItem> leaves,
    required Set<String> completedRefs,
    required List<LearningLedgerData> ledgerEntries,
    required Map<String, String> heLabelLookup,
    Map<String, LifetimeLeafProvenance> leafProvenance = const {},
  }) {
    final learnedLeafRefs = computeLearnedLeafRefs(
      leaves: leaves,
      completedRefs: completedRefs,
      ledgerEntries: ledgerEntries,
    );

    final tree = buildTree(
      curriculum,
      leaves,
      learnedLeafRefs,
      heLabelLookup: heLabelLookup,
      leafProvenance: leafProvenance,
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
      learnedLeafRefs: learnedLeafRefs,
      allLeafRefs: leaves.map((l) => l.sefariaRef).toSet(),
    );
  }

  // ---------------------------------------------------------------------------
  // computeLearnedLeafRefs — B1 lifetime-tier logic
  // ---------------------------------------------------------------------------

  /// Computes the set of leaf `sefariaRef` strings that are considered
  /// lifetime-learned, applying all three credit tiers:
  ///
  /// 1. **Live completions** — `completedRefs` (direct leaf marks).
  /// 2. **Bulk-prior completions** — ledger entries without 'unmark_' prefix
  ///    at the leaf (sefariaRef / level4) scope.
  /// 3. **Lifetime-only scope marks** — ledger entries that mark an entire
  ///    parent level (seder, masechta, perek), expanding to all contained
  ///    leaves.
  ///
  /// Unmark entries (prefixed 'unmark_') remove refs from the learned set.
  Set<String> computeLearnedLeafRefs({
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
        case 'masechta':
        case 'siman':
        case 'level2':
          level2Actions.putIfAbsent(unitId, () => action);
        case 'perek':
        case 'daf':
        case 'halacha':
        case 'pasuk':
        case 'level3':
          level3Actions.putIfAbsent(unitId, () => action);
        case 'mishna':
        case 'amud':
        case 'seif':
        case 'seif_katan':
        case 'level4':
          level4Actions.putIfAbsent(unitId, () => action);
        default:
          if (resolvedType.startsWith('level')) {
            refActions.putIfAbsent(unitId, () => action);
          } else if (action) {
            learnedRefs.add(unitId);
          }
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

    // Return only refs that appear in this curriculum's leaf set.
    final leafRefSet = leaves.map((l) => l.sefariaRef).toSet();
    return learnedRefs.where(leafRefSet.contains).toSet();
  }

  // ---------------------------------------------------------------------------
  // buildTree — tree construction
  // ---------------------------------------------------------------------------

  /// Builds the [LifetimeTreeNode] hierarchy from [leaves] and [learnedRefs].
  ///
  /// When [leafProvenance] is supplied, terminal nodes (those that group
  /// exactly one underlying [ContentItem] leaf) carry a
  /// [LifetimeLeafProvenance] looked up by `sefariaRef`. Nodes that aggregate
  /// multiple leaves do not get provenance — provenance is a per-leaf concept
  /// and would be ambiguous at the aggregate level.
  List<LifetimeTreeNode> buildTree(
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

      // Sort groups by the smallest sortOrder of any item within them.
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
        final levelKey = _levelLookupKey(entry.value.first, level);
        final hebrewName =
            heLabelLookup[levelKey] ??
            (level == 4 ? _hebrewLabelForLeafGroup(entry.value) : null);

        // Provenance is meaningful only on terminal nodes that group exactly
        // one underlying leaf (so the label is unambiguous). When the bucket
        // contains multiple ContentItems with the same level value but
        // different sefariaRefs, leave provenance null at this node — the
        // user can drill into a deeper level if hierarchy exposes one, or
        // the renderer can skip the label when null.
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

  // ---------------------------------------------------------------------------
  // computeLeafProvenance — per-ref provenance map
  // ---------------------------------------------------------------------------

  /// Builds a `sefariaRef → LifetimeLeafProvenance` map from raw source data.
  ///
  /// Provenance rules (mutually exclusive — first match wins):
  ///   1. **[LifetimeLeafSource.live]** — at least one completion event is
  ///      NOT present in [importedKeys] (i.e. is a true live completion). The
  ///      `chazarosCount` is the number of completion events for this ref.
  ///   2. **[LifetimeLeafSource.bulkMarked]** — every event for this ref is
  ///      in [importedKeys] AND at least one import row has
  ///      `source = 'bulkInTrack'`. `chazarosCount` is the event count.
  ///   3. **[LifetimeLeafSource.lifetimeImported]** — every event for this
  ///      ref is in [importedKeys] with `source = 'lifetimeOnly'`, OR there
  ///      are no events at all but a learning-ledger entry implies the leaf
  ///      was lifetime-marked. `chazarosCount` is the event count (0 for
  ///      ledger-only marks).
  ///
  /// Refs that are not in any of [completionEventRefs] / [bulkImportedRefs] /
  /// [lifetimeImportedRefs] / [ledgerLearnedRefs] are absent from the result
  /// (they were never learned).
  ///
  /// [completionEventRefs] — list of every completion event's sefariaRef
  ///   (one entry per event row; duplicates allowed — they count chazaros).
  /// [bulkImportedRefs] — set of sefariaRefs present in
  ///   `prior_completion_imports` with `source = 'bulkInTrack'`.
  /// [lifetimeImportedRefs] — set of sefariaRefs present in
  ///   `prior_completion_imports` with `source = 'lifetimeOnly'`.
  /// [ledgerLearnedRefs] — additional refs learned exclusively via the
  ///   learning-ledger (e.g. lifetime scope marks expanded to leaves). When
  ///   a ref appears here but not in completionEventRefs/bulkImportedRefs,
  ///   it is treated as a lifetimeImported leaf with `chazarosCount = 0`.
  static Map<String, LifetimeLeafProvenance> computeLeafProvenance({
    required List<String> completionEventRefs,
    required Set<String> bulkImportedRefs,
    required Set<String> lifetimeImportedRefs,
    Set<String> ledgerLearnedRefs = const {},
  }) {
    // Count events per ref.
    final eventCount = <String, int>{};
    for (final ref in completionEventRefs) {
      eventCount[ref] = (eventCount[ref] ?? 0) + 1;
    }

    final out = <String, LifetimeLeafProvenance>{};
    final allRefs = <String>{
      ...eventCount.keys,
      ...bulkImportedRefs,
      ...lifetimeImportedRefs,
      ...ledgerLearnedRefs,
    };

    for (final ref in allRefs) {
      final count = eventCount[ref] ?? 0;
      final isBulk = bulkImportedRefs.contains(ref);
      final isLifetime = lifetimeImportedRefs.contains(ref);

      // Rule 1: any event that is NOT an import row → live.
      // A live event is one whose natural key is absent from the imports
      // table. Equivalently: events exist AND the ref is NOT in both
      // bulk/lifetime imports for every event row. Since the imports table
      // is keyed by natural key and one ref can have multiple stage rows,
      // the caller passes the set of refs WITH any import row; if there are
      // more events than imports for this ref, at least one is live.
      //
      // Simpler model used here: a ref is "live" when there is at least one
      // event AND the ref is NOT present in either import set, OR when
      // there are more events than the number of import rows the caller
      // saw for it. The caller in [lifetime_knowledge_providers.dart]
      // distinguishes by querying the prior_completion_imports table.
      final hasImportRow = isBulk || isLifetime;
      if (count > 0 && !hasImportRow) {
        out[ref] = LifetimeLeafProvenance(
          source: LifetimeLeafSource.live,
          chazarosCount: count,
        );
        continue;
      }

      // Rule 2: bulkInTrack import wins over lifetimeOnly when both are
      // present for the same ref (defensive — should not happen in practice).
      if (isBulk) {
        out[ref] = LifetimeLeafProvenance(
          source: LifetimeLeafSource.bulkMarked,
          chazarosCount: count,
        );
        continue;
      }

      // Rule 3: lifetimeOnly import OR ledger-only mark.
      if (isLifetime || ledgerLearnedRefs.contains(ref)) {
        out[ref] = LifetimeLeafProvenance(
          source: LifetimeLeafSource.lifetimeImported,
          chazarosCount: count,
        );
        continue;
      }
    }

    return out;
  }

  // ---------------------------------------------------------------------------
  // buildHeLabelLookup — Hebrew name lookup
  // ---------------------------------------------------------------------------

  /// Builds a map from `(level1|level2|level3|level4)` path → displayNameHe
  /// of the matching intermediate (non-leaf) hierarchy row.
  ///
  /// Called once per curriculum before [build].
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

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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
