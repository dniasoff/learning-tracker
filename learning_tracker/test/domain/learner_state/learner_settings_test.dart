/// Unit tests for [LearnerSettings].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
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
}
