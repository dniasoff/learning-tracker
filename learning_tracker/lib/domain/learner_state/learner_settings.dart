/// AD-37 / AD-52 learner settings — the governed `learnerSettings` fields
/// of `learner_profiles/{profileId}`.
///
/// The profile doc is shared with ordinary (non-governed) profile fields
/// such as `display_name`, so [LearnerSettings.fromProfileDoc] is a
/// *projection*: it reads exactly the settings keys and ignores every other
/// profile key. [toStorage] emits ONLY settings keys — it can never re-emit
/// (or invent) a non-settings field.
library;

import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// The governed settings of one learner profile.
final class LearnerSettings {
  /// Creates settings.
  const LearnerSettings({
    required this.profileId,
    required this.timeZone,
    this.latitude,
    this.longitude,
    this.inIsrael,
    this.lastChangeId,
  });

  /// Projects the settings keys out of a `learner_profiles` doc [map].
  ///
  /// Settings keys are validated strictly (types, ranges, IANA shape);
  /// non-settings keys are ignored, never carried.
  factory LearnerSettings.fromProfileDoc(
    String profileId,
    Map<String, Object?> map,
  ) {
    final r = StorageReader(_type, map);
    final settings = LearnerSettings(
      profileId: profileId,
      latitude: r.optionalNumber(kLatitude),
      longitude: r.optionalNumber(kLongitude),
      timeZone: r.requiredString(kTimeZone),
      inIsrael: r.optional<bool>(kInIsrael),
      lastChangeId: r.optionalUlid(kLastChangeId),
    );
    return settings.._validate();
  }

  static const _type = 'LearnerSettings';

  /// Storage key `latitude`.
  static const kLatitude = 'latitude';

  /// Storage key `longitude`.
  static const kLongitude = 'longitude';

  /// Storage key `time_zone`.
  static const kTimeZone = 'time_zone';

  /// Storage key `in_israel`.
  static const kInIsrael = 'in_israel';

  /// Storage key `last_change_id`.
  static const kLastChangeId = 'last_change_id';

  /// The AD-52 settings key set on `learner_profiles`.
  static const Set<String> storageKeys = {
    kLatitude,
    kLongitude,
    kTimeZone,
    kInIsrael,
    kLastChangeId,
  };

  /// IANA zone id shape (`UTC`, `Asia/Jerusalem`, `America/Argentina/Salta`,
  /// `Etc/GMT+5`). Existence in the tz database is checked where the zone
  /// is used (AD-41), not by this codec.
  static final RegExp _ianaPattern = RegExp(
    r'^(UTC|[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)+)$',
  );

  /// The profile ULID (`change_log.entity_id` for `learnerSettings`).
  final String profileId;

  /// Latitude in degrees, or null when no location is set (fail-closed
  /// lock fallback, AD-36).
  final double? latitude;

  /// Longitude in degrees, set iff [latitude] is set.
  final double? longitude;

  /// IANA time zone (required, seeded from the creating device).
  final String timeZone;

  /// Whether the learner keeps one-day yom tov; null when never set.
  final bool? inIsrael;

  /// Last governed change, or null for a profile with no entry yet.
  final String? lastChangeId;

  /// Whether a location is set.
  bool get hasLocation => latitude != null;

  /// Encodes ONLY the settings keys; optional keys are omitted while null.
  Map<String, Object?> toStorage() {
    _validate();
    return {
      if (latitude != null) kLatitude: latitude,
      if (longitude != null) kLongitude: longitude,
      kTimeZone: timeZone,
      if (inIsrael != null) kInIsrael: inIsrael,
      if (lastChangeId != null) kLastChangeId: lastChangeId,
    };
  }

  Never _fail(String field, String reason) =>
      throw StorageFormatException(_type, field, reason);

  void _validate() {
    if (!isUlid(profileId)) _fail('<id>', 'profile id is not a ULID');
    if ((latitude == null) != (longitude == null)) {
      _fail(kLongitude, 'latitude and longitude must be set together');
    }
    final lat = latitude;
    if (lat != null && (!lat.isFinite || lat < -90 || lat > 90)) {
      _fail(kLatitude, 'out of range');
    }
    final lng = longitude;
    if (lng != null && (!lng.isFinite || lng < -180 || lng > 180)) {
      _fail(kLongitude, 'out of range');
    }
    if (!_ianaPattern.hasMatch(timeZone)) {
      _fail(kTimeZone, 'not an IANA zone id');
    }
    final change = lastChangeId;
    if (change != null && !isUlid(change)) _fail(kLastChangeId, 'not a ULID');
  }

  @override
  bool operator ==(Object other) =>
      other is LearnerSettings &&
      other.profileId == profileId &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timeZone == timeZone &&
      other.inIsrael == inIsrael &&
      other.lastChangeId == lastChangeId;

  @override
  int get hashCode => Object.hash(
    profileId,
    latitude,
    longitude,
    timeZone,
    inIsrael,
    lastChangeId,
  );

  @override
  String toString() => 'LearnerSettings($profileId, $timeZone)';
}
