/// The creating device's learner settings, read once when a profile is
/// created (AD-37: `time_zone` is "required, seeded from the creating
/// device"; DNI-470 AC-6).
///
/// - `time_zone` is the device's IANA zone from `flutter_timezone`. It is
///   required: a zone that cannot be read, is not an IANA id, or is not in
///   the tz database throws [LearnerTimeZoneUnavailableException] and the
///   profile is not created (never a silent device-offset or UTC
///   fallback).
/// - `latitude` / `longitude` / `in_israel` are the device's Sacred Time
///   location and in-Israel flag as currently set on this device. A device
///   with no location yet seeds none (the AD-36 fail-closed lock fallback
///   applies until a location is set through a governed change); the
///   in-Israel flag seeds its current value (default `false`).
///
/// This is the only place the creating device's Sacred Time preferences
/// feed a learner's settings; afterwards every reader goes through
/// `learnerLockSettingsProvider` (AD-37).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/sacred_time/data/services/sacred_time_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// The device's Sacred Time latitude, if a location is set.
  final double? latitude;

  /// The device's Sacred Time longitude, if a location is set.
  final double? longitude;

  /// The device's in-Israel flag.
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

/// The platform [CreatingDeviceSettingsSource]: `flutter_timezone` and the
/// device's Sacred Time preferences.
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
    final prefs = await SharedPreferences.getInstance();
    final location = SacredTimePreferences.readLocation(prefs);
    return CreatingDeviceSettings(
      timeZone: zone,
      latitude: location?.latitude,
      longitude: location?.longitude,
      inIsrael: SacredTimePreferences.readInIsrael(prefs),
    );
  }
}

/// The [CreatingDeviceSettingsSource] profile creation reads (tests
/// override it).
final creatingDeviceSettingsSourceProvider =
    Provider<CreatingDeviceSettingsSource>(
      (ref) => const PlatformCreatingDeviceSettingsSource(),
    );
