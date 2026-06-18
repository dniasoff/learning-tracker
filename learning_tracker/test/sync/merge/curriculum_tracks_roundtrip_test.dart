/// Round-trip test: the canonical write serializer (TrackCodec.encode) must
/// produce a payload that TrackConfigMerger accepts and persists.
///
/// This test guards the Phase B invariant for curriculum_tracks: if encode()
/// ever drifts from the key names _upsertTrack reads (e.g. curriculum_id →
/// wrong key), the track row is silently skipped on pull and cross-device
/// sync breaks without any error or log line the caller can see.
///
/// Before Phase B, encode() did NOT emit profile_id or track_id — those were
/// injected only by the hand-built push maps in the three live writers
/// (track_repository_impl, curriculum_activation_service,
/// local_data_upload_service). After Phase B all three route through
/// TrackCodec().encode(), making this the single authoritative write shape.
///
/// LWW key for curriculum_tracks is state_changed_at.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _codec = TrackCodec();

/// Profile id used throughout this test suite — must match the row seeded
/// by [seedProfile] (auto-increment → 1).
const _profileId = 1;
const _curriculumId = 'bavli';

final _activatedAt = DateTime.utc(2026, 1, 1);
final _stateChangedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderStateChangedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);

/// Build a minimal [TrackRow] for the test curriculum.
TrackRow _row({
  int profileId = _profileId,
  int trackId = 1,
  String curriculumId = _curriculumId,
  String state = 'active',
  DateTime? stateChangedAt,
  DateTime? paceResetDate,
}) => TrackRow(
  profileId: profileId,
  trackId: trackId,
  curriculumId: curriculumId,
  state: state,
  activatedAt: _activatedAt,
  stateChangedAt: stateChangedAt ?? _stateChangedAt,
  paceResetDate: paceResetDate,
);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('curriculum_tracks — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late TrackConfigMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = TrackConfigMerger(store: store);

      // Seed account + profile so FK constraints on curriculum_tracks hold.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as the
        // three live writers now do after Phase B.
        final payload = _codec.encode(_row());

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the track row materialised in the DB — not skipped.
        final track =
            await (db.select(db.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId),
                ))
                .getSingleOrNull();

        expect(
          track,
          isNotNull,
          reason:
              'TrackConfigMerger must INSERT the row when codec.encode() payload '
              'is fed in — if null the merge read-keys diverge from the codec '
              'write-keys (the push↔merge key-contract bug).',
        );
        expect(track!.curriculumId, _curriculumId);
        expect(track.state, 'active');
        expect(
          track.stateChangedAt.toUtc(),
          _stateChangedAt,
          reason: 'state_changed_at must round-trip through the codec',
        );
        expect(
          track.activatedAt.toUtc(),
          _activatedAt,
          reason: 'activated_at must round-trip through the codec',
        );
      },
    );

    test(
      'state_changed_at is persisted as LWW timestamp after merge',
      () async {
        await merger.merge(
          profileId: _profileId,
          rows: [_codec.encode(_row())],
        );

        final persisted = await store.currentUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: _profileId,
          naturalKey: _curriculumId,
        );
        expect(
          persisted,
          _stateChangedAt,
          reason:
              'persistUpdatedAt must record state_changed_at so subsequent '
              'pulls arbitrate LWW symmetrically',
        );
      },
    );

    test(
      'a second merge with an older state_changed_at is skipped (LWW wins local)',
      () async {
        // First: merge a newer row with state='active'.
        await merger.merge(
          profileId: _profileId,
          rows: [_codec.encode(_row(state: 'active'))],
        );

        // Then: try to merge an older row with state='retired' — must be ignored.
        await merger.merge(
          profileId: _profileId,
          rows: [
            _codec.encode(
              _row(state: 'retired', stateChangedAt: _olderStateChangedAt),
            ),
          ],
        );

        final track =
            await (db.select(db.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId),
                ))
                .getSingleOrNull();

        expect(
          track?.state,
          'active',
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'state should remain "active" after the stale merge',
        );
      },
    );

    test('optional pace_reset_date round-trips correctly', () async {
      final paceReset = DateTime.utc(2026, 3, 15);
      final payload = _codec.encode(_row(paceResetDate: paceReset));

      await merger.merge(profileId: _profileId, rows: [payload]);

      final track =
          await (db.select(db.curriculumTracks)..where(
                (t) =>
                    t.profileId.equals(_profileId) &
                    t.curriculumId.equals(_curriculumId),
              ))
              .getSingleOrNull();

      expect(
        track?.paceResetDate?.toUtc(),
        paceReset,
        reason: 'pace_reset_date is optional but must round-trip when present',
      );
    });

    test(
      'encode() emits profile_id and track_id (Phase B canonical fields)',
      () {
        final payload = _codec.encode(_row(profileId: 7, trackId: 42));

        expect(
          payload['profile_id'],
          7,
          reason:
              'Phase B: encode() must emit profile_id so live writers '
              'no longer need to inject it separately',
        );
        expect(
          payload['track_id'],
          42,
          reason:
              'Phase B: encode() must emit track_id so live writers '
              'no longer need to inject it separately',
        );
      },
    );
  });
}
