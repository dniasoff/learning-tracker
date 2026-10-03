/// The *Adjust…* selection of a catch-up card (Story 3.4, DNI-507; screen
/// #10, AD-33, AD-40).
///
/// Ephemeral: it lives only while the card's Adjust panel is open and is
/// never stored (AD-52). Collapsing the panel drops it; only *Record*
/// turns it into a `CatchUpAction`.
///
/// The selection is one [CatchUpDaySelection] per locked day the card
/// covers (at most three, ascending), each holding one
/// [CatchUpGroupSelection] per source of each curriculum that planned
/// something on that day: the main track ("Home · Main track") and each
/// eligible sub-track. A group's rows are the planner's rows for that day
/// and source (every one ticked by default), followed by any later leaves
/// of the track's order the child included through *Up to…*.
///
/// ## One leaf, one day (AC-5)
///
/// A leaf of one curriculum and source belongs to at most one section: the
/// earliest day whose group shows it. A later group's row for the same
/// leaf is hidden from the [view], so the selection never yields two
/// events for one leaf across days. Ownership is derived, never written
/// into a group: editing one day's group never changes another's stored
/// rows, and removing a leaf from an earlier day lets the later day show
/// it again (AC-1/AC-3, AC-2/AC-5).
///
/// Pure Dart; immutable.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

/// One group's identity: a curriculum, a source and the locked day.
final class CatchUpGroupKey {
  /// Creates the key.
  const CatchUpGroupKey({
    required this.curriculumId,
    required this.source,
    required this.learnedOn,
  });

  /// The curriculum storage key.
  final String curriculumId;

  /// `main` or the sub-track ULID (the events' `source`).
  final String source;

  /// The locked day (`learned_on`) of the group's section.
  final String learnedOn;

  /// Whether the group is the main track.
  bool get isMain => source == LearningEvent.sourceMain;

  @override
  bool operator ==(Object other) =>
      other is CatchUpGroupKey &&
      other.curriculumId == curriculumId &&
      other.source == source &&
      other.learnedOn == learnedOn;

  @override
  int get hashCode => Object.hash(curriculumId, source, learnedOn);

  @override
  String toString() => 'CatchUpGroupKey($curriculumId, $source, $learnedOn)';
}

/// One leaf row of a group.
final class CatchUpRow {
  /// Creates the row.
  const CatchUpRow(this.ref, {this.stage, this.planned = false});

  /// The ContentIndex leaf.
  final LeafRef ref;

  /// The main-track stage the event carries; null for a sub-track.
  final int? stage;

  /// Whether the planner listed it for the group's day (it is always
  /// shown); false for a leaf added through *Up to…*.
  final bool planned;

  @override
  bool operator ==(Object other) =>
      other is CatchUpRow &&
      other.ref == ref &&
      other.stage == stage &&
      other.planned == planned;

  @override
  int get hashCode => Object.hash(ref, stage, planned);

  @override
  String toString() =>
      'CatchUpRow($ref${stage == null ? '' : ', stage $stage'}'
      '${planned ? ', planned' : ''})';
}

/// One source's rows on one locked day, with the leaves still included.
final class CatchUpGroupSelection {
  /// Creates the group.
  CatchUpGroupSelection({
    required this.key,
    required List<CatchUpRow> rows,
    required Set<LeafRef> included,
    this.subTrackName,
    this.extensionStage,
  }) : rows = List.unmodifiable(rows),
       included = Set.unmodifiable({
         for (final r in rows)
           if (included.contains(r.ref)) r.ref,
       });

  /// The group's curriculum, source and day.
  final CatchUpGroupKey key;

  /// The sub-track's name; null for the main track.
  final String? subTrackName;

  /// The stage a main-track leaf added through *Up to…* carries: the
  /// planner stage of the group's first new-learning row ([ASSUMPTION],
  /// as the today list's *Up to…* writes `firstStageOrder`). Null for a
  /// sub-track.
  final int? extensionStage;

  /// The rows in order: the planner's rows, then any *Up to…* leaves in
  /// the track's order.
  final List<CatchUpRow> rows;

  /// The leaves of [rows] that are ticked (to be recorded).
  final Set<LeafRef> included;

  /// The planner's rows only, in planner order.
  List<CatchUpRow> get plannedRows => [
    for (final r in rows)
      if (r.planned) r,
  ];

  /// A copy with [rows] and [included] replaced.
  CatchUpGroupSelection copyWith({
    List<CatchUpRow>? rows,
    Set<LeafRef>? included,
  }) => CatchUpGroupSelection(
    key: key,
    subTrackName: subTrackName,
    extensionStage: extensionStage,
    rows: rows ?? this.rows,
    included: included ?? this.included,
  );

  @override
  String toString() =>
      'CatchUpGroupSelection($key, ${rows.length} rows, '
      '${included.length} included)';
}

/// One locked day's section.
final class CatchUpDaySelection {
  /// Creates the section.
  CatchUpDaySelection({
    required this.day,
    required List<CatchUpGroupSelection> groups,
  }) : groups = List.unmodifiable(groups);

  /// The locked day.
  final LockedDay day;

  /// Its groups: per curriculum, the main track then sub-tracks in hub
  /// order.
  final List<CatchUpGroupSelection> groups;
}

/// What one group shows once earliest-day ownership is applied (AC-5).
final class CatchUpGroupView {
  /// Creates the view.
  CatchUpGroupView({
    required this.group,
    required List<CatchUpRow> rows,
    required Set<LeafRef> claimedEarlier,
  }) : rows = List.unmodifiable(rows),
       claimedEarlier = Set.unmodifiable(claimedEarlier);

  /// The stored group.
  final CatchUpGroupSelection group;

  /// The rows this section owns, in group order.
  final List<CatchUpRow> rows;

  /// Leaves of the same curriculum and source an earlier section shows:
  /// this group never offers or records them.
  final Set<LeafRef> claimedEarlier;

  /// The group key.
  CatchUpGroupKey get key => group.key;

  /// Whether [ref] is ticked here.
  bool isIncluded(LeafRef ref) =>
      group.included.contains(ref) && !claimedEarlier.contains(ref);

  /// The ticked rows, in order.
  List<CatchUpRow> get includedRows => [
    for (final r in rows)
      if (group.included.contains(r.ref)) r,
  ];

  /// The ticked row count.
  int get count => includedRows.length;
}

/// One section once earliest-day ownership is applied.
final class CatchUpDayView {
  /// Creates the view.
  CatchUpDayView({required this.day, required List<CatchUpGroupView> groups})
    : groups = List.unmodifiable(groups);

  /// The locked day.
  final LockedDay day;

  /// Its groups.
  final List<CatchUpGroupView> groups;

  /// The ticked rows of the section.
  int get count => groups.fold(0, (sum, g) => sum + g.count);
}

/// The Adjust panel's whole selection: the sections in day order.
final class CatchUpSelection {
  /// Creates the selection over [days] (ascending).
  CatchUpSelection(List<CatchUpDaySelection> days)
    : days = List.unmodifiable(days);

  /// The sections, ascending.
  final List<CatchUpDaySelection> days;

  /// The group stored under [key], or null.
  CatchUpGroupSelection? group(CatchUpGroupKey key) {
    for (final d in days) {
      for (final g in d.groups) {
        if (g.key == key) return g;
      }
    }
    return null;
  }

  /// The sections as shown: a leaf of one curriculum and source appears
  /// only in the earliest section whose group lists it (AC-5).
  List<CatchUpDayView> get view {
    final shown = <(String, String), Set<LeafRef>>{};
    final out = <CatchUpDayView>[];
    for (final d in days) {
      final groups = <CatchUpGroupView>[];
      final addedToday = <(String, String), Set<LeafRef>>{};
      for (final g in d.groups) {
        final id = (g.key.curriculumId, g.key.source);
        final earlier = shown[id] ?? const <LeafRef>{};
        final rows = [
          for (final r in g.rows)
            if (!earlier.contains(r.ref)) r,
        ];
        groups.add(
          CatchUpGroupView(group: g, rows: rows, claimedEarlier: earlier),
        );
        (addedToday[id] ??= {}).addAll(rows.map((r) => r.ref));
      }
      for (final MapEntry(:key, :value) in addedToday.entries) {
        (shown[key] ??= {}).addAll(value);
      }
      out.add(CatchUpDayView(day: d.day, groups: groups));
    }
    return out;
  }

  /// The live total of ticked leaves across every section (the *Record
  /// {n}* count).
  int get count => view.fold(0, (sum, d) => sum + d.count);

  /// Replaces the group under [key] with [next] (same key); every other
  /// group is untouched. An unknown key returns this selection.
  CatchUpSelection replace(CatchUpGroupSelection next) {
    var found = false;
    final days = [
      for (final d in this.days)
        CatchUpDaySelection(
          day: d.day,
          groups: [
            for (final g in d.groups)
              if (g.key == next.key) ...[next] else g,
          ],
        ),
    ];
    for (final d in this.days) {
      if (d.groups.any((g) => g.key == next.key)) found = true;
    }
    return found ? CatchUpSelection(days) : this;
  }

  /// Unticks [ref] in [key]'s group, or re-ticks it. A row the group does
  /// not show (unknown, or owned by an earlier section) is ignored.
  CatchUpSelection toggle(CatchUpGroupKey key, LeafRef ref) {
    for (final d in view) {
      for (final g in d.groups) {
        if (g.key != key) continue;
        if (!g.rows.any((r) => r.ref == ref)) return this;
        final next = {...g.group.included};
        if (!next.remove(ref)) next.add(ref);
        return replace(g.group.copyWith(included: next));
      }
    }
    return this;
  }
}
