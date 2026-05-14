/// Typed delta values for pace status calculations.
///
/// Using distinct types prevents the UI from accidentally displaying a
/// weekly-items deficit (PaceDelta) as if it were a calendar-days delta
/// (DateDelta). Pattern-match on the type to render the correct label.
library;

/// Calendar days the user is ahead (+) or behind (−) their deadline schedule.
///
/// Produced by [PaceCalculator.calculate] for deadline-based goals.
/// A positive value means the user is ahead; negative means behind.
///
/// Display: "+5 days ahead" or "3 days behind".
final class DateDelta {
  const DateDelta(this.days);

  /// Days ahead (positive) or behind (negative) the deadline schedule.
  final int days;

  @override
  bool operator ==(Object other) => other is DateDelta && other.days == days;

  @override
  int get hashCode => Object.hash(runtimeType, days);

  @override
  String toString() => 'DateDelta($days)';
}

/// Weekly item surplus (+) or deficit (−) relative to a pace goal.
///
/// Produced by [PaceCalculator.calculateForPaceGoal] for pace-based goals.
/// Value = `((rollingAverage − targetPacePerDay) * 7).round()`.
/// A positive value means the user is completing more items per week than
/// the target; negative means they are completing fewer.
///
/// Display: "+5 items/week ahead" or "3 items/week behind".
final class PaceDelta {
  const PaceDelta(this.itemsPerWeek);

  /// Weekly item surplus (positive) or deficit (negative).
  final int itemsPerWeek;

  @override
  bool operator ==(Object other) =>
      other is PaceDelta && other.itemsPerWeek == itemsPerWeek;

  @override
  int get hashCode => Object.hash(runtimeType, itemsPerWeek);

  @override
  String toString() => 'PaceDelta($itemsPerWeek)';
}

/// Sealed union of [DateDelta] and [PaceDelta].
///
/// Carried on [PaceStatus.delta] — the [daysDelta] field remains for
/// backward compatibility but UIs MUST switch on [delta] to render the
/// correct label.
sealed class ScheduleDelta {
  const ScheduleDelta();
}

/// [DateDelta] wrapped as a [ScheduleDelta].
final class DateScheduleDelta extends ScheduleDelta {
  const DateScheduleDelta(this.value);

  final DateDelta value;

  @override
  bool operator ==(Object other) =>
      other is DateScheduleDelta && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'DateScheduleDelta($value)';
}

/// [PaceDelta] wrapped as a [ScheduleDelta].
final class PaceScheduleDelta extends ScheduleDelta {
  const PaceScheduleDelta(this.value);

  final PaceDelta value;

  @override
  bool operator ==(Object other) =>
      other is PaceScheduleDelta && other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'PaceScheduleDelta($value)';
}
