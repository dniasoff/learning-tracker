/// Bug 3 regression — tutored mirror computed-schedule inputs.
///
/// In a tutor session the child's track config was mirrored but the per-track
/// computed inputs (stage_definitions / goals / study_day_configs /
/// point_configs) carried the PARENT device's track id. The tutor mirror
/// re-creates the same logical track under a DIFFERENT local autoincrement id,
/// so those child rows referenced a non-existent local track:
///   • stage_definitions / goals → not found by getStagesByTrack/getGoalByTrack
///     (the scheduler projection bailed → "No projection", 0 due, 0% lifetime);
///   • study_day_configs / point_configs → dropped or FK-crashed
///     (tutored_pull_error / tutored_listener_merge_error for
///     gamification_settings).
///
/// The mergers now resolve the LOCAL track id from (profile, curriculum) so
/// every child row binds to the mirror's local track. These tests merge mirror
/// data whose stored track_id is a STALE remote id and assert the projection
/// inputs are queryable by the LOCAL mirror track id.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/gamification_settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/goal_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/study_day_config_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _curriculum = 'mishnayos';
const _remoteTrackId = 770077; // parent device's track id — never the local id.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserDatabase db;
  late DriftMergeStore store;
  late int mirrorProfileId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = UserDatabase(NativeDatabase.memory());
    store = DriftMergeStore(db);

    // Seed the tutor's own account.
    final accountId = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'tutor@example.com',
            tier: 'cloudBorn',
            displayName: 'Tutor',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );

    // Seed the synthetic tutored-mirror profile (is_tutored = true).
    mirrorProfileId = await db.profileDao.upsertTutoredProfile(
      accountId: accountId,
      parentUid: 'parent-uid-1',
      remoteChildProfileId: 'remote-child-1',
      grantId: 'grant-1',
      displayName: 'Talmid',
      mode: 'child',
      now: DateTime.utc(2026, 1, 1),
    );
  });

  tearDown(() => db.close());

  /// Merge the child's track config first (as the reordered tutored pull does),
  /// returning the LOCAL mirror track id.
  Future<int> mergeMirrorTrack() async {
    final trackMerger = TrackConfigMerger(store: store);
    await trackMerger.merge(
      profileId: mirrorProfileId,
      rows: [
        {
          'curriculum_id': _curriculum,
          'state': 'active',
          'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          'state_changed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      ],
    );
    final localTrack = await db.trackDao.getTrackByProfileAndCurriculum(
      mirrorProfileId,
      _curriculum,
    );
    expect(localTrack, isNotNull);
    // The mirror's local autoincrement id must differ from the remote id.
    expect(localTrack!.id, isNot(equals(_remoteTrackId)));
    return localTrack.id;
  }

  test(
    'stage_definitions with a remote track_id bind to the local mirror track',
    () async {
      final localTrackId = await mergeMirrorTrack();

      final stageMerger = StageDefinitionMerger(store: store);
      await stageMerger.merge(
        profileId: mirrorProfileId,
        rows: [
          {
            'curriculum_id': _curriculum,
            'track_id': _remoteTrackId,
            'stage_order': 0,
            'stage_name': 'learning',
            'is_default': true,
            'schedule': '{"type":"delay","delay_days":0}',
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        ],
      );

      // The projection reads stages by the LOCAL track id.
      final stages = await db.stageDao.getStagesByTrack(localTrackId);
      expect(
        stages,
        isNotEmpty,
        reason: 'projection had no stages → "No projection"',
      );
      expect(stages.single.trackId, equals(localTrackId));
    },
  );

  test('goals with a remote track_id bind to the local mirror track', () async {
    final localTrackId = await mergeMirrorTrack();

    final goalMerger = GoalMerger(db, store: store);
    await goalMerger.merge(
      profileId: mirrorProfileId,
      rows: [
        {
          'curriculum_id': _curriculum,
          'track_id': _remoteTrackId,
          'goal_type': 'pace',
          'pace_value': 1,
          'pace_unit': 'per_day',
          'created_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
      ],
    );

    final goal = await db.goalDao.getGoalByTrack(localTrackId);
    expect(
      goal,
      isNotNull,
      reason: 'projection had no goal → no due-today computed',
    );
    expect(goal!.paceValue, equals(1));
  });

  test(
    'study_day_configs with a remote track_id bind to the local mirror track',
    () async {
      final localTrackId = await mergeMirrorTrack();

      final sdcMerger = StudyDayConfigMerger(db, store: store);
      await sdcMerger.merge(
        profileId: mirrorProfileId,
        rows: [
          for (var d = 1; d <= 5; d++)
            {
              'profile_id': mirrorProfileId,
              'curriculum_id': _curriculum,
              'track_id': _remoteTrackId,
              'day_of_week': d,
              'day_type': 'study',
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
        ],
      );

      final configs = await db.studyDayConfigDao.getConfigsByTrack(
        localTrackId,
      );
      expect(
        configs,
        hasLength(5),
        reason: 'study-day pattern lost → projection cannot schedule',
      );
    },
  );

  test(
    'gamification point_configs with a remote track_id no longer FK-crash and '
    'bind to the local mirror track',
    () async {
      final localTrackId = await mergeMirrorTrack();

      final gamMerger = GamificationSettingsMerger(db: db, store: store);
      // Must NOT throw (previously a point_configs FK violation surfaced as
      // tutored_pull_error / tutored_listener_merge_error).
      await gamMerger.merge(
        profileId: mirrorProfileId,
        rows: [
          {
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'points_config': [
              {
                'curriculum_id': _curriculum,
                'track_id': _remoteTrackId,
                'stage_order': 0,
                'points': 10,
              },
            ],
          },
        ],
      );

      final configs = await db.pointConfigDao.getConfigsByCurriculum(
        _curriculum,
        profileId: mirrorProfileId,
        trackId: localTrackId,
      );
      expect(configs, hasLength(1));
      expect(configs.single.points, equals(10));
    },
  );
}
