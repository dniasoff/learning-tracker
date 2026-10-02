/// The Mishna-history read model (Story 1.13, DNI-475; FR-30, UX-DR-41).
///
/// A pure projection of three complete inputs: the profile's learn/void log
/// ([ProfileHistoryLog]), the engine's [LearnerState] (AD-35) and the
/// curriculum's [Corpus]. It never recomputes learner progress:
///
/// - **Learnt** is the engine's `learntLeaves` membership;
/// - **counted** is the engine's `countedEventIds` (and
///   `lockIgnoredEventIds`); a learn is *voided* when a loaded `void`
///   that is not itself lock-ignored targets it (AD-31 — a void of a void
///   has no target here, so it is ignored; AD-36 — a lock-ignored event,
///   void or learn, takes no part in voiding, exactly as the engine's
///   `countEvents`), and *lock-ignored* when it is neither voided nor
///   counted — no second lock-window calculation (AD-36);
/// - the **Learning events** count is the number of non-voided events
///   (FR-30, AC-1) — counted and lock-ignored alike, repeats included —
///   while distinct goal progress stays the engine's `distinctLearnt`
///   (AD-32, UX-DR-153);
/// - **chazara** is derived (every counted event after the first, in
///   `effectiveAt` order) and never stored (AD-32).
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/learning/domain/models/profile_history_log.dart';

/// Who is looking at the history; decides visibility and corrections.
enum MishnaHistoryViewer {
  /// The child session: voided rows hidden; removal, plus re-date of a
  /// catch-up event (FR-4, Story 1.7 child limits).
  child,

  /// The parent session: every row; remove or correct place/source/date.
  parent,

  /// A tutor: read-only until Story 1.24 wires tutor corrections.
  tutor,
}

/// How an event row stands in the engine's output.
enum MishnaHistoryStatus {
  /// Counts toward the learnt state.
  counted,

  /// Cancelled by a `void` (shown to parent/tutor only).
  voided,

  /// Recorded inside a Shabbos/Yom Tov lock window: kept, not counted.
  lockIgnored,
}

/// The kind of source chip a row shows (UX-DR-21).
enum MishnaHistorySourceKind {
  /// `source == main`.
  home,

  /// A sub-track, live or ended, named by its stored `name`.
  subTrack,

  /// A sub-track id the complete read does not hold. Labelled generically,
  /// never with the ULID.
  unknownSubTrack,
}

/// A correction a row offers (FR-4).
enum MishnaCorrection {
  /// `LearningCommands.voidEvent`.
  remove,

  /// `LearningCommands.replace` with a new leaf `ref`.
  changePlace,

  /// `LearningCommands.replace` to Home or Before tracking.
  changeSource,

  /// `LearningCommands.replace` with a new `learned_on`.
  changeDate,
}

/// One learn event as a history row.
final class MishnaHistoryItem {
  /// Creates a row.
  const MishnaHistoryItem({
    required this.event,
    required this.status,
    required this.sourceKind,
    this.sourceName,
    this.sourceEnded = false,
    this.ordinal,
    this.isChazara = false,
    this.pending = false,
  });

  /// The learn event.
  final LearningEvent event;

  /// Counted, voided or lock-ignored.
  final MishnaHistoryStatus status;

  /// The source chip kind.
  final MishnaHistorySourceKind sourceKind;

  /// The sub-track's stored name, for [MishnaHistorySourceKind.subTrack].
  final String? sourceName;

  /// Whether that sub-track is ended (tombstoned).
  final bool sourceEnded;

  /// 1-based position among counted events in `effectiveAt` order; null for
  /// a row that does not count.
  final int? ordinal;

  /// Derived: a counted repeat (not the first counted event).
  final bool isChazara;

  /// An optimistic correction is in flight for this row.
  final bool pending;

  /// The event id.
  String get eventId => event.id;

  /// AD-31 history instant.
  DateTime get effectiveAtUtc => effectiveAt(event);

  /// The date state.
  DateState get dateState => event.dateState!;

  /// The civil date learnt, or null for Before tracking.
  String? get learnedOn => event.learnedOn;

  /// Learnt on a locked day and recorded in its catch-up window.
  bool get isCatchUp => dateState == DateState.catchUp;

  /// Learnt before tracking began.
  bool get isBeforeTracking => dateState == DateState.beforeTracking;

  /// A Before-tracking event on a node above this leaf (AD-31 node ref).
  bool get isNodeEvent => event.level != null;

  /// A copy with the given fields replaced.
  MishnaHistoryItem copyWith({
    LearningEvent? event,
    MishnaHistoryStatus? status,
    MishnaHistorySourceKind? sourceKind,
    String? sourceName,
    bool? sourceEnded,
    bool? pending,
  }) => MishnaHistoryItem(
    event: event ?? this.event,
    status: status ?? this.status,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceName: sourceName ?? this.sourceName,
    sourceEnded: sourceEnded ?? this.sourceEnded,
    ordinal: ordinal,
    isChazara: isChazara,
    pending: pending ?? this.pending,
  );

  @override
  String toString() => 'MishnaHistoryItem($eventId, ${status.name})';
}

/// The history of one leaf of one curriculum.
final class MishnaHistory {
  /// Creates a history.
  MishnaHistory({
    required this.curriculumId,
    required this.leafRef,
    required this.learnt,
    required this.eventCount,
    required List<MishnaHistoryItem> items,
    List<LeafRef> placeChoices = const [],
  }) : items = List.unmodifiable(items),
       placeChoices = List.unmodifiable(placeChoices);

  /// Projects the history of [leafRef] in [curriculumId].
  ///
  /// [corpus] (the unscoped ContentIndex tree) lets a Before-tracking node
  /// event that covers the leaf appear, and supplies [placeChoices] — the
  /// leaf's siblings under its parent unit. Without it only events on the
  /// leaf itself appear and no place choice is offered.
  factory MishnaHistory.project({
    required String curriculumId,
    required LeafRef leafRef,
    required ProfileHistoryLog log,
    required LearnerState state,
    Corpus? corpus,
  }) {
    bool covers(LearningEvent e) {
      if (!e.isLearn || e.curriculumId != curriculumId) return false;
      if (e.ref == leafRef) return true;
      if (corpus == null || e.dateState != DateState.beforeTracking) {
        return false;
      }
      final node = corpus.nodeForRef(e.ref!);
      return node != null &&
          !corpus.isLeaf(node) &&
          corpus.leavesUnder(node).contains(leafRef);
    }

    final learns = log.events.where(covers).toList();
    // Mirror the engine's counted-event boundary (`countEvents`): a
    // lock-ignored event takes no part at all, so a lock-ignored void
    // cancels nothing and a void of a lock-ignored learn leaves it
    // lock-ignored (AD-36). The lock decision itself is the engine's
    // `lockIgnoredEventIds`; nothing is recalculated here.
    final ignored = state.lockIgnoredEventIds;
    final liveLearnIds = {
      for (final e in learns)
        if (!ignored.contains(e.id)) e.id,
    };
    final voided = {
      for (final e in log.events)
        if (e.isVoid &&
            !ignored.contains(e.id) &&
            liveLearnIds.contains(e.targetId))
          e.targetId!,
    };

    MishnaHistoryStatus statusOf(LearningEvent e) {
      if (voided.contains(e.id)) return MishnaHistoryStatus.voided;
      if (state.countedEventIds.contains(e.id) &&
          !state.lockIgnoredEventIds.contains(e.id)) {
        return MishnaHistoryStatus.counted;
      }
      return MishnaHistoryStatus.lockIgnored;
    }

    int chronological(LearningEvent a, LearningEvent b) {
      final byTime = effectiveAt(a).compareTo(effectiveAt(b));
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    }

    final counted =
        learns.where((e) => statusOf(e) == MishnaHistoryStatus.counted).toList()
          ..sort(chronological);
    final ordinals = {
      for (var i = 0; i < counted.length; i++) counted[i].id: i + 1,
    };

    MishnaHistoryItem itemOf(LearningEvent e) {
      final ordinal = ordinals[e.id];
      final source = e.source!;
      final track = source == LearningEvent.sourceMain
          ? null
          : log.subTracksById[source];
      return MishnaHistoryItem(
        event: e,
        status: statusOf(e),
        sourceKind: source == LearningEvent.sourceMain
            ? MishnaHistorySourceKind.home
            : track == null
            ? MishnaHistorySourceKind.unknownSubTrack
            : MishnaHistorySourceKind.subTrack,
        sourceName: track?.name,
        sourceEnded: track?.endedAt != null,
        ordinal: ordinal,
        isChazara: ordinal != null && ordinal > 1,
      );
    }

    final newestFirst = [...learns]..sort((a, b) => chronological(b, a));

    var placeChoices = const <LeafRef>[];
    if (corpus != null) {
      final node = corpus.nodeForRef(leafRef);
      final parent = node == null ? null : corpus.parentOf(node);
      if (parent != null) {
        placeChoices = [
          for (final ref in corpus.leavesUnder(parent))
            if (ref != leafRef) ref,
        ];
      }
    }

    return MishnaHistory(
      curriculumId: curriculumId,
      leafRef: leafRef,
      learnt: state[curriculumId]?.learntLeaves.contains(leafRef) ?? false,
      // FR-30: every non-voided event, lock-ignored ones included; only the
      // ordinals (and so chazara) are limited to counted events.
      eventCount: learns
          .where((e) => statusOf(e) != MishnaHistoryStatus.voided)
          .length,
      items: [for (final e in newestFirst) itemOf(e)],
      placeChoices: placeChoices,
    );
  }

  /// The curriculum.
  final String curriculumId;

  /// The leaf.
  final LeafRef leafRef;

  /// The engine's Learnt state for the leaf.
  final bool learnt;

  /// "Learning events": every non-voided event (FR-30), repeats and
  /// lock-ignored events included. Not goal progress (AD-32).
  final int eventCount;

  /// Every learn row (counted, voided, lock-ignored), newest first by
  /// `effectiveAt`, ties broken by descending event id.
  final List<MishnaHistoryItem> items;

  /// Leaves a parent may move an event to (the leaf's siblings).
  final List<LeafRef> placeChoices;

  /// Whether the header shows the [eventCount]: always for a learnt leaf,
  /// and for an unlearnt one whenever a non-voided (lock-ignored) event
  /// exists — the count never depends on the Learnt state alone (FR-30).
  bool get showsEventCount => learnt || eventCount > 0;

  /// The rows [viewer] sees, newest first.
  ///
  /// A learnt leaf shows every row, except voided rows for a child (FR-30).
  /// An unlearnt leaf shows only its lock-ignored rows — kept, not counted
  /// (AD-36) — so a mishna ticked only during Shabbos/Yom Tov still
  /// explains itself under "Not learnt yet"; with none, the list is empty
  /// (UX-DR-140; story [ASSUMPTION]: voided-only stays the empty state for
  /// every viewer).
  List<MishnaHistoryItem> visibleTo(MishnaHistoryViewer viewer) {
    if (!learnt) {
      return [
        for (final item in items)
          if (item.status == MishnaHistoryStatus.lockIgnored) item,
      ];
    }
    if (viewer != MishnaHistoryViewer.child) return items;
    return [
      for (final item in items)
        if (item.status != MishnaHistoryStatus.voided) item,
    ];
  }

  /// [items] with optimistic [overlays] (by event id) applied.
  MishnaHistory withOverlays(Map<String, MishnaHistoryItem> overlays) {
    if (overlays.isEmpty) return this;
    return MishnaHistory(
      curriculumId: curriculumId,
      leafRef: leafRef,
      learnt: learnt,
      eventCount: eventCount,
      items: [for (final item in items) overlays[item.eventId] ?? item],
      placeChoices: placeChoices,
    );
  }
}

/// The corrections [item] offers to [viewer] (FR-4, Story 1.7 limits).
///
/// No action on a row that does not count (voided, or lock-ignored —
/// AD-36: no Undo for a lock-ignored event), on a row with a correction in
/// flight, on a Before-tracking node event (it spans other leaves), or for
/// a tutor (Story 1.24). A child may remove, and re-date only a catch-up
/// event (its catch-up window is enforced by `LearningCommands`, which
/// returns `childLimit` outside it). A parent may also change the place
/// (when [placeChoices] is non-empty) and the source.
Set<MishnaCorrection> allowedCorrections(
  MishnaHistoryItem item,
  MishnaHistoryViewer viewer, {
  bool hasPlaceChoices = false,
}) {
  if (item.pending ||
      item.status != MishnaHistoryStatus.counted ||
      item.isNodeEvent) {
    return const {};
  }
  return switch (viewer) {
    MishnaHistoryViewer.tutor => const {},
    MishnaHistoryViewer.child => {
      MishnaCorrection.remove,
      if (item.isCatchUp) MishnaCorrection.changeDate,
    },
    MishnaHistoryViewer.parent => {
      MishnaCorrection.remove,
      if (hasPlaceChoices) MishnaCorrection.changePlace,
      MishnaCorrection.changeSource,
      MishnaCorrection.changeDate,
    },
  };
}
