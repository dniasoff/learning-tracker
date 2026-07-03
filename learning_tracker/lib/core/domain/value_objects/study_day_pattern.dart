/// Kind of day in a study schedule.
///
/// Mirrors [features/scheduler/domain/models/day_type.dart] `DayType` but
/// lives in `core/` so the VO is independent of feature code. Feature-layer
/// code converts between `DayKind` and `DayType` at the boundary.
enum DayKind {
  /// An active study day — new content is scheduled.
  study,

  /// A review-only day — no new content, only chazara.
  review;

  /// Storage key used in the database `day_type` column.
  String get storageKey => name;

  /// Parses [key] from the database `day_type` column.
  ///
  /// Throws [ArgumentError] when [key] is not a recognised storage key.
  static DayKind fromStorageKey(String key) {
    return DayKind.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () =>
          throw ArgumentError.value(key, 'key', 'Unknown DayKind storage key.'),
    );
  }
}

/// Typed value object representing a weekly study schedule pattern.
///
/// Maps each ISO 8601 weekday (1 = Monday … 7 = Sunday) to a [DayKind],
/// indicating whether that day is a study day, a review day, or—when absent
/// from the map—implicitly a study day (the default per-day behaviour).
///
/// ## Invariants
/// - All weekday keys are in range 1..7 (ISO 8601).
/// - At least one weekday maps to [DayKind.study].
///
/// ## Equality
/// Two [WeeklyStudyDayPattern]s are equal when they have identical weekday→DayKind
/// mappings (order-independent Map equality).
///
/// ## Usage
/// ```dart
/// final pattern = WeeklyStudyDayPattern({
///   1: DayKind.study,   // Monday
///   2: DayKind.study,   // Tuesday
///   ...
///   6: DayKind.review,  // Saturday
///   7: DayKind.review,  // Sunday
/// });
///
/// final kind = pattern.dayKindFor(clock.today().weekday);
/// ```
class WeeklyStudyDayPattern {
  /// Creates a [WeeklyStudyDayPattern] from [entries] (weekday 1..7 → [DayKind]).
  ///
  /// All entries must use weekday values 1..7; at least one must be
  /// [DayKind.study]. Throws [ArgumentError] on violation.
  WeeklyStudyDayPattern(Map<int, DayKind> entries)
    : _entries = Map.unmodifiable(entries) {
    for (final key in entries.keys) {
      if (key < 1 || key > 7) {
        throw ArgumentError.value(
          key,
          'weekday',
          'Weekday must be in range 1..7 (ISO 8601).',
        );
      }
    }
    if (!entries.values.any((d) => d == DayKind.study)) {
      throw ArgumentError(
        'WeeklyStudyDayPattern must contain at least one study day.',
      );
    }
  }

  final Map<int, DayKind> _entries;

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// The default pattern: all 7 days are study days.
  factory WeeklyStudyDayPattern.allStudy() =>
      WeeklyStudyDayPattern({for (var i = 1; i <= 7; i++) i: DayKind.study});

  /// Convenience pattern: Mon–Fri study, Sat–Sun review.
  factory WeeklyStudyDayPattern.weekdaysStudy() => WeeklyStudyDayPattern({
    1: DayKind.study,
    2: DayKind.study,
    3: DayKind.study,
    4: DayKind.study,
    5: DayKind.study,
    6: DayKind.review,
    7: DayKind.review,
  });

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// Returns the [DayKind] for [weekday] (ISO 8601, 1=Mon…7=Sun).
  ///
  /// Defaults to [DayKind.study] when [weekday] is not in the pattern.
  DayKind dayKindFor(int weekday) => _entries[weekday] ?? DayKind.study;

  /// Whether [weekday] (ISO 8601) is a study day in this pattern.
  bool isStudyDay(int weekday) => dayKindFor(weekday) == DayKind.study;

  /// Whether [weekday] (ISO 8601) is a review-only day in this pattern.
  bool isReviewDay(int weekday) => dayKindFor(weekday) == DayKind.review;

  /// The count of weekdays mapped to [DayKind.study].
  int get studyDaysPerWeek =>
      _entries.values.where((d) => d == DayKind.study).length;

  /// An unmodifiable view of the weekday→DayKind mapping.
  Map<int, DayKind> get entries => _entries;

  // ---------------------------------------------------------------------------
  // Equality + hash
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WeeklyStudyDayPattern) return false;
    if (_entries.length != other._entries.length) return false;
    for (final entry in _entries.entries) {
      if (other._entries[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
    _entries.entries.map((e) => Object.hash(e.key, e.value)).toList()..sort(),
  );

  @override
  String toString() {
    final days = _entries.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final repr = days.map((e) => '${e.key}:${e.value.name}').join(', ');
    return 'WeeklyStudyDayPattern{$repr}';
  }
}
