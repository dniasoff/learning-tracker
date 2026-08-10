/// WS6 — Location Device-Scope Consistency (DEC-26)
///
/// Guards the fix that moves sacred-time / location out of the per-profile
/// ui_preferences merger and into device-global SharedPreferences only.
///
/// **The defect (pre-fix):** location rode each profile's Firestore
/// ui_preferences doc with LWW across profiles.  Syncing a second profile
/// clobbered the device-global location — even though SacredTimePreferences
/// already uses device-global keys locally.
///
/// **The fix:** sacred_time is stripped from pushUiPreferencesSnapshot()
/// and ignored by UiPreferencesMerger.  One device = one location, never
/// overwritten by another profile's sync.
///
/// **Tests in this file:**
///   1. pushUiPreferencesSnapshot no longer embeds sacred_time.
///   2. Merger round-trip: two profiles push location data → pull + merge →
///      device-level location is the locally-set value, unchanged.
///   3. Merger ignores a sacred_time block in legacy Firestore documents.
///   4. Non-location prefs (locale, hebrew-calendar) are still merged correctly.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/ui_preferences_merger.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_database.dart' show seedProfile;

/// Device-global SharedPreferences keys used by SacredTimePreferences.
const _latKey = 'sacred_time_latitude';
const _lonKey = 'sacred_time_longitude';
const _countryKey = 'sacred_time_country_code';
const _cityKey = 'sacred_time_city_label';
const _sourceKey = 'sacred_time_source';
const _fixedAtKey = 'sacred_time_fixed_at_ms';
const _inIsraelKey = 'sacred_time_in_israel';

/// Jerusalem coordinates set locally on the device.
const _localLat = 31.7683;
const _localLon = 35.2137;
const _localCountry = 'IL';
const _localCity = 'Jerusalem';
const _localSource = 'manual';
const _localFixedAt = 1_716_900_000_000;
const _localInIsrael = true;

void main() {
  group('WS6 — Location Device-Scope Consistency (DEC-26)', () {
    // ── Test 1: push snapshot does NOT embed sacred_time ──────────────────────

    group('pushUiPreferencesSnapshot — no sacred_time in outbox payload', () {
      test('payload contains no sacred_time key after DEC-26 fix', () async {
        SharedPreferences.setMockInitialValues({
          _latKey: _localLat,
          _lonKey: _localLon,
          _countryKey: _localCountry,
          _cityKey: _localCity,
          _sourceKey: _localSource,
          _fixedAtKey: _localFixedAt,
          _inIsraelKey: _localInIsrael,
        });

        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedProfile(db);

        const profileId = 1;
        final facade = OutboxSyncWriteFacade(
          outboxDao: db.outboxDao,
          database: db,
          resolveProfileId: () => profileId,
          clock: const SystemLocalDayClock(),
        );

        await facade.pushUiPreferencesSnapshot();

        final rows = await db.select(db.outbox).get();
        final uiRows = rows
            .where((r) => r.entityKind == OutboxEntityKind.uiPreferences)
            .toList();
        expect(uiRows, hasLength(1), reason: 'exactly one ui_preferences row');

        final payload =
            jsonDecode(uiRows.single.payload) as Map<String, dynamic>;
        expect(
          payload.containsKey('sacred_time'),
          isFalse,
          reason:
              'sacred_time MUST NOT be present in per-profile ui_preferences '
              'push payload (DEC-26: location is device-scoped)',
        );
      });

      test(
        'payload still contains per-profile fields (locale, hebrew-calendar)',
        () async {
          SharedPreferences.setMockInitialValues({
            _latKey: _localLat,
            _lonKey: _localLon,
            _inIsraelKey: _localInIsrael,
          });

          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          await seedProfile(db);

          const profileId = 1;
          final facade = OutboxSyncWriteFacade(
            outboxDao: db.outboxDao,
            database: db,
            resolveProfileId: () => profileId,
            clock: const SystemLocalDayClock(),
          );

          await facade.pushUiPreferencesSnapshot();

          final rows = await db.select(db.outbox).get();
          final uiRows = rows
              .where((r) => r.entityKind == OutboxEntityKind.uiPreferences)
              .toList();
          expect(uiRows, hasLength(1));

          final payload =
              jsonDecode(uiRows.single.payload) as Map<String, dynamic>;
          // Per-profile prefs are still present.
          expect(
            payload.containsKey('app_locale'),
            isTrue,
            reason: 'app_locale must remain in ui_preferences payload',
          );
          expect(
            payload.containsKey('use_hebrew_calendar'),
            isTrue,
            reason: 'use_hebrew_calendar must remain in ui_preferences payload',
          );
        },
      );
    });

    // ── Test 2: Merger round-trip — two profiles push, device location intact ─

    group(
      'Merger round-trip — two profiles push location → merge → device unchanged',
      () {
        /// The core WS6 acceptance test:
        ///   Profile A sets location to Jerusalem.
        ///   Profile A pushes (no sacred_time in payload — DEC-26 fix).
        ///   Profile B pushes different location in a legacy-style payload.
        ///   Both payloads are pulled and merged.
        ///   Device location remains the locally-set Jerusalem value —
        ///   not clobbered by either profile's sync.
        test(
          'device location is not clobbered after two profiles push and merge',
          () async {
            // Arrange: device has Jerusalem set locally.
            SharedPreferences.setMockInitialValues({
              _latKey: _localLat,
              _lonKey: _localLon,
              _countryKey: _localCountry,
              _cityKey: _localCity,
              _inIsraelKey: _localInIsrael,
            });

            final db = UserDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            await seedProfile(db);
            final store = DriftMergeStore(db);
            final merger = UiPreferencesMerger(store: store);

            final t1 = DateTime.utc(2026, 5, 24, 10, 0);
            final t2 = DateTime.utc(2026, 5, 24, 11, 0); // newer

            // Simulate Profile A's ui_preferences Firestore doc.
            // Even if an older build included sacred_time in profile A's doc,
            // the merger must now ignore it.
            final profileADoc = <String, dynamic>{
              'updated_at': t1.toIso8601String(),
              'app_locale': 'en',
              'sacred_time': {
                // legacy data from profile A — should be ignored
                'latitude': 40.7128, // New York
                'longitude': -74.0060,
                'country_code': 'US',
                'city_label': 'New York',
                'in_israel': false,
              },
            };

            // Simulate Profile B's ui_preferences Firestore doc (newer).
            final profileBDoc = <String, dynamic>{
              'updated_at': t2.toIso8601String(),
              'app_locale': 'he',
              'sacred_time': {
                // legacy data from profile B — should also be ignored
                'latitude': 51.5074, // London
                'longitude': -0.1278,
                'country_code': 'GB',
                'city_label': 'London',
                'in_israel': false,
              },
            };

            // Act: merge both profiles' docs.
            await merger.merge(profileId: 1, rows: [profileADoc]);
            await merger.merge(profileId: 2, rows: [profileBDoc]);

            // Assert: device-level SharedPreferences still hold Jerusalem.
            final prefs = await SharedPreferences.getInstance();
            expect(
              prefs.getDouble(_latKey),
              closeTo(_localLat, 0.0001),
              reason:
                  'latitude must remain Jerusalem after two profile merges '
                  '(DEC-26: location is device-scoped, merger must not write it)',
            );
            expect(
              prefs.getDouble(_lonKey),
              closeTo(_localLon, 0.0001),
              reason: 'longitude must remain Jerusalem',
            );
            expect(
              prefs.getString(_countryKey),
              equals(_localCountry),
              reason: 'country_code must remain IL',
            );
            expect(
              prefs.getString(_cityKey),
              equals(_localCity),
              reason: 'city_label must remain Jerusalem',
            );
            expect(
              prefs.getBool(_inIsraelKey),
              isTrue,
              reason: 'in_israel must remain true',
            );
          },
        );

        test(
          'merger with no locally-set location does not write sacred_time keys',
          () async {
            // Device has no location set at all.
            SharedPreferences.setMockInitialValues({});

            final db = UserDatabase(NativeDatabase.memory());
            addTearDown(db.close);
            await seedProfile(db);
            final store = DriftMergeStore(db);
            final merger = UiPreferencesMerger(store: store);

            final t = DateTime.utc(2026, 5, 24, 10, 0);
            final doc = <String, dynamic>{
              'updated_at': t.toIso8601String(),
              'app_locale': 'en',
              'sacred_time': {
                'latitude': 40.7128,
                'longitude': -74.0060,
                'in_israel': false,
              },
            };

            await merger.merge(profileId: 1, rows: [doc]);

            final prefs = await SharedPreferences.getInstance();
            expect(
              prefs.getDouble(_latKey),
              isNull,
              reason:
                  'merger must not write latitude even if sacred_time is in '
                  'the Firestore doc — device location is set only locally',
            );
            expect(
              prefs.getDouble(_lonKey),
              isNull,
              reason: 'merger must not write longitude',
            );
          },
        );
      },
    );

    // ── Test 3: legacy sacred_time block is silently ignored ──────────────────

    group('Merger ignores legacy sacred_time block', () {
      test(
        'sacred_time key in incoming row does not modify SharedPreferences',
        () async {
          SharedPreferences.setMockInitialValues({
            _latKey: _localLat,
            _lonKey: _localLon,
            _inIsraelKey: _localInIsrael,
          });

          final db = UserDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          await seedProfile(db);
          final store = DriftMergeStore(db);
          final merger = UiPreferencesMerger(store: store);

          final doc = <String, dynamic>{
            'updated_at': DateTime.utc(2026, 5, 24, 12).toIso8601String(),
            'app_locale': 'he',
            'sacred_time': {
              // Attacker / stale data — must be ignored.
              'latitude': 0.0,
              'longitude': 0.0,
              'country_code': 'XX',
              'city_label': 'Nowhere',
              'in_israel': false,
            },
          };

          await merger.merge(profileId: 1, rows: [doc]);

          final prefs = await SharedPreferences.getInstance();
          expect(
            prefs.getDouble(_latKey),
            closeTo(_localLat, 0.0001),
            reason: 'latitude must be untouched by legacy sacred_time block',
          );
          expect(
            prefs.getDouble(_lonKey),
            closeTo(_localLon, 0.0001),
            reason: 'longitude must be untouched',
          );
          expect(
            prefs.getBool(_inIsraelKey),
            isTrue,
            reason: 'in_israel flag must be untouched',
          );
        },
      );
    });

    // ── Test 4: per-profile prefs still merge correctly ────────────────────────

    group('Per-profile prefs are still merged correctly', () {
      test('app_locale is applied to the correct profile key', () async {
        SharedPreferences.setMockInitialValues({});

        final db = UserDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedProfile(db);
        final store = DriftMergeStore(db);
        final merger = UiPreferencesMerger(store: store);

        const profileId = 1;
        final doc = <String, dynamic>{
          'updated_at': DateTime.utc(2026, 5, 24, 9).toIso8601String(),
          'app_locale': 'he',
          'use_hebrew_calendar': true,
        };

        await merger.merge(profileId: profileId, rows: [doc]);

        final prefs = await SharedPreferences.getInstance();
        // The merger writes per-profile keys using ProfileScopedPreferenceKeys.
        // We verify the effect by checking that at least one pref was updated.
        // (ProfileScopedPreferenceKeys.appLocale returns a key with profileId
        //  suffix — verifying the key format is an implementation detail.)
        const localeKey = 'app_locale_p$profileId';
        expect(
          prefs.getString(localeKey),
          equals('he'),
          reason: 'app_locale must be applied per-profile',
        );

        const hebrewCalKey = 'use_hebrew_calendar_p$profileId';
        expect(
          prefs.getBool(hebrewCalKey),
          isTrue,
          reason: 'use_hebrew_calendar must be applied per-profile',
        );
      });
    });
  });
}
