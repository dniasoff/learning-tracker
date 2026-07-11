/// Regression tests for [StreakEventMerger].
///
/// C2 regression (V3-W1): merger was reading `event_timestamp` while
/// W3.37 renamed the Firestore field to `study_date`. Every pulled row
/// would fail the null-guard (`ts == null`) and be silently discarded,
/// causing complete streak data loss on new-device / device-restore scenarios.
///
/// C3 regression (V3-W1): verifies the channel name used in
/// [FirestoreListenerSource] now matches the `streak_events` collection
/// (the old `streak/data` document listener path is dead after W3.37).
///
/// AG-5 (AUD-app-05): also folds in
/// test/sync/merge/streak_events_roundtrip_test.dart's codec.encode() ->
/// merger -> DB round-trip group (Phase B invariant).
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/streak_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/streak_event_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

// ── codec.encode() → merger → DB round-trip fixtures ─────────────────────────
const _rtCodec = StreakEventCodec();
const _rtProfileId = 1;
final _rtStudyDate = DateTime.utc(2026, 6, 18);
final _rtCreatedAt = DateTime.utc(2026, 6, 18, 14, 30, 0);
const _rtEventType = 'completion';
const _rtUlid = '01JBVZ0000TESTULID000000AB';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('StreakEventMerger', () {
    test(
      'C2 regression: W3.37 shape (study_date) is inserted into Drift',
      () async {
        // GIVEN an in-memory DB with a seeded learner profile.
        final db = createTestDatabase();
        await seedProfile(db);
        final profiles = await db.select(db.learnerProfiles).get();
        final profileId = profiles.first.id;

        final merger = StreakEventMerger(db);
        final studyDate = DateTime.utc(2026, 3, 20);

        // WHEN a W3.37-shape row (study_date, no event_timestamp) is merged.
        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'profile_id': profileId,
              'event_type': 'completion',
              'study_date': studyDate.toIso8601String(),
              'created_at': studyDate.toIso8601String(),
            },
          ],
        );

        // THEN the event lands in Drift.
        final events = await db.streakEventDao.getEventsByProfile(profileId);
        expect(events, hasLength(1));
        expect(events.first.eventType, 'completion');
        // eventTimestamp is set to study_date by the merger. Compare year/month/day
        // rather than full timestamp to avoid local-vs-UTC drift in tests.
        final stored = events.first.eventTimestamp.toUtc();
        expect(stored.year, studyDate.year);
        expect(stored.month, studyDate.month);
        expect(stored.day, studyDate.day);

        await db.close();
      },
    );

    test(
      'C2 regression: legacy event_timestamp shape is still accepted',
      () async {
        // Ensure any pre-W3.37 rows still in Firestore are ingested.
        final db = createTestDatabase();
        await seedProfile(db);
        final profiles = await db.select(db.learnerProfiles).get();
        final profileId = profiles.first.id;

        final merger = StreakEventMerger(db);
        final ts = DateTime.utc(2025, 12, 1);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'event_type': 'completion',
              'event_timestamp': ts.toIso8601String(),
            },
          ],
        );

        final events = await db.streakEventDao.getEventsByProfile(profileId);
        expect(events, hasLength(1));
        expect(events.first.eventType, 'completion');
        // Compare date components to avoid local-vs-UTC drift in test environments.
        final stored = events.first.eventTimestamp.toUtc();
        expect(stored.year, ts.year);
        expect(stored.month, ts.month);
        expect(stored.day, ts.day);

        await db.close();
      },
    );

    test(
      'C2 regression: row missing both study_date and event_timestamp is skipped',
      () async {
        final db = createTestDatabase();
        await seedProfile(db);
        final profiles = await db.select(db.learnerProfiles).get();
        final profileId = profiles.first.id;

        final merger = StreakEventMerger(db);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'event_type': 'completion',
              // no study_date, no event_timestamp → should skip gracefully
            },
          ],
        );

        final events = await db.streakEventDao.getEventsByProfile(profileId);
        expect(events, isEmpty);

        await db.close();
      },
    );

    test('dedup: same study_date + event_type is idempotent', () async {
      final db = createTestDatabase();
      await seedProfile(db);
      final profiles = await db.select(db.learnerProfiles).get();
      final profileId = profiles.first.id;

      final merger = StreakEventMerger(db);
      final studyDate = DateTime.utc(2026, 5, 1);
      final row = {
        'profile_id': profileId,
        'event_type': 'completion',
        'study_date': studyDate.toIso8601String(),
        'created_at': studyDate.toIso8601String(),
      };

      await merger.merge(profileId: profileId, rows: [row]);
      await merger.merge(profileId: profileId, rows: [row]); // second pull

      final events = await db.streakEventDao.getEventsByProfile(profileId);
      expect(events, hasLength(1)); // dedup by (profileId, dayUtc, eventType)

      await db.close();
    });
  });

  group('streak_events — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late StreakEventMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      merger = StreakEventMerger(db);

      // Seed account + profile so FK constraints on streak_events are met.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        final row = StreakEventRow(
          profileId: _rtProfileId,
          eventType: _rtEventType,
          studyDate: _rtStudyDate,
          createdAt: _rtCreatedAt,
          ulid: _rtUlid,
        );
        final payload = _rtCodec.encode(row);

        // Verify the payload has the expected keys (Phase B canonical shape).
        expect(payload['profile_id'], _rtProfileId);
        expect(payload['event_type'], _rtEventType);
        expect(payload.containsKey('study_date'), isTrue);
        expect(payload.containsKey('created_at'), isTrue);
        expect(payload['ulid'], _rtUlid);

        // The merger must accept the codec payload and write it to Drift.
        await merger.merge(profileId: _rtProfileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final events = await db.streakEventDao.getEventsByProfile(_rtProfileId);

        expect(
          events,
          hasLength(1),
          reason:
              'StreakEventMerger must INSERT the row when codec.encode() '
              'payload is fed in — if empty, the merge read-keys diverge from '
              'the codec write-keys (push↔merge key-contract bug). '
              'Most likely cause: merger reads "study_date" but codec emits a '
              'different key, causing the null-guard to discard the row.',
        );

        final stored = events.first;
        expect(stored.eventType, _rtEventType);

        // Merger maps study_date → eventTimestamp; compare date components to
        // avoid local-vs-UTC drift in test environments.
        final storedUtc = stored.eventTimestamp.toUtc();
        expect(storedUtc.year, _rtStudyDate.year);
        expect(storedUtc.month, _rtStudyDate.month);
        expect(storedUtc.day, _rtStudyDate.day);
      },
    );

    test(
      'dedup: two merges of the same codec payload produce exactly one DB row',
      () async {
        final payload = _rtCodec.encode(
          StreakEventRow(
            profileId: _rtProfileId,
            eventType: _rtEventType,
            studyDate: _rtStudyDate,
            createdAt: _rtCreatedAt,
            ulid: _rtUlid,
          ),
        );

        // Simulate an outbox retry: merge the same payload twice.
        await merger.merge(profileId: _rtProfileId, rows: [payload]);
        await merger.merge(profileId: _rtProfileId, rows: [payload]);

        final events = await db.streakEventDao.getEventsByProfile(_rtProfileId);
        expect(
          events,
          hasLength(1),
          reason:
              'streak_events has a UNIQUE (profileId, dayUtc, eventType) index; '
              'a duplicate push must be silently collapsed to one row.',
        );
      },
    );

    test('ulid round-trips through codec encode/decode', () {
      final row = StreakEventRow(
        profileId: _rtProfileId,
        eventType: _rtEventType,
        studyDate: _rtStudyDate,
        createdAt: _rtCreatedAt,
        ulid: _rtUlid,
      );
      final payload = _rtCodec.encode(row);

      expect(
        payload['ulid'],
        _rtUlid,
        reason:
            'Phase B: encode() must include the ulid so the gateway can use '
            'it as the Firestore document-id (streak_events/{ulid}) and '
            'idempotent outbox retries overwrite the same document.',
      );

      final decoded = _rtCodec.decode(payload);
      expect(decoded, isNotNull);
      expect(
        decoded!.ulid,
        _rtUlid,
        reason: 'ulid must survive a decode() round-trip',
      );
    });

    test('encode() without ulid omits the ulid key (optional field)', () {
      final row = StreakEventRow(
        profileId: _rtProfileId,
        eventType: _rtEventType,
        studyDate: _rtStudyDate,
        createdAt: _rtCreatedAt,
        // no ulid
      );
      final payload = _rtCodec.encode(row);

      expect(
        payload.containsKey('ulid'),
        isFalse,
        reason:
            'ulid is optional — encode() must omit the key when null so '
            'legacy payloads (pre-Phase B) without ulid are still valid.',
      );
    });
  });
}
