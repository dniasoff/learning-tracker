/// Identifies the type of learning track.
///
/// V1 ships with a single track type — `personal` — per the developer
/// handbook. Earlier designs had school and tutor variants; those were
/// scrapped before v1.
enum TrackType {
  /// Personal learning track — the only track type in v1.
  personal('personal');

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
  };
}
