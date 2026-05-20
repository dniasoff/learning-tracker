/// Schedule types for stage definitions.
///
/// Determines how a stage calculates when items are due for review.
enum ScheduleType {
  /// Delay-based: item due X days after previous stage completion.
  delay('delay'),

  /// Weekly: review on specific days of the week.
  weekly('weekly'),

  /// Rolling window: always review the last N items.
  rolling('rolling');

  const ScheduleType(this.storageKey);

  /// The string stored in the database.
  final String storageKey;

  /// Parse from database storage key.
  static ScheduleType fromStorageKey(String key) {
    return ScheduleType.values.firstWhere(
      (e) => e.storageKey == key,
      orElse: () => ScheduleType.delay,
    );
  }
}
