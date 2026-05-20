/// Typed value object for a stage's ordinal position within a curriculum track.
///
/// Stage orders are 1-based positive integers: stage 1 is always the initial
/// learning stage, stage 2 the first chazara (review), and so on.
///
/// ## Invariants
/// - [value] is ≥ 1.
///
/// ## Monotonic lists
/// A list of [StageOrder]s is monotonic when each element is exactly one
/// greater than the previous. Use [StageOrder.isMonotonicFrom] to verify
/// a sequence returned from the repository.
///
/// ## Usage
/// ```dart
/// final first = StageOrder(1);   // initial learn stage
/// final second = StageOrder(2);  // first chazara
///
/// // Convert from DB int (already 1-based):
/// final so = StageOrder(row.stageOrder);
///
/// // Back to DB int:
/// db.insert(stage_order: so.value);
/// ```
class StageOrder {
  /// Constructs a [StageOrder] from [value].
  ///
  /// Throws [ArgumentError] when [value] is less than 1.
  StageOrder(this.value) {
    if (value < 1) {
      throw ArgumentError.value(
        value,
        'value',
        'StageOrder must be ≥ 1.',
      );
    }
  }

  /// The 1-based ordinal position.
  final int value;

  // ---------------------------------------------------------------------------
  // Ordering helpers
  // ---------------------------------------------------------------------------

  /// Whether this stage order immediately precedes [other] (i.e. other.value == value + 1).
  bool precedes(StageOrder other) => other.value == value + 1;

  /// Whether this stage is the initial learn stage (value == 1).
  bool get isFirst => value == 1;

  /// The next stage order in sequence.
  StageOrder get next => StageOrder(value + 1);

  /// Returns `true` when [stages] form a monotonically increasing sequence
  /// starting at 1 with no gaps.
  ///
  /// An empty list is considered trivially monotonic.
  static bool isMonotonicFrom(Iterable<StageOrder> stages) {
    final list = stages.toList()..sort((a, b) => a.value.compareTo(b.value));
    for (var i = 0; i < list.length; i++) {
      if (list[i].value != i + 1) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Comparators
  // ---------------------------------------------------------------------------

  bool operator <(StageOrder other) => value < other.value;
  bool operator <=(StageOrder other) => value <= other.value;
  bool operator >(StageOrder other) => value > other.value;
  bool operator >=(StageOrder other) => value >= other.value;

  // ---------------------------------------------------------------------------
  // Equality + hash
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StageOrder && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StageOrder($value)';
}
