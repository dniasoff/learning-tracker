/// DNI-470 AC-6: the creating device's reading becomes a profile's seed
/// settings only with a real IANA zone.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/features/profiles/data/repositories/creating_device_settings_source.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/retired_inventory.dart';

void main() {
  test('seedFor carries every device value onto the new profile', () {
    const reading = CreatingDeviceSettings(
      timeZone: 'Asia/Jerusalem',
      latitude: 31.778,
      longitude: 35.235,
      inIsrael: true,
    );
    expect(
      reading.seedFor(profileUlid),
      const LearnerSettings(
        profileId: profileUlid,
        timeZone: 'Asia/Jerusalem',
        latitude: 31.778,
        longitude: 35.235,
        inIsrael: true,
      ),
    );
  });

  test('no location seeds none; UTC is a valid zone', () {
    const reading = CreatingDeviceSettings(timeZone: 'UTC', inIsrael: false);
    final seed = reading.seedFor(profileUlid);
    expect(seed.hasLocation, isFalse);
    expect(seed.inIsrael, isFalse);
  });

  for (final zone in [null, '', '+02:00', 'Not/A_Zone']) {
    test('an unusable zone ($zone) throws, never falls back', () {
      expect(
        () => CreatingDeviceSettings(
          timeZone: zone,
          inIsrael: false,
        ).seedFor(profileUlid),
        throwsA(
          isA<LearnerTimeZoneUnavailableException>().having(
            (e) => e.timeZone,
            'timeZone',
            zone,
          ),
        ),
      );
    });
  }

  test('an unusable device location (half-set or out of range) seeds no '
      'location rather than blocking creation', () {
    for (final (lat, lng) in [(31.0, null), (91.0, 35.0)]) {
      final seed = CreatingDeviceSettings(
        timeZone: 'UTC',
        latitude: lat,
        longitude: lng,
        inIsrael: true,
      ).seedFor(profileUlid);
      expect(seed.hasLocation, isFalse);
      expect(seed.longitude, isNull);
      expect(seed.inIsrael, isTrue);
    }
  });

  group('PlatformCreatingDeviceSettingsSource (DNI-481 AC-4)', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('reads only the device zone: no device preference (the retired '
        'Sacred Time location / in-Israel keys) reaches the seed', () async {
      // Every retired R9 preference key, from the AD-49 inventory, at a
      // value of its stored type.
      SharedPreferences.setMockInitialValues({
        for (final key in retiredKeysOf('lib/**', group: 'R9'))
          key: key.endsWith('israel')
              ? true
              : key.endsWith('_ms')
              ? 1
              : key.endsWith('itude')
              ? 31.778
              : 'legacy',
      });
      const channel = MethodChannel('flutter_timezone');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => 'Asia/Jerusalem',
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final reading = await const PlatformCreatingDeviceSettingsSource().read();
      expect(reading.timeZone, 'Asia/Jerusalem');
      expect(reading.latitude, isNull);
      expect(reading.longitude, isNull);
      expect(reading.inIsrael, isFalse);
      expect(reading.seedFor(profileUlid).hasLocation, isFalse);
    });
  });
}
