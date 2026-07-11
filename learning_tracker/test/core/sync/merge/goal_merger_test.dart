/// Unit tests for [GoalMerger]: Phase-3 LWW symmetry + persistUpdatedAt
/// against a real [DriftMergeStore], and the codec.encode() -> merger -> DB
/// round-trip (Phase B invariant).
///
/// AG-5 (AUD-app-05): consolidates test/sync/merge/lww_symmetric_test.dart's
/// GoalMerger group, test/sync/merge/persist_updated_at_test.dart's GoalMerger
/// case, and test/sync/merge/goals_roundtrip_test.dart into the single file
/// mirroring lib/core/sync/merge/goal_merger.dart.
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

import '../../../helpers/test_database.dart';

// ── Phase 3 LWW-symmetry / persistUpdatedAt fixtures ────────────────────────
final _local = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteNewer = DateTime.utc(2026, 5, 21, 13, 0, 0);
final _remoteOlder = DateTime.utc(2026, 5, 21, 11, 0, 0);
const _profileId = 1;
final _ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);

// ── codec.encode() → merger → DB round-trip fixtures ─────────────────────────
const _rtCodec = GoalCodec();

/// Profile id produced by [seedProfile] (auto-increment → 1).
const _rtProfileId = 1;
const _rtCurriculumId = 'bavli';

final _rtCreatedAt = DateTime.utc(2026, 1, 1);
final _rtUpdatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _rtOlderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);
final _rtTargetDate = DateTime.utc(2026, 12, 31);

/// Seed a [curriculum_tracks] row and return its local id.
///
/// Goals have a FK → curriculum_tracks(id), so the track must exist
/// before any goal insert.
Future<int> _rtSeedTrack(UserDatabase db) async {
  return db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: _rtProfileId,
          curriculumId: _rtCurriculumId,
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

/// Build a minimal [GoalRow] for the test curriculum.
GoalRow _rtRow({
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
      '${_rtCurriculumId}_${targetPercent.toStringAsFixed(1)}'
      '_${_rtCreatedAt.millisecondsSinceEpoch}',
  profileId: _rtProfileId,
  curriculumId: _rtCurriculumId,
  trackId: trackId,
  targetPercent: targetPercent,
  description: description,
  dateType: dateType,
  goalType: goalType,
  paceValue: paceValue,
  pacePeriod: pacePeriod,
  paceGranularity: paceGranularity,
  targetDate: targetDate,
  createdAt: _rtCreatedAt,
  updatedAt: updatedAt ?? _rtUpdatedAt,
);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('GoalMerger — LWW symmetry + persistence (real DriftMergeStore)', () {
    late UserDatabase db;
    late DriftMergeStore store;
    const profileId = 1;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      await seedProfile(db);
      store = DriftMergeStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('GoalMerger', () {
      late GoalMerger merger;

      setUp(() {
        merger = GoalMerger(db, store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'profile_id': profileId,
        'curriculum_id': 'bavli',
        'track_id': 1,
        'description': 'Daily 1 mishnah',
        'target_percent': 100.0,
        'created_at': _local.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
      };

      Future<void> seedTrack() async {
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                stateChangedAt: _local,
                activatedAt: _local,
              ),
            );
      }

      test('remote newer than local → applies', () async {
        await seedTrack();
        await store.persistUpdatedAt(
          kind: EntityKind.goal,
          profileId: profileId,
          naturalKey: '1',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.goal,
          profileId: profileId,
          naturalKey: '1',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await seedTrack();
        await store.persistUpdatedAt(
          kind: EntityKind.goal,
          profileId: profileId,
          naturalKey: '1',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.goal,
          profileId: profileId,
          naturalKey: '1',
        );
        expect(after, _local);
      });

      // R4-5 regression: pace_granularity must survive pull on fresh device.
      test(
        'pace_granularity from Firestore row is persisted to local DB',
        () async {
          await seedTrack();

          await merger.merge(
            profileId: profileId,
            rows: [
              {
                ...row(updatedAt: _remoteNewer),
                'pace_value': 2,
                'pace_unit': 'week',
                'pace_granularity': 'perek',
              },
            ],
          );

          final goal = await db.goalDao.getGoalByTrack(1);
          expect(goal, isNotNull);
          expect(
            goal!.paceGranularity,
            'perek',
            reason:
                'pace_granularity must not be dropped during GoalMerger.merge()',
          );
        },
      );
    });

    Future<void> seedTrack() async {
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'bavli',
              stateChangedAt: _ts.subtract(const Duration(days: 1)),
              activatedAt: _ts.subtract(const Duration(days: 1)),
            ),
          );
    }

    test('GoalMerger', () async {
      await seedTrack();
      await GoalMerger(db, store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'profile_id': _profileId,
            'curriculum_id': 'bavli',
            'track_id': 1,
            'description': 'Daily',
            'target_percent': 100.0,
            'created_at': _ts.toIso8601String(),
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.goal,
        profileId: _profileId,
        naturalKey: '1',
      );
      expect(updatedAt, _ts);
    });
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
      trackId = await _rtSeedTrack(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as the
        // live writers do after Phase B.
        final payload = _rtCodec.encode(_rtRow(trackId: trackId));

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _rtProfileId, rows: [payload]);

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
        expect(goal!.curriculumId, _rtCurriculumId);
        expect(goal.targetPercent, 100.0);
        expect(goal.description, 'Finish by year-end');
        expect(goal.dateType, 'gregorian');
        expect(goal.goalType, 'deadline');
        expect(
          goal.updatedAt.toUtc(),
          _rtUpdatedAt,
          reason: 'updated_at must round-trip through the codec',
        );
        expect(
          goal.createdAt.toUtc(),
          _rtCreatedAt,
          reason: 'created_at must round-trip through the codec',
        );
      },
    );

    test('target_date round-trips correctly', () async {
      final payload = _rtCodec.encode(
        _rtRow(
          trackId: trackId,
          goalType: 'deadline',
          targetDate: _rtTargetDate,
        ),
      );

      await merger.merge(profileId: _rtProfileId, rows: [payload]);

      final goal = await db.goalDao.getGoalByTrack(trackId);
      expect(
        goal?.targetDate?.toUtc(),
        _rtTargetDate,
        reason: 'target_date must round-trip through the codec',
      );
    });

    test('pace fields round-trip correctly', () async {
      final payload = _rtCodec.encode(
        _rtRow(
          trackId: trackId,
          goalType: 'pace',
          paceValue: 5,
          pacePeriod: 'per_day',
          paceGranularity: 'daf',
        ),
      );

      await merger.merge(profileId: _rtProfileId, rows: [payload]);

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
        profileId: _rtProfileId,
        rows: [_rtCodec.encode(_rtRow(trackId: trackId))],
      );

      // The LWW natural key for goals is remoteTrackId.toString().
      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.goal,
        profileId: _rtProfileId,
        naturalKey: trackId.toString(),
      );
      expect(
        persisted,
        _rtUpdatedAt,
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
          profileId: _rtProfileId,
          rows: [
            _rtCodec.encode(_rtRow(trackId: trackId, targetPercent: 100.0)),
          ],
        );

        // Then: try to merge an older row with targetPercent=50 — must be ignored.
        await merger.merge(
          profileId: _rtProfileId,
          rows: [
            _rtCodec.encode(
              _rtRow(
                trackId: trackId,
                targetPercent: 50.0,
                updatedAt: _rtOlderUpdatedAt,
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
      final payload = _rtCodec.encode(_rtRow(trackId: 42));

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
        final payload = _rtCodec.encode(
          _rtRow(
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
