/// Regression tests for sacred-time / location scope in the UI-preferences
/// sync path.
///
/// **Pre-DEC-26 (Plan §F Phase 5 deliverable 7):** sacred-time rode every
/// profile's UI-prefs snapshot so that secondary adult profiles on
/// multi-profile devices didn't lose their sacred-window config across a
/// reinstall. The block was written per-profile into Firestore.
///
/// **DEC-26 (WS6):** location is Device-scoped. The sacred_time block MUST NOT
/// appear in the per-profile ui_preferences push payload. It is NOT a
/// regression for it to be absent — it is the correct fix. The device-global
/// SharedPreferences keys managed by SacredTimePreferences remain the
/// authoritative local store; the cloud no longer overrides them per-profile.
///
/// Tests in this file guard against re-introducing the sacred_time block
/// in the per-profile push payload (the old behavior = the clobber bug).
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
    'DEC-26 — sacred-time is NOT in per-profile ui_preferences push payload',
    () {
      test(
        'pushUiPreferencesSnapshot for profileId != 0 does NOT include '
        'sacred_time (DEC-26: location is device-scoped, not per-profile)',
        () async {
          final database = UserDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          await seedProfile(database);

          // profileId = 42 — well outside the "profile 0" sentinel.
          const profileId = 42;
          final facade = OutboxSyncWriteFacade(
            outboxDao: database.outboxDao,
            database: database,
            resolveProfileId: () => profileId,
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

          // DEC-26: sacred_time MUST NOT appear in the per-profile payload.
          // Its absence is correct — location is device-scoped and no longer
          // synced per-profile.
          expect(
            payload.containsKey('sacred_time'),
            isFalse,
            reason:
                'sacred_time MUST NOT be present in the per-profile '
                'ui_preferences payload (DEC-26: location is device-scoped, '
                'embedding it per-profile causes cross-profile LWW clobber)',
          );
        },
      );

      test(
        'profileId == 0 also does NOT include sacred_time (consistent with DEC-26)',
        () async {
          final database = UserDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          await seedProfile(database);

          final facade = OutboxSyncWriteFacade(
            outboxDao: database.outboxDao,
            database: database,
            resolveProfileId: () => 0,
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

          // DEC-26: sacred_time must not appear for any profile, including 0.
          expect(
            payload.containsKey('sacred_time'),
            isFalse,
            reason: 'sacred_time must not be in ui_preferences for any profile',
          );
        },
      );
    },
  );
}
