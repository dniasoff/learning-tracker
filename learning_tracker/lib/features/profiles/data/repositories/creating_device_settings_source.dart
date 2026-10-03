/// The creating device's learner settings, read once when a profile is
/// created (AD-37: `time_zone` is "required, seeded from the creating
/// device"; DNI-470 AC-6).
///
/// - `time_zone` is the device's IANA zone from `flutter_timezone`. It is
///   required: a zone that cannot be read, is not an IANA id, or is not in
///   the tz database throws [LearnerTimeZoneUnavailableException] and the
///   profile is not created (never a silent device-offset or UTC
///   fallback).
/// - No location is seeded (DNI-481 AC-4: nothing reads or copies device
///   preferences into a profile — the device-global Sacred Time
///   preferences are deleted). The AD-36 fail-closed lock fallback applies
///   until a parent sets the learner's location through a governed change,
///   and the after-lock prompt asks for it (AC-2).
/// - `in_israel` seeds `false` (diaspora: two-day yom tov, the fail-closed
///   superset of the Israel days) until set through a governed change.
///
/// Afterwards every reader goes through `learnerLockSettingsProvider`
/// (AD-37).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';

/// The raw settings the creating device reports.
final class CreatingDeviceSettings {
  /// Creates the reading.
  const CreatingDeviceSettings({
    required this.timeZone,
    required this.inIsrael,
    this.latitude,
    this.longitude,
  });

  /// The device's IANA zone id, or null when it could not be read.
  final String? timeZone;

  /// The seed latitude, if a location is known (none from the platform
  /// source).
  final double? latitude;

  /// The seed longitude, if a location is known (none from the platform
  /// source).
  final double? longitude;

  /// The seed in-Israel flag.
  final bool inIsrael;

  /// The seed [LearnerSettings] of new profile [profileId].
  ///
  /// Throws [LearnerTimeZoneUnavailableException] when [timeZone] is
  /// missing, not an IANA id, or unknown to the tz database.
  LearnerSettings seedFor(String profileId) {
    final zone = timeZone;
    if (zone == null || !LearnerZone.of(zone).isKnown) {
      throw LearnerTimeZoneUnavailableException(zone);
    }
    try {
      LearnerSettings(profileId: profileId, timeZone: zone).toStorage();
    } on StorageFormatException {
      throw LearnerTimeZoneUnavailableException(zone); // not an IANA id
    }
    final withLocation = LearnerSettings(
      profileId: profileId,
      timeZone: zone,
      latitude: latitude,
      longitude: longitude,
      inIsrael: inIsrael,
    );
    try {
      return withLocation..toStorage(); // AD-52 ranges, lat/long together
    } on StorageFormatException {
      // An unusable device location seeds none (AD-36 fail-closed lock
      // fallback until a location is set) rather than blocking creation.
      return LearnerSettings(
        profileId: profileId,
        timeZone: zone,
        inIsrael: inIsrael,
      );
    }
  }
}

/// Reads the creating device's settings.
abstract interface class CreatingDeviceSettingsSource {
  /// The current reading.
  Future<CreatingDeviceSettings> read();
}

/// The platform [CreatingDeviceSettingsSource]: the device's IANA zone from
/// `flutter_timezone`, no location and diaspora (DNI-481: no device
/// preference is read).
final class PlatformCreatingDeviceSettingsSource
    implements CreatingDeviceSettingsSource {
  /// Creates the source.
  const PlatformCreatingDeviceSettingsSource();

  @override
  Future<CreatingDeviceSettings> read() async {
    String? zone;
    try {
      zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } on Object {
      zone = null; // unreadable: creation is blocked by seedFor
    }
    return CreatingDeviceSettings(timeZone: zone, inIsrael: false);
  }
}

/// The [CreatingDeviceSettingsSource] profile creation reads (tests
/// override it).
final creatingDeviceSettingsSourceProvider =
    Provider<CreatingDeviceSettingsSource>(
      (ref) => const PlatformCreatingDeviceSettingsSource(),
    );
