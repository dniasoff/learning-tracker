/// Regression + parity coverage for [resolveLocalTrackId] (AUD-t-cross-43).
///
/// Direct unit tests for the shared helper, plus a parity suite proving
/// every child-row merger (goal, gamification_settings points_config,
/// study_day_config, stage_definition, settings) skips IDENTICALLY when no
/// local track exists for the row's (profile, curriculum) — even when the
/// row's remote `track_id` happens to numerically match an UNRELATED local
/// track (a different curriculum on the same profile). Before this fix,
/// GoalMerger/StudyDayConfigMerger/StageDefinitionMerger/SettingsMerger each
/// independently fell back to `TrackDao.getById(remoteTrackId)` and silently
/// bound the row to that coincidentally-matching but wrong track, while
/// GamificationSettingsMerger alone skipped — a real divergence, not just
/// duplicated code.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/gamification_settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/goal_merger.dart';
import 'package:learning_tracker/core/sync/merge/local_track_id_resolver.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/study_day_config_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

const _profileId = 1;
// Has a local curriculum_tracks row — otherTrackId below.
const _otherCurriculum = 'other-curriculum';
// Deliberately NEVER has a local curriculum_tracks row in this suite.
const _targetCurriculum = 'target-curriculum';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late UserDatabase db;
  late DriftMergeStore store;
  late int otherTrackId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = UserDatabase(NativeDatabase.memory());
    store = DriftMergeStore(db);
    await seedProfile(db);
    otherTrackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: _profileId,
            curriculumId: _otherCurriculum,
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() => db.close());

  group('resolveLocalTrackId', () {
    test(
      'returns the local track id when (profile, curriculum) matches',
      () async {
        final resolved = await resolveLocalTrackId(
          db,
          profileId: _profileId,
          curriculumId: _otherCurriculum,
        );
        expect(resolved, otherTrackId);
      },
    );

    test('returns null when no local track matches (profile, curriculum) — '
        'never guesses via a coincidentally-matching id from another '
        'curriculum', () async {
      final resolved = await resolveLocalTrackId(
        db,
        profileId: _profileId,
        curriculumId: _targetCurriculum,
      );
      expect(resolved, isNull);
    });
  });

  group('parity: every child-row merger skips identically when the local track '
      'is missing, even when the remote track_id coincidentally matches an '
      'UNRELATED local track (AUD-t-cross-43)', () {
    test(
      'GoalMerger: row is skipped, not bound to the unrelated track',
      () async {
        final merger = GoalMerger(db, store: store);
        await merger.merge(
          profileId: _profileId,
          rows: [
            {
              'curriculum_id': _targetCurriculum,
              'track_id': otherTrackId,
              'description': 'must never apply',
              'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        );

        final rows = await (db.select(
          db.goals,
        )..where((t) => t.curriculumId.equals(_targetCurriculum))).get();
        expect(rows, isEmpty);
      },
    );

    test('GamificationSettingsMerger: row is skipped, not bound to the '
        'unrelated track', () async {
      final merger = GamificationSettingsMerger(db: db, store: store);
      await merger.merge(
        profileId: _profileId,
        rows: [
          {
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'points_config': [
              {
                'curriculum_id': _targetCurriculum,
                'track_id': otherTrackId,
                'stage_order': 0,
                'points': 10,
              },
            ],
          },
        ],
      );

      final rows = await db.pointConfigDao.getConfigsByCurriculum(
        _targetCurriculum,
        profileId: _profileId,
      );
      expect(rows, isEmpty);
    });

    test('StudyDayConfigMerger: row is skipped, not bound to the unrelated '
        'track', () async {
      final merger = StudyDayConfigMerger(db, store: store);
      await merger.merge(
        profileId: _profileId,
        rows: [
          {
            'profile_id': _profileId,
            'curriculum_id': _targetCurriculum,
            'track_id': otherTrackId,
            'day_of_week': 3,
            'day_type': 'review',
            'updated_at': '2026-05-01T10:00:00.000Z',
          },
        ],
      );

      final rows = await (db.select(
        db.studyDayConfigs,
      )..where((t) => t.curriculumId.equals(_targetCurriculum))).get();
      expect(rows, isEmpty);
    });

    test('StageDefinitionMerger: row is skipped, not bound to the unrelated '
        'track', () async {
      final merger = StageDefinitionMerger(store: store);
      await merger.merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': _targetCurriculum,
            'track_id': otherTrackId,
            'stage_order': 0,
            'stage_name': 'learning',
            'schedule': '{"type":"delay","delay_days":0}',
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        ],
      );

      final rows = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.curriculumId.equals(_targetCurriculum))).get();
      expect(rows, isEmpty);
    });

    test('SettingsMerger (DriftMergeStore._upsertSettings): row is skipped, '
        'not bound to the unrelated track', () async {
      await store.upsert(
        kind: EntityKind.settings,
        profileId: _profileId,
        fields: {
          'curriculum_id': _targetCurriculum,
          'track_id': otherTrackId,
          'stages': [
            {
              'stage_order': 0,
              'stage_name': 'learning',
              'schedule': '{"type":"delay","delay_days":0}',
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        },
      );

      final rows = await (db.select(
        db.stageDefinitions,
      )..where((t) => t.curriculumId.equals(_targetCurriculum))).get();
      expect(rows, isEmpty);
    });
  });
}
