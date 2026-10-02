/// Records "learnt before I started tracking" (Story 1.11, DNI-473; AD-31,
/// R10): the onboarding / Add-track bulk mark writes `before_tracking`
/// learning events through `LearningCommands.capture` instead of the
/// retired `2000-01-01` sentinel completions.
///
/// A whole node the learner ticked is ONE node event carrying its
/// ContentIndex `level` (the engine expands it with `expandGround`); a
/// single leaf is a leaf event. Neither carries a `learned_on`, earns
/// points or counts for the streak (AD-40, AD-50). Un-ticking an earlier
/// mark is `LearningCommands.unlearn` (AD-31).
library;

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';

export 'package:learning_tracker/core/content/hierarchy_selection.dart';

/// The ContentIndex node depth of [item]: its deepest non-null level.
int contentDepthOf(ContentItem item) => item.level4 != null
    ? 4
    : item.level3 != null
    ? 3
    : item.level2 != null
    ? 2
    : 1;

/// The [NodeEntry] of a container [item] of [curriculumId], with the level
/// name the engine's corpus uses (`contentIndexCorpus`).
NodeEntry nodeEntryOf(CurriculumId curriculumId, ContentItem item) => NodeEntry(
  level: contentLevelName(
    CurriculumLabels.labelsEn(curriculumId),
    contentDepthOf(item),
  ),
  ref: item.sefariaRef,
);

/// The unscoped [Corpus] of [curriculumId] built from its ContentIndex
/// [items] (the same adapter `corporaProvider` uses).
Corpus corpusOf(CurriculumId curriculumId, List<ContentItem> items) =>
    contentIndexCorpus(
      curriculumId: curriculumId.storageKey,
      items: items,
      levelLabels: CurriculumLabels.labelsEn(curriculumId),
    );

/// One `before_tracking` capture: whole-node events, leaf events, and every
/// leaf they cover in corpus order.
final class BeforeTrackingBatch {
  /// Creates the batch.
  const BeforeTrackingBatch({
    required this.nodes,
    required this.refs,
    required this.leaves,
  });

  /// Whole nodes, each one event with its `level`.
  final List<NodeEntry> nodes;

  /// Single leaves, each one event.
  final List<String> refs;

  /// Every leaf the batch covers, in corpus order.
  final List<ContentItem> leaves;

  /// Whether the batch writes nothing.
  bool get isEmpty => nodes.isEmpty && refs.isEmpty;
}

List<String?> _pathOf(ContentItem item) => [
  item.level1,
  item.level2,
  item.level3,
  item.level4,
].sublist(0, contentDepthOf(item));

List<String?> _pathOfSelection(HierarchySelection s) {
  final all = [s.level1, s.level2, s.level3, s.level4];
  var depth = 0;
  for (var i = 0; i < all.length; i++) {
    if (all[i] != null) depth = i + 1;
  }
  return all.sublist(0, depth);
}

bool _covers(HierarchySelection s, ContentItem leaf) {
  if (s.level1 != null && s.level1 != leaf.level1) return false;
  if (s.level2 != null && s.level2 != leaf.level2) return false;
  if (s.level3 != null && s.level3 != leaf.level3) return false;
  if (s.level4 != null && s.level4 != leaf.level4) return false;
  return true;
}

bool _samePath(List<String?> a, List<String?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The leaves under [selections] among [items], in corpus (`sortOrder`)
/// order, each once.
List<ContentItem> selectionLeaves(
  List<ContentItem> items,
  Iterable<HierarchySelection> selections,
) {
  return [
    for (final leaf in _orderedLeaves(items))
      if (selections.any((s) => _covers(s, leaf))) leaf,
  ];
}

List<ContentItem> _orderedLeaves(List<ContentItem> items) =>
    items.where((i) => i.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

/// Plans the `before_tracking` capture of Lifetime Marking [scopes]: each
/// `(level, qualified unit id)` naming a container item is one node event,
/// otherwise its leaves are leaf events; a leaf under a marked node is not
/// repeated.
BeforeTrackingBatch planScopeMarks({
  required CurriculumId curriculumId,
  required List<ContentItem> items,
  required Iterable<({int level, String unitId})> scopes,
}) {
  final nodes = <NodeEntry>[];
  final nodeLeaves = <ContentItem>[];
  final leafRefs = <ContentItem>[];
  final leaves = _orderedLeaves(items);
  for (final scope in {...scopes}) {
    bool under(ContentItem i) =>
        scopeUnitIdentifierForItem(i, scope.level) == scope.unitId;
    final container = items
        .where((i) => !i.isLeaf && contentDepthOf(i) == scope.level && under(i))
        .firstOrNull;
    final covered = leaves.where(under).toList();
    if (container != null) {
      nodes.add(nodeEntryOf(curriculumId, container));
      nodeLeaves.addAll(covered);
    } else {
      leafRefs.addAll(covered);
    }
  }
  final nodeRefs = {for (final l in nodeLeaves) l.sefariaRef};
  final leafRefSet = {for (final l in leafRefs) l.sefariaRef};
  return BeforeTrackingBatch(
    nodes: nodes,
    refs: [
      for (final l in leaves)
        if (leafRefSet.contains(l.sefariaRef) &&
            !nodeRefs.contains(l.sefariaRef))
          l.sefariaRef,
    ],
    leaves: [
      for (final l in leaves)
        if (nodeRefs.contains(l.sefariaRef) ||
            leafRefSet.contains(l.sefariaRef))
          l,
    ],
  );
}

/// Plans the `before_tracking` capture of [selections] in [curriculumId].
///
/// A selection naming a container [ContentItem] is one node event; one
/// naming a leaf, or a container with no item of its own, is its leaves. A
/// leaf already covered by a selected node is not repeated.
BeforeTrackingBatch planBeforeTracking({
  required CurriculumId curriculumId,
  required List<ContentItem> items,
  required Iterable<HierarchySelection> selections,
}) {
  final nodes = <NodeEntry>[];
  final nodeSelections = <HierarchySelection>[];
  final leafSelections = <HierarchySelection>[];
  for (final s in {...selections}) {
    final path = _pathOfSelection(s);
    final container = items
        .where((i) => !i.isLeaf && _samePath(_pathOf(i), path))
        .firstOrNull;
    if (container == null) {
      leafSelections.add(s);
    } else {
      nodes.add(nodeEntryOf(curriculumId, container));
      nodeSelections.add(s);
    }
  }
  final covered = selectionLeaves(items, nodeSelections);
  final coveredRefs = {for (final l in covered) l.sefariaRef};
  final refs = [
    for (final leaf in selectionLeaves(items, leafSelections))
      if (!coveredRefs.contains(leaf.sefariaRef)) leaf.sefariaRef,
  ];
  return BeforeTrackingBatch(
    nodes: nodes,
    refs: refs,
    leaves: selectionLeaves(items, selections),
  );
}

/// The outcome of [BeforeTrackingRecorder.record].
final class BeforeTrackingResult {
  /// Creates the result.
  const BeforeTrackingResult({
    required this.capture,
    required this.itemCount,
    this.bookmarkSefariaRef,
  });

  /// What the capture did.
  final CaptureResult capture;

  /// The leaves the batch covers.
  final int itemCount;

  /// Where the reading-order bookmark was set, if it was.
  final String? bookmarkSefariaRef;

  /// The learning events written.
  int get eventCount => switch (capture) {
    CaptureSuccess(:final eventIds) => eventIds.length,
    _ => 0,
  };
}

/// No learner is active (or the account is not ready): nothing can be
/// recorded.
final class BeforeTrackingUnavailableException implements Exception {
  /// Creates the exception.
  const BeforeTrackingUnavailableException();

  @override
  String toString() => 'BeforeTrackingUnavailableException';
}

/// Records and un-records "learnt before tracking" for the active learner.
class BeforeTrackingRecorder {
  /// Creates the recorder. [commands] and [events] resolve the active
  /// learner's commands and complete event log (null when none is active).
  BeforeTrackingRecorder({
    required ContentRepository contentRepository,
    required BookmarkRepository bookmarkRepository,
    required Future<LearningCommands?> Function() commands,
    required Future<List<LearningEvent>?> Function() events,
  }) : _content = contentRepository,
       _bookmarks = bookmarkRepository,
       _commands = commands,
       _events = events;

  final ContentRepository _content;
  final BookmarkRepository _bookmarks;
  final Future<LearningCommands?> Function() _commands;
  final Future<List<LearningEvent>?> Function() _events;

  Future<LearningCommands> _requireCommands() async {
    final commands = await _commands();
    if (commands == null) throw const BeforeTrackingUnavailableException();
    return commands;
  }

  /// The leaves [selections] cover in [curriculumId], in corpus order.
  Future<List<ContentItem>> resolveSelections({
    required CurriculumId curriculumId,
    required List<HierarchySelection> selections,
  }) async => selectionLeaves(
    await _content.getContentForCurriculum(curriculumId),
    selections,
  );

  /// Records [selections] as one `before_tracking` capture. On success the
  /// legacy reading-order bookmark moves to the first leaf not yet learnt
  /// (R4 co-write, retired by DNI-478).
  Future<BeforeTrackingResult> record({
    required CurriculumId curriculumId,
    required List<HierarchySelection> selections,
  }) async {
    final items = await _content.getContentForCurriculum(curriculumId);
    return _capture(
      curriculumId,
      items,
      planBeforeTracking(
        curriculumId: curriculumId,
        items: items,
        selections: selections,
      ),
      moveBookmark: true,
    );
  }

  /// Records the Lifetime Marking [scopes] — `(level, qualified unit id)`
  /// pairs (`scopeUnitIdentifier`) — as one `before_tracking` capture
  /// (lifetime knowledge, so the reading-order bookmark is not moved).
  Future<BeforeTrackingResult> recordScopes({
    required CurriculumId curriculumId,
    required List<({int level, String unitId})> scopes,
  }) async {
    final items = await _content.getContentForCurriculum(curriculumId);
    return _capture(
      curriculumId,
      items,
      planScopeMarks(curriculumId: curriculumId, items: items, scopes: scopes),
      moveBookmark: false,
    );
  }

  Future<BeforeTrackingResult> _capture(
    CurriculumId curriculumId,
    List<ContentItem> items,
    BeforeTrackingBatch batch, {
    required bool moveBookmark,
  }) async {
    if (batch.isEmpty) {
      return const BeforeTrackingResult(
        capture: CaptureResult.success(),
        itemCount: 0,
      );
    }
    final commands = await _requireCommands();
    final capture = await commands.capture(
      curriculumId: curriculumId.storageKey,
      refs: batch.refs,
      nodes: batch.nodes,
      source: LearningEvent.sourceMain,
      dateState: DateState.beforeTracking,
    );
    String? bookmark;
    if (moveBookmark && capture is CaptureSuccess) {
      final learnt = {
        ...await _learntRefs(curriculumId, items),
        for (final leaf in batch.leaves) leaf.sefariaRef,
      };
      bookmark = _orderedLeaves(
        items,
      ).map((l) => l.sefariaRef).where((r) => !learnt.contains(r)).firstOrNull;
      if (bookmark != null) {
        await _bookmarks.setBookmark(
          curriculumId: curriculumId,
          sefariaRef: bookmark,
        );
      }
    }
    return BeforeTrackingResult(
      capture: capture,
      itemCount: batch.leaves.length,
      bookmarkSefariaRef: bookmark,
    );
  }

  /// Un-learns [sefariaRefs] (AD-31 `unlearn`: a node event covering part
  /// of them is replaced by Before-tracking events for the rest).
  Future<CaptureResult> unrecord({
    required CurriculumId curriculumId,
    required List<String> sefariaRefs,
  }) async {
    if (sefariaRefs.isEmpty) return const CaptureResult.success();
    final commands = await _requireCommands();
    return commands.unlearn(curriculumId.storageKey, sefariaRefs.toSet());
  }

  /// The leaves of [curriculumId] the learner marked "before tracking" and
  /// has not un-learnt (counted `before_tracking` events, node events
  /// expanded): the B7 pre-tick.
  Future<Set<String>> recordedRefs(CurriculumId curriculumId) async {
    final items = await _content.getContentForCurriculum(curriculumId);
    return _learntRefs(
      curriculumId,
      items,
      only: (e) => e.dateState == DateState.beforeTracking,
    );
  }

  Future<Set<String>> _learntRefs(
    CurriculumId curriculumId,
    List<ContentItem> items, {
    bool Function(LearningEvent e)? only,
  }) async {
    final events = await _events();
    if (events == null || events.isEmpty) return const {};
    final corpus = corpusOf(curriculumId, items);
    return {
      for (final e in countEvents(events).learns)
        if (e.curriculumId == curriculumId.storageKey &&
            (only == null || only(e)))
          ...coveredLeaves(e, corpus),
    };
  }
}
