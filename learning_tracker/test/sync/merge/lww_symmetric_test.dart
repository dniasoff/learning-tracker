/// Phase 3 LWW symmetry tests for every LWW merger.
///
/// Asserts the four invariants from the sync architecture plan §C.2:
///   1. Remote newer than local → applies (existing behaviour).
///   2. Local newer than remote → does NOT apply (new — used to overwrite
///      because [DriftMergeStore.currentUpdatedAt] returned null).
///   3. Within ±5 s clock skew with differing `synced_at` → server
///      timestamp decides.
///   4. Same `synced_at` (or missing) → remote wins (convergence).
@Tags(['lww_symmetric'])
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

/// Strict timestamps to make ordering unambiguous.
final _local = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteNewer = DateTime.utc(2026, 5, 21, 13, 0, 0);
final _remoteOlder = DateTime.utc(2026, 5, 21, 11, 0, 0);

/// Within the ±5 s clock-skew window.
final _localSkew = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteSkew = DateTime.utc(2026, 5, 21, 12, 0, 2); // 2 s ahead

/// Synced_at values for the tie-breaker test.
final _localSynced = DateTime.utc(2026, 5, 21, 12, 0, 5);
final _remoteSyncedNewer = DateTime.utc(2026, 5, 21, 12, 0, 10);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Phase 3 LWW symmetry', () {
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

    // ── BookmarkMerger ───────────────────────────────────────────────────────

    group('BookmarkMerger', () {
      late BookmarkMerger merger;

      setUp(() {
        merger = BookmarkMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'curriculum_id': 'bavli',
        'track_type': 'personal',
        'sefaria_ref': 'Berakhot 1',
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
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await seedTrack();
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
        );
        expect(after, _local);
      });

      test('within ±5 s — remote synced_at newer → applies', () async {
        await seedTrack();
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
        );
        expect(after, _remoteSkew);
      });

      test('same synced_at — remote wins (convergence)', () async {
        await seedTrack();
        await store.persistUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _localSynced)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: profileId,
          naturalKey: 'bavli|personal',
        );
        expect(after, _remoteSkew);
      });
    });

    // ── SettingsMerger ───────────────────────────────────────────────────────

    group('SettingsMerger', () {
      late SettingsMerger merger;
      late int settingsTrackId;

      setUp(() async {
        merger = SettingsMerger(store: store);
        // SettingsMerger materialises nested stage_definitions which FK
        // curriculum_tracks(id) — seed a track first.
        settingsTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                stateChangedAt: _local,
                activatedAt: _local,
              ),
            );
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'curriculum_id': 'bavli',
        'track_id': settingsTrackId,
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        'stages': [
          {
            'track_id': settingsTrackId,
            'stage_order': 0,
            'stage_name': 'learning',
            'is_default': true,
          },
        ],
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _local);
      });

      test('within ±5 s — remote synced_at newer → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteSkew);
      });

      test('same synced_at — remote wins', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _localSynced)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.settings,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteSkew);
      });
    });

    // ── StageDefinitionMerger ───────────────────────────────────────────────

    group('StageDefinitionMerger', () {
      late StageDefinitionMerger merger;
      late int seededTrackId;

      setUp(() async {
        merger = StageDefinitionMerger(store: store);
        // stage_definitions.track_id FKs curriculum_tracks(id); seed one so
        // the merger's upsert doesn't fail with SqliteException(787).
        seededTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: 'bavli',
                stateChangedAt: _local,
                activatedAt: _local,
              ),
            );
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'curriculum_id': 'bavli',
        'track_id': seededTrackId,
        'stage_order': 0,
        'stage_name': 'learning',
        'is_default': true,
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          naturalKey: 'bavli|$seededTrackId|0',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          naturalKey: 'bavli|$seededTrackId|0',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          naturalKey: 'bavli|$seededTrackId|0',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          naturalKey: 'bavli|$seededTrackId|0',
        );
        expect(after, _local);
      });

      test('within ±5 s — remote synced_at newer → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          naturalKey: 'bavli|$seededTrackId|0',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.stageDefinition,
          profileId: profileId,
          naturalKey: 'bavli|$seededTrackId|0',
        );
        expect(after, _remoteSkew);
      });
    });

    // ── LearningOrderMerger ────────────────────────────────────────────────

    group('LearningOrderMerger', () {
      late LearningOrderMerger merger;

      setUp(() {
        merger = LearningOrderMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Berakhot',
        'user_sort_order': 1,
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.learningOrder,
          profileId: profileId,
          naturalKey: 'bavli|Berakhot',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.learningOrder,
          profileId: profileId,
          naturalKey: 'bavli|Berakhot',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.learningOrder,
          profileId: profileId,
          naturalKey: 'bavli|Berakhot',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.learningOrder,
          profileId: profileId,
          naturalKey: 'bavli|Berakhot',
        );
        expect(after, _local);
      });

      test('within ±5 s — remote synced_at newer → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.learningOrder,
          profileId: profileId,
          naturalKey: 'bavli|Berakhot',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.learningOrder,
          profileId: profileId,
          naturalKey: 'bavli|Berakhot',
        );
        expect(after, _remoteSkew);
      });
    });

    // ── TrackConfigMerger ──────────────────────────────────────────────────

    group('TrackConfigMerger', () {
      late TrackConfigMerger merger;

      setUp(() {
        merger = TrackConfigMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime stateChangedAt,
        DateTime? syncedAt,
      }) => {
        'curriculum_id': 'bavli',
        'state': 'active',
        'activated_at': stateChangedAt.toIso8601String(),
        'state_changed_at': stateChangedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(stateChangedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(stateChangedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _local);
      });

      test('within ±5 s — remote synced_at newer → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [
            row(stateChangedAt: _remoteSkew, syncedAt: _remoteSyncedNewer),
          ],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.trackConfig,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteSkew);
      });
    });

    // ── LearnerProfileMerger ───────────────────────────────────────────────

    group('LearnerProfileMerger', () {
      late LearnerProfileMerger merger;

      setUp(() {
        merger = LearnerProfileMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'profile_id': profileId,
        'account_id': 1,
        'display_name': 'Alice',
        'mode': 'adult',
        'updated_at': updatedAt.toIso8601String(),
        'created_at': _local.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.learnerProfile,
          profileId: profileId,
          naturalKey: profileId.toString(),
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.learnerProfile,
          profileId: profileId,
          naturalKey: profileId.toString(),
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.learnerProfile,
          profileId: profileId,
          naturalKey: profileId.toString(),
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.learnerProfile,
          profileId: profileId,
          naturalKey: profileId.toString(),
        );
        expect(after, _local);
      });
    });

    // ── ProfileProgramMerger ───────────────────────────────────────────────

    group('ProfileProgramMerger', () {
      late ProfileProgramMerger merger;

      setUp(() {
        merger = ProfileProgramMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'profile_id': profileId,
        'curriculum_id': 'bavli',
        'program_id': 1,
        'tracking_start_date': _local.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
      };

      // R3-6 fix: naturalKey is just curriculumId — profileId is added by
      // _scopedKey inside the store; using '$profileId|bavli' here was the
      // same double-scoping bug that the merger had. All four tests below now
      // use 'bavli' directly, matching the TrackConfigMerger pattern.

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _local);
      });

      test('within ±5 s — remote synced_at newer → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteSkew);
      });

      test('same synced_at — remote wins (convergence)', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _localSynced)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteSkew);
      });

      // R3-6 regression: verify that the key written by the merger on a
      // successful apply is exactly the key that currentUpdatedAt reads back.
      // Before the fix the merger wrote '$profileId|$profileId|$curriculumId'
      // while the test read '$profileId|$curriculumId' — a permanent key miss
      // that made every subsequent remote pull look "new".
      test(
        'R3-6 regression — key written by merger matches key read back',
        () async {
          // Start with no local timestamp for this (profileId, curriculumId).
          final before = await store.currentUpdatedAt(
            kind: EntityKind.profileProgram,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(
            before,
            isNull,
            reason: 'no local timestamp before first merge',
          );

          // First merge: remote is applied because there is no local record.
          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          // The timestamp the merger persisted must be readable under the same
          // (profileId, 'bavli') natural key.
          final afterFirst = await store.currentUpdatedAt(
            kind: EntityKind.profileProgram,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(
            afterFirst,
            _remoteNewer,
            reason:
                'merger must write the scoped key that currentUpdatedAt reads',
          );

          // Second merge with an older remote: should NOT overwrite because local
          // is newer. This only passes if the key used by merge() == the key
          // used by currentUpdatedAt() — i.e., no double-scoping.
          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final afterSecond = await store.currentUpdatedAt(
            kind: EntityKind.profileProgram,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(
            afterSecond,
            _remoteNewer,
            reason:
                'older remote must NOT overwrite the newer local — key mismatch '
                'would make every merge look new and allow silent overwrites',
          );
        },
      );
    });

    // ── GoalMerger ─────────────────────────────────────────────────────────

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

    // ── NotificationSettingsMerger ─────────────────────────────────────────

    group('NotificationSettingsMerger', () {
      late NotificationSettingsMerger merger;

      setUp(() {
        merger = NotificationSettingsMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        'daily_reminder': {'enabled': true, 'hour': 7, 'minute': 30},
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.notificationSettings,
          profileId: profileId,
          naturalKey: 'preferences',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.notificationSettings,
          profileId: profileId,
          naturalKey: 'preferences',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.notificationSettings,
          profileId: profileId,
          naturalKey: 'preferences',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.notificationSettings,
          profileId: profileId,
          naturalKey: 'preferences',
        );
        expect(after, _local);
      });
    });

    // ── GamificationSettingsMerger ─────────────────────────────────────────

    group('GamificationSettingsMerger', () {
      late GamificationSettingsMerger merger;

      setUp(() {
        merger = GamificationSettingsMerger(
          db: db,
          store: store,
          onRewardSettings: null,
        );
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        'points_config': const <Map<String, Object?>>[],
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.gamificationSettings,
          profileId: profileId,
          naturalKey: 'config',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.gamificationSettings,
          profileId: profileId,
          naturalKey: 'config',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.gamificationSettings,
          profileId: profileId,
          naturalKey: 'config',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.gamificationSettings,
          profileId: profileId,
          naturalKey: 'config',
        );
        expect(after, _local);
      });
    });

    // ── UiPreferencesMerger ────────────────────────────────────────────────

    group('UiPreferencesMerger', () {
      late UiPreferencesMerger merger;

      setUp(() {
        merger = UiPreferencesMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        'app_locale': 'en',
      };

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.uiPreferences,
          profileId: profileId,
          naturalKey: 'data',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.uiPreferences,
          profileId: profileId,
          naturalKey: 'data',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.uiPreferences,
          profileId: profileId,
          naturalKey: 'data',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.uiPreferences,
          profileId: profileId,
          naturalKey: 'data',
        );
        expect(after, _local);
      });
    });
  });

  // ── DriftMergeStore.remoteIsNewer unit tests ─────────────────────────────

  group('DriftMergeStore.remoteIsNewer', () {
    late UserDatabase db;
    late DriftMergeStore store;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      await seedProfile(db);
      store = DriftMergeStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('null remote → false', () {
      expect(
        store.remoteIsNewer(localUpdatedAt: _local, remoteUpdatedAt: null),
        isFalse,
      );
    });

    test('null local → true', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: null,
          remoteUpdatedAt: _remoteNewer,
        ),
        isTrue,
      );
    });

    test('remote strictly newer outside window → true', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: _local,
          remoteUpdatedAt: _remoteNewer,
        ),
        isTrue,
      );
    });

    test('local strictly newer outside window → false', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: _local,
          remoteUpdatedAt: _remoteOlder,
        ),
        isFalse,
      );
    });

    test('inside window, remote synced_at newer → true', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: _localSkew,
          remoteUpdatedAt: _remoteSkew,
          localSyncedAt: _localSynced,
          remoteSyncedAt: _remoteSyncedNewer,
        ),
        isTrue,
      );
    });

    test('inside window, local synced_at newer → false', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: _localSkew,
          remoteUpdatedAt: _remoteSkew,
          localSyncedAt: _remoteSyncedNewer,
          remoteSyncedAt: _localSynced,
        ),
        isFalse,
      );
    });

    test('inside window, equal synced_at → remote wins (true)', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: _localSkew,
          remoteUpdatedAt: _remoteSkew,
          localSyncedAt: _localSynced,
          remoteSyncedAt: _localSynced,
        ),
        isTrue,
      );
    });

    test('inside window, missing synced_at → remote wins (true)', () {
      expect(
        store.remoteIsNewer(
          localUpdatedAt: _localSkew,
          remoteUpdatedAt: _remoteSkew,
        ),
        isTrue,
      );
    });

    test('exactly identical timestamps, no synced_at → remote wins', () {
      // Both at the same instant: prefer remote to converge two devices
      // that wrote the same value.
      expect(
        store.remoteIsNewer(localUpdatedAt: _local, remoteUpdatedAt: _local),
        isTrue,
      );
    });
  });
}
