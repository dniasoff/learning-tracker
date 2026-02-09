/// Identifies the type of learning track.
///
/// Each curriculum can have multiple active tracks. Personal track is
/// always present and cannot be removed. School and tutor tracks are optional.
enum TrackType {
  /// Personal learning track (always active, cannot be removed)
  personal('personal'),

  /// School-based learning track (optional)
  school('school'),

  /// Tutor-supervised learning track (optional)
  tutor('tutor');

  const TrackType(this.storageKey);

  /// Canonical string key used in database and Firestore.
  final String storageKey;

  /// Parse from storage key string.
  static TrackType fromStorageKey(String key) {
    return TrackType.values.firstWhere(
      (type) => type.storageKey == key,
      orElse: () => throw ArgumentError('Invalid TrackType key: $key'),
    );
  }

  /// Display name in English.
  String get displayNameEn => switch (this) {
    TrackType.personal => 'Personal',
    TrackType.school => 'School',
    TrackType.tutor => 'Tutor',
  };
}
