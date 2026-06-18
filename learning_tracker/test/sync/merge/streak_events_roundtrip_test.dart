/// Round-trip test: the canonical write serializer (StreakEventCodec.encode)
/// must produce a payload that StreakEventMerger accepts and persists.
///
/// This test guards the Phase B invariant for streak_events: if encode()
/// ever drifts from the key names StreakEventMerger reads (e.g. study_date →
/// wrong key), the streak event is silently skipped on pull and streak data
/// is lost on new-device / device-restore scenarios without any error.
///
/// Key fields verified:
///   * profile_id   — decoded via FirestoreCodec.parseInt
///   * event_type   — decoded as String
///   * study_date   — decoded as DateTime (the W3.37 canonical field name)
///   * created_at   — decoded as DateTime
///   * ulid         — carried through encode/decode; used by gateway as doc-id
///
/// The test also verifies dedup: two merges of the same payload produce one
/// row (UNIQUE composite `(profileId, dayUtc, eventType)` on streak_events).
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/streak_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/streak_event_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _codec = StreakEventCodec();

const _profileId = 1;
final _studyDate = DateTime.utc(2026, 6, 18);
final _createdAt = DateTime.utc(2026, 6, 18, 14, 30, 0);
const _eventType = 'completion';
const _ulid = '01JBVZ0000TESTULID000000AB';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
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
          profileId: _profileId,
          eventType: _eventType,
          studyDate: _studyDate,
          createdAt: _createdAt,
          ulid: _ulid,
        );
        final payload = _codec.encode(row);

        // Verify the payload has the expected keys (Phase B canonical shape).
        expect(payload['profile_id'], _profileId);
        expect(payload['event_type'], _eventType);
        expect(payload.containsKey('study_date'), isTrue);
        expect(payload.containsKey('created_at'), isTrue);
        expect(payload['ulid'], _ulid);

        // The merger must accept the codec payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final events = await db.streakEventDao.getEventsByProfile(_profileId);

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
        expect(stored.eventType, _eventType);

        // Merger maps study_date → eventTimestamp; compare date components to
        // avoid local-vs-UTC drift in test environments.
        final storedUtc = stored.eventTimestamp.toUtc();
        expect(storedUtc.year, _studyDate.year);
        expect(storedUtc.month, _studyDate.month);
        expect(storedUtc.day, _studyDate.day);
      },
    );

    test(
      'dedup: two merges of the same codec payload produce exactly one DB row',
      () async {
        final payload = _codec.encode(
          StreakEventRow(
            profileId: _profileId,
            eventType: _eventType,
            studyDate: _studyDate,
            createdAt: _createdAt,
            ulid: _ulid,
          ),
        );

        // Simulate an outbox retry: merge the same payload twice.
        await merger.merge(profileId: _profileId, rows: [payload]);
        await merger.merge(profileId: _profileId, rows: [payload]);

        final events = await db.streakEventDao.getEventsByProfile(_profileId);
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
        profileId: _profileId,
        eventType: _eventType,
        studyDate: _studyDate,
        createdAt: _createdAt,
        ulid: _ulid,
      );
      final payload = _codec.encode(row);

      expect(
        payload['ulid'],
        _ulid,
        reason:
            'Phase B: encode() must include the ulid so the gateway can use '
            'it as the Firestore document-id (streak_events/{ulid}) and '
            'idempotent outbox retries overwrite the same document.',
      );

      final decoded = _codec.decode(payload);
      expect(decoded, isNotNull);
      expect(
        decoded!.ulid,
        _ulid,
        reason: 'ulid must survive a decode() round-trip',
      );
    });

    test('encode() without ulid omits the ulid key (optional field)', () {
      final row = StreakEventRow(
        profileId: _profileId,
        eventType: _eventType,
        studyDate: _studyDate,
        createdAt: _createdAt,
        // no ulid
      );
      final payload = _codec.encode(row);

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
