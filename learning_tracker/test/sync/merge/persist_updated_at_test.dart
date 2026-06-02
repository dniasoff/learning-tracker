/// Phase 3: assert every LWW merger persists the remote `updated_at` via
/// [DriftMergeStore.persistUpdatedAt] so subsequent pulls arbitrate
/// symmetrically.
///
/// Each test merges a row with a known `updated_at`, then reads back the
/// store's [currentUpdatedAt] for the same `(kind, naturalKey)` and asserts
/// it matches the merged row's timestamp.
@Tags(['persist_updated_at'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/bookmark_merger.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/gamification_settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/goal_merger.dart';
import 'package:learning_tracker/core/sync/merge/learner_profile_merger.dart';
import 'package:learning_tracker/core/sync/merge/learning_order_merger.dart';
import 'package:learning_tracker/core/sync/merge/notification_settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/profile_program_merger.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';
import 'package:learning_tracker/core/sync/merge/ui_preferences_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _profileId = 1;
final _ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('persistUpdatedAt — every LWW merger persists after apply', () {
    late UserDatabase db;
    late DriftMergeStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      await seedProfile(db);
      store = DriftMergeStore(db);
    });

    tearDown(() async {
      await db.close();
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

    test('BookmarkMerger', () async {
      await seedTrack();
      await BookmarkMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': 'bavli',
            'sefaria_ref': 'Berakhot 1',
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.bookmark,
        profileId: _profileId,
        naturalKey: 'bavli',
      );
      final syncedAt = await store.currentSyncedAt(
        kind: EntityKind.bookmark,
        profileId: _profileId,
        naturalKey: 'bavli',
      );
      expect(updatedAt, _ts);
      expect(syncedAt, _syncedAt);
    });

    test('SettingsMerger', () async {
      // SettingsMerger materialises nested stage_definitions which FK
      // curriculum_tracks(id) — seed a track first.
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'bavli',
              stateChangedAt: _ts.subtract(const Duration(days: 1)),
              activatedAt: _ts.subtract(const Duration(days: 1)),
            ),
          );

      await SettingsMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': 'bavli',
            'track_id': trackId,
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
            'stages': [
              {
                'track_id': trackId,
                'stage_order': 0,
                'stage_name': 'learning',
                'is_default': true,
              },
            ],
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.settings,
        profileId: _profileId,
        naturalKey: 'bavli',
      );
      expect(updatedAt, _ts);
    });

    test('StageDefinitionMerger', () async {
      // stage_definitions.track_id FKs curriculum_tracks(id).
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'bavli',
              stateChangedAt: _ts.subtract(const Duration(days: 1)),
              activatedAt: _ts.subtract(const Duration(days: 1)),
            ),
          );

      await StageDefinitionMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': 'bavli',
            'track_id': trackId,
            'stage_order': 0,
            'stage_name': 'learning',
            'is_default': true,
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.stageDefinition,
        profileId: _profileId,
        naturalKey: 'bavli|$trackId|0',
      );
      expect(updatedAt, _ts);
    });

    test('LearningOrderMerger', () async {
      await LearningOrderMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': 'bavli',
            'sefaria_ref': 'Berakhot',
            'user_sort_order': 1,
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.learningOrder,
        profileId: _profileId,
        naturalKey: 'bavli|Berakhot',
      );
      expect(updatedAt, _ts);
    });

    test('TrackConfigMerger', () async {
      await TrackConfigMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': 'bavli',
            'state': 'active',
            'activated_at': _ts.toIso8601String(),
            'state_changed_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.trackConfig,
        profileId: _profileId,
        naturalKey: 'bavli',
      );
      expect(updatedAt, _ts);
    });

    test('LearnerProfileMerger', () async {
      await LearnerProfileMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'profile_id': _profileId,
            'account_id': 1,
            'display_name': 'Alice',
            'mode': 'adult',
            'updated_at': _ts.toIso8601String(),
            'created_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.learnerProfile,
        profileId: _profileId,
        naturalKey: _profileId.toString(),
      );
      expect(updatedAt, _ts);
    });

    test('ProfileProgramMerger', () async {
      await ProfileProgramMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'profile_id': _profileId,
            'curriculum_id': 'bavli',
            'program_id': 1,
            'tracking_start_date': _ts.toIso8601String(),
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.profileProgram,
        // R3-6: natural key is the entity key only ('bavli'); profileId is added
        // by _scopedKey. Previously this was double-scoped ('$profileId|bavli').
        naturalKey: 'bavli',
        profileId: _profileId,
      );
      expect(updatedAt, _ts);
    });

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

    test('NotificationSettingsMerger', () async {
      await NotificationSettingsMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
            'daily_reminder': {'enabled': true, 'hour': 7, 'minute': 30},
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.notificationSettings,
        profileId: _profileId,
        naturalKey: 'preferences',
      );
      expect(updatedAt, _ts);
    });

    test('GamificationSettingsMerger', () async {
      await GamificationSettingsMerger(
        db: db,
        store: store,
        onRewardSettings: null,
      ).merge(
        profileId: _profileId,
        rows: [
          {
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
            'points_config': const <Map<String, Object?>>[],
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.gamificationSettings,
        profileId: _profileId,
        naturalKey: 'config',
      );
      expect(updatedAt, _ts);
    });

    test('UiPreferencesMerger', () async {
      await UiPreferencesMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
            'app_locale': 'en',
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.uiPreferences,
        profileId: _profileId,
        naturalKey: 'data',
      );
      expect(updatedAt, _ts);
    });
  });
}
