/// The Up to… selection (Story 2.10, DNI-501; UX-DR-18, UX-DR-72).
///
/// Pure Dart: each selectable row is independent. A tap toggles that row;
/// [tickAllUpTo] is the explicit bulk action. Only included rows are
/// recorded. Rows already ticked in this track stay selected and can never
/// be written twice.
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
  /// The first selectable row that is not selected.
  nextUp,

  /// Ticked: it will be recorded.
  included,

  /// Previously ticked by the user, then unticked.
  skipped,

  /// Ticked in this track before: not selectable.
  alreadyRecorded,

  /// Unticked: it gets no event.
  notSelected,
}

/// An immutable Up to… selection over [rows].
final class UpToSelection {
  /// A selection over [rows] with no user-selected rows.
  UpToSelection(List<UpToRow> rows)
    : this._(List.unmodifiable(rows), null, const {}, const {});

  const UpToSelection._(this.rows, this.target, this._included, this._skipped);

  /// The rows, from the position, in track order.
  final List<UpToRow> rows;

  /// The row most recently acted on; null before the first tap.
  final int? target;

  final Set<int> _included;
  final Set<int> _skipped;

  /// Row indexes previously ticked, then unticked.
  Set<int> get skipped => Set.unmodifiable(_skipped);

  /// Whether row [index] can be targeted or ticked.
  bool isSelectable(int index) =>
      index >= 0 && index < rows.length && !rows[index].recorded;

  /// Whether no row can be recorded (every row is already recorded, or
  /// there are none): the track is exhausted.
  bool get isExhausted => !rows.any((r) => !r.recorded);

  /// Explicitly ticks every selectable row through [index], preserving
  /// existing selections after it and leaving recorded rows unchanged.
  UpToSelection tickAllUpTo(int index) {
    if (!isSelectable(index)) return this;
    final included = {..._included};
    final skipped = {..._skipped};
    for (var i = 0; i <= index; i++) {
      if (!isSelectable(i)) continue;
      included.add(i);
      skipped.remove(i);
    }
    return UpToSelection._(rows, index, included, skipped);
  }

  /// Toggles only row [index]. Recorded or out-of-range rows are rejected.
  UpToSelection toggle(int index) {
    if (!isSelectable(index)) return this;
    final included = {..._included};
    final next = {..._skipped};
    if (included.remove(index)) {
      next.add(index);
    } else {
      included.add(index);
      next.remove(index);
    }
    return UpToSelection._(rows, index, included, next);
  }

  /// A row tap or checkbox activation toggles only that row.
  UpToSelection tick(int index) => toggle(index);

  /// The status row [index] announces.
  UpToRowStatus statusOf(int index) {
    if (rows[index].recorded) return UpToRowStatus.alreadyRecorded;
    if (target == null) {
      return index == _firstSelectable
          ? UpToRowStatus.nextUp
          : UpToRowStatus.notSelected;
    }
    if (_included.contains(index)) return UpToRowStatus.included;
    if (_skipped.contains(index)) return UpToRowStatus.skipped;
    return index == _firstSelectable
        ? UpToRowStatus.nextUp
        : UpToRowStatus.notSelected;
  }

  int get _firstSelectable => rows.indexWhere((r) => !r.recorded);

  /// The leaves to record, in track order.
  List<LeafRef> get includedRefs => [
    for (var i = 0; i < rows.length; i++)
      if (_included.contains(i)) rows[i].ref,
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
      'unticked: $_skipped)';
}
