/// Acceptance test for Plan §F Phase 5 deliverable 7 — sacred-time prefs
/// ride along on every profile's UI-prefs snapshot, not just profile 0.
///
/// Sacred-time (lat/lon/in-Israel/country/city) is *device*-level — it
/// describes where the device is, not which learner is signed in — so the
/// snapshot for every profile must include the block. Previously gated on
/// `profileId == 0`, which silently dropped sacred-time for every adult
/// secondary profile on a multi-profile install.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart' show seedProfile;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'sacred_time_latitude': 31.7683,
      'sacred_time_longitude': 35.2137,
      'sacred_time_country_code': 'IL',
      'sacred_time_city_label': 'Jerusalem',
      'sacred_time_source': 'manual',
      'sacred_time_fixed_at_ms': 1716_900_000_000,
      'sacred_time_in_israel': true,
    });
  });

  group(
    'Plan §F Phase 5 deliverable 7 — sacred-time prefs sync for all profiles',
    () {
      test(
        'pushUiPreferencesSnapshot for profileId != 0 includes the '
        'sacred_time block (was previously dropped — multi-profile gap)',
        () async {
          final database = UserDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          await seedProfile(database);

          // profileId = 42 — well outside the "profile 0" sentinel that the
          // old code gated on.
          const profileId = 42;
          final facade = OutboxSyncWriteFacade(
            outboxDao: database.outboxDao,
            database: database,
            profileId: profileId,
            clock: const SystemLocalDayClock(),
          );

          await facade.pushUiPreferencesSnapshot();

          final rows = await database.select(database.outbox).get();
          final uiRows = rows
              .where((r) => r.entityKind == OutboxEntityKind.uiPreferences)
              .toList();
          expect(uiRows, hasLength(1));

          final payload =
              jsonDecode(uiRows.single.payload) as Map<String, dynamic>;
          expect(payload['profile_id'], profileId);

          final sacredTime = payload['sacred_time'];
          expect(
            sacredTime,
            isA<Map<String, dynamic>>(),
            reason:
                'sacred_time MUST be present for every profile, not '
                'just profile 0',
          );
          final block = sacredTime as Map<String, dynamic>;
          expect(block['latitude'], closeTo(31.7683, 0.0001));
          expect(block['longitude'], closeTo(35.2137, 0.0001));
          expect(block['country_code'], 'IL');
          expect(block['city_label'], 'Jerusalem');
          expect(block['in_israel'], true);
        },
      );

      test(
        'profileId == 0 still includes sacred_time (no regression)',
        () async {
          final database = UserDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          await seedProfile(database);

          final facade = OutboxSyncWriteFacade(
            outboxDao: database.outboxDao,
            database: database,
            profileId: 0,
            clock: const SystemLocalDayClock(),
          );

          await facade.pushUiPreferencesSnapshot();

          final rows = await database.select(database.outbox).get();
          final uiRows = rows
              .where((r) => r.entityKind == OutboxEntityKind.uiPreferences)
              .toList();
          expect(uiRows, hasLength(1));

          final payload =
              jsonDecode(uiRows.single.payload) as Map<String, dynamic>;
          expect(payload['sacred_time'], isA<Map<String, dynamic>>());
          expect((payload['sacred_time'] as Map)['in_israel'], true);
        },
      );
    },
  );
}
