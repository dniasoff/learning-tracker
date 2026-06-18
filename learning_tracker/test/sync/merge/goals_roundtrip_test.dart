/// Round-trip test: the canonical write serializer (GoalCodec.encode) must
/// produce a payload that GoalMerger accepts and persists.
///
/// This test guards the Phase B invariant for goals: if encode() ever drifts
/// from the key names GoalMerger / GoalDao.upsertGoalByTrack reads (e.g.
/// track_id absent, pace_unit vs pace_period, missing target_percent), the
/// goal row is silently skipped on pull and cross-device sync breaks without
/// any error or log line the caller can observe.
///
/// Before Phase B, the live write path used GoalEntity.toFirestore() (a
/// separate, hand-built serializer) and LocalDataUploadService built its own
/// map without pace_granularity. After Phase B all writes go through
/// GoalCodec.encode(), making this the single authoritative write shape.
///
/// LWW key for goals is updated_at (arbitrated per remoteTrackId natural key).
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/goal_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/goal_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _codec = GoalCodec();

/// Profile id produced by [seedProfile] (auto-increment → 1).
const _profileId = 1;
const _curriculumId = 'bavli';

final _createdAt = DateTime.utc(2026, 1, 1);
final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);
final _targetDate = DateTime.utc(2026, 12, 31);

/// Seed a [curriculum_tracks] row and return its local id.
///
/// Goals have a FK → curriculum_tracks(id), so the track must exist
/// before any goal insert.
Future<int> _seedTrack(UserDatabase db) async {
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _profileId,
          curriculumId: _curriculumId,
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

/// Build a minimal [GoalRow] for the test curriculum.
GoalRow _row({
  int? trackId,
  double targetPercent = 100.0,
  String description = 'Finish by year-end',
  String dateType = 'gregorian',
  String goalType = 'deadline',
  int? paceValue,
  String? pacePeriod,
  String? paceGranularity,
  DateTime? targetDate,
  DateTime? updatedAt,
}) => GoalRow(
  firestoreId:
      '${_curriculumId}_${targetPercent.toStringAsFixed(1)}'
      '_${_createdAt.millisecondsSinceEpoch}',
  profileId: _profileId,
  curriculumId: _curriculumId,
  trackId: trackId,
  targetPercent: targetPercent,
  description: description,
  dateType: dateType,
  goalType: goalType,
  paceValue: paceValue,
  pacePeriod: pacePeriod,
  paceGranularity: paceGranularity,
  targetDate: targetDate,
  createdAt: _createdAt,
  updatedAt: updatedAt ?? _updatedAt,
);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('goals — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late GoalMerger merger;
    late int trackId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = GoalMerger(db, store: store);

      // Seed account + profile so FK constraints on curriculum_tracks hold.
      await seedProfile(db);
      // Seed a track so the goals FK is satisfiable.
      trackId = await _seedTrack(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as the
        // live writers do after Phase B.
        final payload = _codec.encode(_row(trackId: trackId));

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the goal row materialised in the DB — not skipped.
        final goal = await db.goalDao.getGoalByTrack(trackId);

        expect(
          goal,
          isNotNull,
          reason:
              'GoalMerger must INSERT the row when codec.encode() payload is '
              'fed in — if null the merge read-keys diverge from the codec '
              'write-keys (the push↔merge key-contract bug). '
              'Likely cause: track_id missing from encode(), or wrong key name.',
        );
        expect(goal!.curriculumId, _curriculumId);
        expect(goal.targetPercent, 100.0);
        expect(goal.description, 'Finish by year-end');
        expect(goal.dateType, 'gregorian');
        expect(goal.goalType, 'deadline');
        expect(
          goal.updatedAt.toUtc(),
          _updatedAt,
          reason: 'updated_at must round-trip through the codec',
        );
        expect(
          goal.createdAt.toUtc(),
          _createdAt,
          reason: 'created_at must round-trip through the codec',
        );
      },
    );

    test('target_date round-trips correctly', () async {
      final payload = _codec.encode(
        _row(trackId: trackId, goalType: 'deadline', targetDate: _targetDate),
      );

      await merger.merge(profileId: _profileId, rows: [payload]);

      final goal = await db.goalDao.getGoalByTrack(trackId);
      expect(
        goal?.targetDate?.toUtc(),
        _targetDate,
        reason: 'target_date must round-trip through the codec',
      );
    });

    test('pace fields round-trip correctly', () async {
      final payload = _codec.encode(
        _row(
          trackId: trackId,
          goalType: 'pace',
          paceValue: 5,
          pacePeriod: 'per_day',
          paceGranularity: 'daf',
        ),
      );

      await merger.merge(profileId: _profileId, rows: [payload]);

      final goal = await db.goalDao.getGoalByTrack(trackId);
      expect(goal?.paceValue, 5, reason: 'pace_value must round-trip');
      expect(
        goal?.pacePeriod,
        'per_day',
        reason: 'pace_unit in encode() maps to pacePeriod in the DB',
      );
      expect(
        goal?.paceGranularity,
        'daf',
        reason: 'pace_granularity must round-trip through the codec',
      );
    });

    test('updated_at is persisted as LWW timestamp after merge', () async {
      await merger.merge(
        profileId: _profileId,
        rows: [_codec.encode(_row(trackId: trackId))],
      );

      // The LWW natural key for goals is remoteTrackId.toString().
      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.goal,
        profileId: _profileId,
        naturalKey: trackId.toString(),
      );
      expect(
        persisted,
        _updatedAt,
        reason:
            'persistUpdatedAt must record updated_at so subsequent pulls '
            'arbitrate LWW symmetrically',
      );
    });

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        // First: merge a newer row with targetPercent=100.
        await merger.merge(
          profileId: _profileId,
          rows: [_codec.encode(_row(trackId: trackId, targetPercent: 100.0))],
        );

        // Then: try to merge an older row with targetPercent=50 — must be ignored.
        await merger.merge(
          profileId: _profileId,
          rows: [
            _codec.encode(
              _row(
                trackId: trackId,
                targetPercent: 50.0,
                updatedAt: _olderUpdatedAt,
              ),
            ),
          ],
        );

        final goal = await db.goalDao.getGoalByTrack(trackId);
        expect(
          goal?.targetPercent,
          100.0,
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'targetPercent should remain 100.0 after the stale merge',
        );
      },
    );

    test('encode() emits track_id (required by GoalMerger natural key)', () {
      final payload = _codec.encode(_row(trackId: 42));

      expect(
        payload['track_id'],
        42,
        reason:
            'Phase B: encode() must emit track_id because GoalMerger uses '
            'it as the natural key (remoteTrackId) for LWW arbitration and '
            'upsertGoalByTrack. Without it every row is silently skipped.',
      );
    });

    test(
      'encode() emits target_percent, description, date_type, goal_type',
      () {
        final payload = _codec.encode(
          _row(
            trackId: 1,
            targetPercent: 75.0,
            description: 'Half-way milestone',
            dateType: 'hebrew',
            goalType: 'pace',
          ),
        );

        expect(payload['target_percent'], 75.0);
        expect(payload['description'], 'Half-way milestone');
        expect(payload['date_type'], 'hebrew');
        expect(payload['goal_type'], 'pace');
      },
    );
  });
}
