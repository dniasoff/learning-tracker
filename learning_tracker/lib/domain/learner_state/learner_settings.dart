/// AD-37 / AD-52 learner settings — the governed `learnerSettings` fields
/// of `learner_profiles/{profileId}`.
///
/// The profile doc is shared with ordinary (non-governed) profile fields
/// such as `display_name`, so [LearnerSettings.fromProfileDoc] is a
/// *projection*: it reads exactly the settings keys and ignores every other
/// profile key. [toStorage] emits ONLY settings keys — it can never re-emit
/// (or invent) a non-settings field.
library;

import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// The governed settings of one learner profile.
final class LearnerSettings {
  /// Creates settings.
  const LearnerSettings({
    required this.profileId,
    required this.timeZone,
    this.latitude,
    this.longitude,
    bool? inIsrael,
    this.yomTovDays,
    this.tzeisMinhag = defaultTzeisMinhag,
    this.candleLightingMinutes = defaultCandleLightingMinutes,
    this.locationSource,
    this.locationFixedAt,
    this.shnayimMikraMode = ShnayimMikraMode.pasuk,
    this.shnayimMikraPace = ShnayimMikraPace.self,
    this.shnayimMikraSource = ShnayimMikraSource.onkelos,
    this.shnayimMikraParshaSchedule,
    this.lastChangeId,
  }) : _legacyInIsrael = inIsrael;

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
      yomTovDays: r.optional<int>(kYomTovDays),
      tzeisMinhag: r.optional<String>(kTzeisMinhag) ?? defaultTzeisMinhag,
      candleLightingMinutes:
          r.optional<int>(kCandleLightingMinutes) ??
          defaultCandleLightingMinutes,
      locationSource: r.optional<String>(kLocationSource),
      locationFixedAt: r.optionalInstant(kLocationFixedAt),
      shnayimMikraMode: _decodeEnum(
        kShnayimMikraMode,
        r.optional<String>(kShnayimMikraMode),
        ShnayimMikraMode.pasuk,
        ShnayimMikraMode.values,
        (value) => value.storageKey,
      ),
      shnayimMikraPace: _decodeEnum(
        kShnayimMikraPace,
        r.optional<String>(kShnayimMikraPace),
        ShnayimMikraPace.self,
        ShnayimMikraPace.values,
        (value) => value.storageKey,
      ),
      shnayimMikraSource: _decodeEnum(
        kShnayimMikraSource,
        r.optional<String>(kShnayimMikraSource),
        ShnayimMikraSource.onkelos,
        ShnayimMikraSource.values,
        (value) => value.storageKey,
      ),
      shnayimMikraParshaSchedule: _decodeOptionalEnum(
        kShnayimMikraParshaSchedule,
        r.optional<String>(kShnayimMikraParshaSchedule),
        ShnayimMikraParshaSchedule.values,
        (value) => value.storageKey,
      ),
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
  static const kYomTovDays = 'yom_tov_days';
  static const kTzeisMinhag = 'tzeis_minhag';
  static const kCandleLightingMinutes = 'candle_lighting_minutes';
  static const kLocationSource = 'location_source';
  static const kLocationFixedAt = 'location_fixed_at';
  static const kShnayimMikraMode = 'shnayim_mikra_mode';
  static const kShnayimMikraPace = 'shnayim_mikra_pace';
  static const kShnayimMikraSource = 'shnayim_mikra_source';
  static const kShnayimMikraParshaSchedule = 'shnayim_mikra_parsha_schedule';
  static const defaultTzeisMinhag = 'degrees_8_5';
  static const defaultCandleLightingMinutes = 18;

  /// Storage key `last_change_id`.
  static const kLastChangeId = 'last_change_id';

  /// The AD-52 settings key set on `learner_profiles`.
  static const Set<String> storageKeys = {
    kLatitude,
    kLongitude,
    kTimeZone,
    kInIsrael,
    kYomTovDays,
    kTzeisMinhag,
    kCandleLightingMinutes,
    kLocationSource,
    kLocationFixedAt,
    kShnayimMikraMode,
    kShnayimMikraPace,
    kShnayimMikraSource,
    kShnayimMikraParshaSchedule,
    kLastChangeId,
  };

  static T _decodeEnum<T>(
    String field,
    String? raw,
    T fallback,
    Iterable<T> values,
    String Function(T value) storageKey,
  ) {
    if (raw == null) return fallback;
    for (final value in values) {
      if (storageKey(value) == raw) return value;
    }
    throw StorageFormatException(_type, field, 'unsupported value');
  }

  static T? _decodeOptionalEnum<T>(
    String field,
    String? raw,
    Iterable<T> values,
    String Function(T value) storageKey,
  ) {
    if (raw == null) return null;
    for (final value in values) {
      if (storageKey(value) == raw) return value;
    }
    throw StorageFormatException(_type, field, 'unsupported value');
  }

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
  ///
  /// This remains stored as `in_israel` for old-client compatibility. It is
  /// a minhag choice and is never inferred again after it has a value.
  final bool? _legacyInIsrael;

  /// Canonical minhag choice: `1` for Eretz Yisrael, `2` for chutz la'aretz.
  /// Null on legacy documents until the next governed settings write.
  final int? yomTovDays;

  /// Backwards-compatible one-day flag. New settings mirror this field so
  /// older clients continue to follow the selected minhag.
  bool? get inIsrael => yomTovDays == null ? _legacyInIsrael : yomTovDays == 1;

  /// Whether this learner keeps two days of Yom Tov (chutz la'aretz minhag).
  /// Exposed for calendar consumers that should not depend on location.
  bool get keepsTwoDaysYomTov =>
      yomTovDays == null ? _legacyInIsrael != true : yomTovDays == 2;

  /// Tzeis preset: degrees_8_5, minutes_72, or rabbeinu_tam.
  final String tzeisMinhag;

  /// Minutes before sunset for candle lighting (18/20/22/30/40).
  final int candleLightingMinutes;

  /// detected, manual_city, or manual_coords; absent on legacy documents.
  final String? locationSource;

  /// UTC time of the latest detected fix.
  final DateTime? locationFixedAt;

  /// Three-reading order, defaulting legacy learners to pasuk-by-pasuk.
  final ShnayimMikraMode shnayimMikraMode;

  /// Daily-aliyah pacing is opt-in; legacy learners are self-paced.
  final ShnayimMikraPace shnayimMikraPace;

  /// The third reading, defaulting to Onkelos for legacy learners.
  final ShnayimMikraSource shnayimMikraSource;

  /// Explicit weekly parsha minhag. Null only for legacy profiles or before
  /// Shnayim Mikra track creation initializes it from the Yom Tov setting.
  final ShnayimMikraParshaSchedule? shnayimMikraParshaSchedule;

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
      if (yomTovDays != null) ...{
        kYomTovDays: yomTovDays,
        kInIsrael: yomTovDays == 1,
      } else if (_legacyInIsrael != null)
        kInIsrael: _legacyInIsrael,
      if (tzeisMinhag != defaultTzeisMinhag) kTzeisMinhag: tzeisMinhag,
      if (candleLightingMinutes != defaultCandleLightingMinutes)
        kCandleLightingMinutes: candleLightingMinutes,
      if (locationSource != null) kLocationSource: locationSource,
      if (locationFixedAt != null) kLocationFixedAt: locationFixedAt!.toUtc(),
      if (shnayimMikraMode != ShnayimMikraMode.pasuk)
        kShnayimMikraMode: shnayimMikraMode.storageKey,
      if (shnayimMikraPace != ShnayimMikraPace.self)
        kShnayimMikraPace: shnayimMikraPace.storageKey,
      if (shnayimMikraSource != ShnayimMikraSource.onkelos)
        kShnayimMikraSource: shnayimMikraSource.storageKey,
      if (shnayimMikraParshaSchedule != null)
        kShnayimMikraParshaSchedule: shnayimMikraParshaSchedule!.storageKey,
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
    if (yomTovDays != null && ![1, 2].contains(yomTovDays)) {
      _fail(kYomTovDays, 'must be 1 or 2');
    }
    if (!{'degrees_8_5', 'minutes_72', 'rabbeinu_tam'}.contains(tzeisMinhag)) {
      _fail(kTzeisMinhag, 'unsupported minhag');
    }
    if (![18, 20, 22, 30, 40].contains(candleLightingMinutes)) {
      _fail(kCandleLightingMinutes, 'unsupported offset');
    }
    if (locationSource != null &&
        !{
          'detected',
          'manual_city',
          'manual_coords',
        }.contains(locationSource)) {
      _fail(kLocationSource, 'unsupported location source');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LearnerSettings &&
      other.profileId == profileId &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timeZone == timeZone &&
      other._legacyInIsrael == _legacyInIsrael &&
      other.yomTovDays == yomTovDays &&
      other.tzeisMinhag == tzeisMinhag &&
      other.candleLightingMinutes == candleLightingMinutes &&
      other.locationSource == locationSource &&
      other.locationFixedAt == locationFixedAt &&
      other.shnayimMikraMode == shnayimMikraMode &&
      other.shnayimMikraPace == shnayimMikraPace &&
      other.shnayimMikraSource == shnayimMikraSource &&
      other.shnayimMikraParshaSchedule == shnayimMikraParshaSchedule &&
      other.lastChangeId == lastChangeId;

  @override
  int get hashCode => Object.hash(
    profileId,
    latitude,
    longitude,
    timeZone,
    _legacyInIsrael,
    yomTovDays,
    tzeisMinhag,
    candleLightingMinutes,
    locationSource,
    locationFixedAt,
    shnayimMikraMode,
    shnayimMikraPace,
    shnayimMikraSource,
    lastChangeId,
  );

  @override
  String toString() => 'LearnerSettings($profileId, $timeZone)';
}
