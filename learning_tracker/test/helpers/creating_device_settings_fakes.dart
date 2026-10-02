/// A fixed [CreatingDeviceSettingsSource] for tests that create profiles
/// through `FirestoreProfileRepositoryAdapter` (DNI-470 AC-6): no platform
/// channel, no SharedPreferences.
library;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/features/profiles/data/repositories/creating_device_settings_source.dart';

/// Reports [settings] on every read and counts the reads.
final class FakeCreatingDeviceSettingsSource
    implements CreatingDeviceSettingsSource {
  /// Creates the fake (Jerusalem zone, no location, in Israel by default).
  FakeCreatingDeviceSettingsSource([
    this.settings = const CreatingDeviceSettings(
      timeZone: 'Asia/Jerusalem',
      inIsrael: true,
    ),
  ]);

  /// What every read reports.
  CreatingDeviceSettings settings;

  /// How many times [read] ran.
  int reads = 0;

  @override
  Future<CreatingDeviceSettings> read() async {
    reads++;
    return settings;
  }
}

/// Overrides `creatingDeviceSettingsSourceProvider` with [source] (or a
/// default [FakeCreatingDeviceSettingsSource]).
Override creatingDeviceSettingsOverride([
  CreatingDeviceSettingsSource? source,
]) => creatingDeviceSettingsSourceProvider.overrideWithValue(
  source ?? FakeCreatingDeviceSettingsSource(),
);
