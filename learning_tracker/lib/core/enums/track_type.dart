/// Identifies the learning track type for completions and bookmarks.
///
/// Each user can maintain separate progress for different track types
/// within the same curriculum (e.g., personal study vs. school program).
enum TrackType {
  personal('personal'),
  school('school'),
  tutor('tutor');

  const TrackType(this.value);

  /// String value used in database and Firestore.
  final String value;

  /// Parse from string value.
  static TrackType fromValue(String value) {
    return TrackType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw ArgumentError('Invalid TrackType: $value'),
    );
  }
}
