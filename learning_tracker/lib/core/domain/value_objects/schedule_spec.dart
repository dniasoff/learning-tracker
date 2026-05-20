/// Sealed domain value object for a stage's review schedule.
///
/// Replaces the old nullable quartet
/// (`scheduleType enum + delayDays + daysOfWeek? + rollingWindowSize?`)
/// that was spread across [StageDefinition], [DefaultStageDefinition], and
/// the repository layer. A [ScheduleSpec] variant carries exactly the data
/// its variant needs — no extraneous nullable fields.
///
/// ### Variants
/// - [DelaySchedule] — item is due `delayDays` days after the previous
///   stage was completed. This is the default for all built-in stages.
/// - [WeeklySchedule] — review occurs on specific day(s) of the week.
///   [daysOfWeek] contains ISO weekday numbers (Mon=1 … Sun=7) and must
///   have at least one entry with all values in the range [1, 7].
/// - [RollingSchedule] — always review the last N items. [windowSize] must
///   be positive.
///
/// ### Storage
/// The repository encodes a [ScheduleSpec] as three database columns
/// (`schedule_type`, `delay_days`/`days_of_week`/`rolling_window_size`) for
/// backwards-compatibility during the current migration window. Once W3.27
/// lands (single JSON `schedule` column) the codec will be updated and the
/// old columns dropped.
///
/// Use [ScheduleSpec.fromParts] to reconstruct from the raw column values,
/// and the `storageKey` / accessors to write back.
sealed class ScheduleSpec {
  const ScheduleSpec();

  /// The string stored in the `schedule_type` DB column.
  String get storageKey;

  // ── Constructors for each variant ──────────────────────────────────────

  /// Delay-based schedule: item due [delayDays] days after previous stage.
  const factory ScheduleSpec.delay(int delayDays) = DelaySchedule;

  /// Weekly schedule: review on [daysOfWeek] (ISO Mon=1…Sun=7).
  ///
  /// Throws [ArgumentError] when [daysOfWeek] is empty or contains values
  /// outside 1–7.
  factory ScheduleSpec.weekly(List<int> daysOfWeek) = WeeklySchedule;

  /// Rolling window: always review the last [windowSize] items.
  ///
  /// Throws [ArgumentError] when [windowSize] ≤ 0.
  factory ScheduleSpec.rolling(int windowSize) = RollingSchedule;

  // ── Reconstruction from raw DB columns ─────────────────────────────────

  /// Reconstruct a [ScheduleSpec] from the three database column values that
  /// were written by the repository layer prior to W4.10.
  ///
  /// [scheduleTypeKey] must be one of `'delay'`, `'weekly'`, `'rolling'`.
  /// Falls back to [DelaySchedule] for unrecognised keys (legacy resilience).
  static ScheduleSpec fromParts({
    required String scheduleTypeKey,
    required int delayDays,
    required List<int>? daysOfWeek,
    required int? rollingWindowSize,
  }) {
    return switch (scheduleTypeKey) {
      'weekly' => WeeklySchedule(daysOfWeek ?? const []),
      'rolling' => RollingSchedule(rollingWindowSize ?? 1),
      _ => DelaySchedule(delayDays),
    };
  }

  // ── Convenience accessors for repository write-back ─────────────────────

  /// The `delay_days` column value for this spec.
  ///
  /// Non-zero only for [DelaySchedule]; other variants write 0.
  int get delayDays => switch (this) {
    DelaySchedule(:final delayDays) => delayDays,
    _ => 0,
  };

  /// The `days_of_week` column value (JSON-encoded) for this spec, or null.
  List<int>? get daysOfWeek => switch (this) {
    WeeklySchedule(:final daysOfWeek) => daysOfWeek,
    _ => null,
  };

  /// The `rolling_window_size` column value for this spec, or null.
  int? get rollingWindowSize => switch (this) {
    RollingSchedule(:final windowSize) => windowSize,
    _ => null,
  };
}

/// Delay-based schedule: the item is due [delayDays] days after the previous
/// stage was completed.
///
/// [delayDays] == 0 means "due immediately" (the Learn/לימוד stage).
final class DelaySchedule extends ScheduleSpec {
  const DelaySchedule(this.delayDays);

  final int delayDays;

  @override
  String get storageKey => 'delay';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DelaySchedule && other.delayDays == delayDays);

  @override
  int get hashCode => Object.hash(runtimeType, delayDays);

  @override
  String toString() => 'DelaySchedule(delayDays: $delayDays)';
}

/// Weekly schedule: the item is due on specific day(s) of the week.
///
/// [daysOfWeek] holds ISO weekday numbers (Mon = 1, …, Sun = 7).
/// Must have at least one value; all values must be in [1, 7].
final class WeeklySchedule extends ScheduleSpec {
  WeeklySchedule(List<int> daysOfWeek)
    : assert(daysOfWeek.isNotEmpty, 'daysOfWeek must not be empty'),
      assert(
        daysOfWeek.every((d) => d >= 1 && d <= 7),
        'daysOfWeek values must be 1 (Mon) through 7 (Sun)',
      ),
      daysOfWeek = List.unmodifiable(daysOfWeek);

  final List<int> daysOfWeek;

  @override
  String get storageKey => 'weekly';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklySchedule && _listEquals(other.daysOfWeek, daysOfWeek));

  @override
  int get hashCode => Object.hashAll([runtimeType, ...daysOfWeek]);

  @override
  String toString() => 'WeeklySchedule(daysOfWeek: $daysOfWeek)';
}

/// Rolling-window schedule: always review the last [windowSize] items.
///
/// [windowSize] must be positive (>= 1).
final class RollingSchedule extends ScheduleSpec {
  RollingSchedule(this.windowSize)
    : assert(windowSize > 0, 'windowSize must be positive, got $windowSize');

  final int windowSize;

  @override
  String get storageKey => 'rolling';

  /// Exposes `rollingWindowSize` under the standard accessor name.
  @override
  int? get rollingWindowSize => windowSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RollingSchedule && other.windowSize == windowSize);

  @override
  int get hashCode => Object.hash(runtimeType, windowSize);

  @override
  String toString() => 'RollingSchedule(windowSize: $windowSize)';
}

// ── Internal helpers ─────────────────────────────────────────────────────────

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
