/// Unit tests for [LearnerSettings].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/shnayim_mikra_preferences.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  test('projects settings keys out of a profile doc', () {
    final settings = LearnerSettings.fromProfileDoc(profileUlid, {
      'display_name': 'Moshe',
      'time_zone': 'Etc/GMT+5',
      'latitude': 40,
      'longitude': -74,
      'in_israel': false,
    });
    expect(settings.latitude, 40.0);
    expect(settings.toStorage(), {
      'latitude': 40.0,
      'longitude': -74.0,
      'time_zone': 'Etc/GMT+5',
      'in_israel': false,
    });
  });

  test('time_zone is required and IANA-shaped', () {
    expect(
      () => LearnerSettings.fromProfileDoc(profileUlid, {'display_name': 'x'}),
      throwsA(isA<StorageFormatException>()),
    );
    for (final ok in ['UTC', 'Asia/Jerusalem', 'America/Argentina/Salta']) {
      expect(
        LearnerSettings(profileId: profileUlid, timeZone: ok).toStorage(),
        {'time_zone': ok},
      );
    }
    for (final bad in ['', 'Jerusalem', 'GMT+2', 'Asia/']) {
      expect(
        LearnerSettings(profileId: profileUlid, timeZone: bad).toStorage,
        throwsA(isA<StorageFormatException>()),
        reason: bad,
      );
    }
  });

  test('latitude/longitude set together and in range', () {
    for (final bad in [
      const LearnerSettings(
        profileId: profileUlid,
        timeZone: 'UTC',
        latitude: 1,
      ),
      const LearnerSettings(
        profileId: profileUlid,
        timeZone: 'UTC',
        latitude: 91,
        longitude: 0,
      ),
      const LearnerSettings(
        profileId: profileUlid,
        timeZone: 'UTC',
        latitude: 0,
        longitude: -181,
      ),
    ]) {
      expect(bad.toStorage, throwsA(isA<StorageFormatException>()));
    }
  });

  test('profile id must be a ULID; last_change_id too when present', () {
    expect(
      const LearnerSettings(profileId: 'p', timeZone: 'UTC').toStorage,
      throwsA(isA<StorageFormatException>()),
    );
    expect(
      () => LearnerSettings.fromProfileDoc(profileUlid, {
        'time_zone': 'UTC',
        'last_change_id': 'x',
      }),
      throwsA(isA<StorageFormatException>()),
    );
  });

  test('new Sacred Time settings round-trip with legacy defaults', () {
    final fixedAt = DateTime.utc(2026, 11, 6, 12);
    final configured = LearnerSettings(
      profileId: profileUlid,
      timeZone: 'Europe/London',
      latitude: 51.5074,
      longitude: -0.1278,
      tzeisMinhag: 'rabbeinu_tam',
      candleLightingMinutes: 30,
      locationSource: 'detected',
      locationFixedAt: fixedAt,
    );
    expect(
      LearnerSettings.fromProfileDoc(profileUlid, configured.toStorage()),
      configured,
    );
    final legacy = LearnerSettings.fromProfileDoc(profileUlid, {
      'time_zone': 'Europe/London',
    });
    expect(legacy.tzeisMinhag, LearnerSettings.defaultTzeisMinhag);
    expect(
      legacy.candleLightingMinutes,
      LearnerSettings.defaultCandleLightingMinutes,
    );
  });

  test(
    'Shnayim Mikra defaults preserve legacy documents and follow region',
    () {
      final legacyDiaspora = LearnerSettings.fromProfileDoc(profileUlid, {
        'time_zone': 'UTC',
      });
      expect(legacyDiaspora.shnayimMikraMode, ShnayimMikraMode.pasuk);
      expect(legacyDiaspora.shnayimMikraPace, ShnayimMikraPace.self);
      expect(legacyDiaspora.shnayimMikraSource, ShnayimMikraSource.onkelos);
      expect(legacyDiaspora.shnayimMikraInIsrael, isFalse);

      final israel = LearnerSettings.fromProfileDoc(profileUlid, {
        'time_zone': 'Asia/Jerusalem',
        'in_israel': true,
      });
      expect(israel.shnayimMikraInIsrael, isTrue);
    },
  );

  test('Shnayim Mikra settings round-trip and reject unknown enum values', () {
    const configured = LearnerSettings(
      profileId: profileUlid,
      timeZone: 'UTC',
      inIsrael: true,
      shnayimMikraMode: ShnayimMikraMode.parsha,
      shnayimMikraPace: ShnayimMikraPace.dailyAliyah,
      shnayimMikraSource: ShnayimMikraSource.rashi,
    );
    expect(configured.toStorage(), {
      'time_zone': 'UTC',
      'in_israel': true,
      'shnayim_mikra_mode': 'parsha',
      'shnayim_mikra_pace': 'daily_aliyah',
      'shnayim_mikra_source': 'rashi',
    });
    expect(
      LearnerSettings.fromProfileDoc(profileUlid, configured.toStorage()),
      configured,
    );

    for (final invalid in [
      {'time_zone': 'UTC', 'shnayim_mikra_mode': 'unknown'},
      {'time_zone': 'UTC', 'shnayim_mikra_pace': 'weekly'},
      {'time_zone': 'UTC', 'shnayim_mikra_source': 'targum'},
    ]) {
      expect(
        () => LearnerSettings.fromProfileDoc(profileUlid, invalid),
        throwsA(isA<StorageFormatException>()),
      );
    }
  });
}
