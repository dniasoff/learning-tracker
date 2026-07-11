/// Round-trip test: the canonical write serializer (CompletionEventCodec.encode)
/// must produce a payload that CompletionEventMerger accepts and persists.
///
/// This test guards the Phase B invariant for completions: if encode() ever
/// drifts from the key names DriftMergeStore._insertCompletionIfAbsent reads
/// (e.g. completed_at → wrong key, or curriculum_id absent), the completion
/// row is silently skipped on pull, and cross-device replication breaks without
/// any error or log line the caller can observe.
///
/// Before Phase B, CompletionWriter._outboxPayload was a separate hand-built
/// map that included `profile_id` and `track_id` but the codec did not. After
/// Phase B all writes go through CompletionEventCodec.encode(), unifying the
/// push shape with what the merger and codec expect.
///
/// Fields verified:
///   * profile_id    — injected by codec; merge uses injected profileId param
///   * curriculum_id — primary natural-key field
///   * sefaria_ref   — part of natural key
///   * stage_id      — part of natural key
///   * track_type    — part of natural key
///   * track_id      — optional; persisted when present, null when absent
///   * completed_at  — maps to eventTimestamp; required field
///   * points        — persisted as-is
///   * prior_mark_only — conditional; only emitted when true
///
/// AG-5 (AUD-app-05): relocated from
/// test/sync/merge/completions_roundtrip_test.dart to its mirrored path.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/completion_event_codec.dart';
import 'package:learning_tracker/core/sync/merge/completion_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

const _codec = CompletionEventCodec();

/// Profile id produced by [seedProfile] (auto-increment → 1).
const _profileId = 1;
const _curriculumId = 'bavli';
const _sefariaRef = 'Berakhot 2a';
const _stageId = 1;
const _trackType = 'standard';
final _completedAt = DateTime.utc(2026, 6, 18, 12, 0, 0);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('completions — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late CompletionEventMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = CompletionEventMerger(store: store);

      // Seed account + profile so FK constraints on completion_events hold.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        final row = CompletionEventRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          sefariaRef: _sefariaRef,
          stageId: _stageId,
          trackType: _trackType,
          eventTimestamp: _completedAt,
          points: 10,
        );
        final payload = _codec.encode(row);

        // Verify the payload has the expected canonical keys (Phase B shape).
        expect(payload['profile_id'], _profileId);
        expect(payload['curriculum_id'], _curriculumId);
        expect(payload['sefaria_ref'], _sefariaRef);
        expect(payload['stage_id'], _stageId);
        expect(payload['track_type'], _trackType);
        expect(payload.containsKey('completed_at'), isTrue);
        expect(payload['points'], 10);
        // track_id is absent when null (conditional key).
        expect(payload.containsKey('track_id'), isFalse);

        // The merger must accept the codec payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final events = await db.completionEventDao.getEventsByProfile(
          _profileId,
        );

        expect(
          events,
          hasLength(1),
          reason:
              'CompletionEventMerger must INSERT the row when codec.encode() '
              'payload is fed in — if empty, the merge read-keys diverge from '
              'the codec write-keys (push↔merge key-contract bug). '
              'Most likely cause: merger reads "completed_at" but codec emits '
              'a different key, causing the null-guard to discard the row.',
        );

        final stored = events.first;
        expect(stored.profileId, _profileId);
        expect(stored.curriculumId, _curriculumId);
        expect(stored.sefariaRef, _sefariaRef);
        expect(stored.stageId, _stageId);
        expect(stored.trackType, _trackType);
        expect(stored.points, 10);
        expect(stored.trackId, isNull, reason: 'no track_id was supplied');

        final storedUtc = stored.eventTimestamp.toUtc();
        expect(storedUtc.year, _completedAt.year);
        expect(storedUtc.month, _completedAt.month);
        expect(storedUtc.day, _completedAt.day);
      },
    );

    test('track_id round-trips when supplied', () async {
      // Seed a curriculum_tracks row so the FK on track_id can be satisfied.
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: _curriculumId,
              stateChangedAt: _completedAt,
              activatedAt: _completedAt,
            ),
          );

      final payload = _codec.encode(
        CompletionEventRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          sefariaRef: _sefariaRef,
          stageId: _stageId,
          trackType: _trackType,
          trackId: trackId,
          eventTimestamp: _completedAt,
          points: 5,
        ),
      );

      expect(
        payload['track_id'],
        trackId,
        reason:
            'Phase B: encode() must include track_id when non-null so the '
            'completions_view can serve track-scoped queries on the receiving '
            'device.',
      );

      await merger.merge(profileId: _profileId, rows: [payload]);

      final events = await db.completionEventDao.getEventsByProfile(_profileId);
      expect(events, hasLength(1));
      expect(
        events.first.trackId,
        trackId,
        reason: 'track_id must be persisted by the merger from the payload',
      );
    });

    test(
      'prior_mark_only is emitted only when true and does not break merge',
      () async {
        final payload = _codec.encode(
          CompletionEventRow(
            profileId: _profileId,
            curriculumId: _curriculumId,
            sefariaRef: _sefariaRef,
            stageId: _stageId,
            trackType: _trackType,
            eventTimestamp: _completedAt,
            points: 0,
            priorMarkOnly: true,
          ),
        );

        expect(
          payload['prior_mark_only'],
          true,
          reason:
              'encode() must emit prior_mark_only:true when the flag is set '
              'so tutor bulk-prior CF writes can carry this field.',
        );

        // Merger must not be confused by the extra prior_mark_only field.
        await merger.merge(profileId: _profileId, rows: [payload]);

        final events = await db.completionEventDao.getEventsByProfile(
          _profileId,
        );
        expect(
          events,
          hasLength(1),
          reason:
              'prior_mark_only in the payload must not cause the row to be '
              'skipped — the merger ignores unknown fields.',
        );
      },
    );

    test(
      'dedup: two merges of the same codec payload produce exactly one DB row',
      () async {
        final payload = _codec.encode(
          CompletionEventRow(
            profileId: _profileId,
            curriculumId: _curriculumId,
            sefariaRef: _sefariaRef,
            stageId: _stageId,
            trackType: _trackType,
            eventTimestamp: _completedAt,
            points: 10,
          ),
        );

        // Simulate an outbox retry: merge the same payload twice.
        await merger.merge(profileId: _profileId, rows: [payload]);
        await merger.merge(profileId: _profileId, rows: [payload]);

        final events = await db.completionEventDao.getEventsByProfile(
          _profileId,
        );
        expect(
          events,
          hasLength(1),
          reason:
              'completion_events has a UNIQUE natural-key index; a duplicate '
              'push (outbox retry) must be silently collapsed to one row.',
        );
      },
    );

    test(
      'prior_mark_only is absent from encode() output when false (default)',
      () {
        final payload = _codec.encode(
          CompletionEventRow(
            profileId: _profileId,
            curriculumId: _curriculumId,
            sefariaRef: _sefariaRef,
            stageId: _stageId,
            trackType: _trackType,
            eventTimestamp: _completedAt,
            points: 0,
            // priorMarkOnly defaults to false
          ),
        );

        expect(
          payload.containsKey('prior_mark_only'),
          isFalse,
          reason:
              'prior_mark_only must be omitted from the payload when false '
              'so live-completion documents remain clean.',
        );
      },
    );

    test(
      'encode() emits profile_id and curriculum_id (required push fields)',
      () {
        final payload = _codec.encode(
          CompletionEventRow(
            profileId: 42,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 1:1',
            stageId: 2,
            trackType: 'chazara',
            eventTimestamp: _completedAt,
            points: 3,
          ),
        );

        expect(
          payload['profile_id'],
          42,
          reason:
              'Phase B: encode() must emit profile_id so the gateway and '
              'Firestore receive the owner profile scope.',
        );
        expect(payload['curriculum_id'], 'mishnayos');
        expect(payload['sefaria_ref'], 'Berakhot 1:1');
        expect(payload['stage_id'], 2);
        expect(payload['track_type'], 'chazara');
        expect(payload['points'], 3);
      },
    );
  });
}
