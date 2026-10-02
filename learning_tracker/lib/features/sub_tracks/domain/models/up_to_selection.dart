/// The Up to… run selection (Story 2.10, DNI-501; UX-DR-18, UX-DR-72).
///
/// Pure Dart: the picker's rows run from the track position through the end
/// of its ground (sub-track) or its schedulable leaves (main track). The
/// child taps a target; every selectable row from the position through it
/// is included, any of them can then be unticked (skipped) or re-ticked,
/// and only the included rows are recorded. Rows already ticked in this
/// track are shown but never selectable, so they are never written twice.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';

/// One leaf row of the picker, in track order.
final class UpToRow {
  /// Creates a row.
  const UpToRow(this.ref, {this.recorded = false});

  /// The leaf.
  final LeafRef ref;

  /// Already ticked in this track: shown, not selectable, never written.
  final bool recorded;

  @override
  bool operator ==(Object other) =>
      other is UpToRow && other.ref == ref && other.recorded == recorded;

  @override
  int get hashCode => Object.hash(ref, recorded);

  @override
  String toString() => 'UpToRow($ref${recorded ? ', recorded' : ''})';
}

/// What a row announces (UX-DR-157).
enum UpToRowStatus {
  /// The first row before any target is chosen: the track position.
  nextUp,

  /// In the run and ticked: it will be recorded.
  included,

  /// In the run but unticked: it gets no event.
  skipped,

  /// Ticked in this track before: not selectable.
  alreadyRecorded,

  /// After the target (or no target yet): not part of the run.
  notSelected,
}

/// An immutable Up to… selection over [rows].
final class UpToSelection {
  /// A selection over [rows] with no target yet.
  UpToSelection(List<UpToRow> rows)
    : this._(List.unmodifiable(rows), null, const {});

  const UpToSelection._(this.rows, this.target, this._skipped);

  /// The rows, from the position, in track order.
  final List<UpToRow> rows;

  /// The highlighted target row index; null before the first tap.
  final int? target;

  final Set<int> _skipped;

  /// The skipped row indexes inside the run.
  Set<int> get skipped => Set.unmodifiable(_skipped);

  /// Whether row [index] can be targeted or ticked.
  bool isSelectable(int index) =>
      index >= 0 && index < rows.length && !rows[index].recorded;

  /// Whether no row can be recorded (every row is already recorded, or
  /// there are none): the track is exhausted.
  bool get isExhausted => !rows.any((r) => !r.recorded);

  /// Whether row [index] is inside the run (position through target).
  bool inRun(int index) {
    final t = target;
    return t != null && index >= 0 && index <= t;
  }

  /// Targets row [index]: the run becomes every selectable row from the
  /// position through it, keeping the skips still inside it. A recorded or
  /// out-of-range row is rejected (the selection is returned unchanged).
  UpToSelection selectTarget(int index) {
    if (!isSelectable(index)) return this;
    return UpToSelection._(rows, index, {
      for (final i in _skipped)
        if (i <= index) i,
    });
  }

  /// Unticks an included row, or re-ticks a skipped one. A row outside the
  /// run, or a recorded row, is rejected (unchanged).
  UpToSelection toggle(int index) {
    if (!isSelectable(index) || !inRun(index)) return this;
    final next = {..._skipped};
    if (!next.remove(index)) next.add(index);
    return UpToSelection._(rows, target, next);
  }

  /// The tap on row [index]'s tick: inside the run it toggles the row,
  /// outside it targets the row (so ticking a later row extends the run).
  UpToSelection tick(int index) =>
      inRun(index) ? toggle(index) : selectTarget(index);

  /// The status row [index] announces.
  UpToRowStatus statusOf(int index) {
    if (rows[index].recorded) return UpToRowStatus.alreadyRecorded;
    if (target == null) {
      return index == _firstSelectable
          ? UpToRowStatus.nextUp
          : UpToRowStatus.notSelected;
    }
    if (!inRun(index)) return UpToRowStatus.notSelected;
    return _skipped.contains(index)
        ? UpToRowStatus.skipped
        : UpToRowStatus.included;
  }

  int get _firstSelectable => rows.indexWhere((r) => !r.recorded);

  /// The leaves to record, in track order.
  List<LeafRef> get includedRefs => [
    for (var i = 0; i < rows.length; i++)
      if (statusOf(i) == UpToRowStatus.included) rows[i].ref,
  ];

  /// The live count: included rows only.
  int get count => includedRefs.length;

  /// The track position once the included rows are recorded: the first row
  /// that is neither already recorded nor included; null when none is left
  /// (FR-2a). The engine derives the real position; this is the optimistic
  /// view of the same rule.
  LeafRef? get positionAfterRecord {
    final included = includedRefs.toSet();
    for (final r in rows) {
      if (!r.recorded && !included.contains(r.ref)) return r.ref;
    }
    return null;
  }

  @override
  String toString() =>
      'UpToSelection(${rows.length} rows, target: $target, '
      'skipped: $_skipped)';
}
