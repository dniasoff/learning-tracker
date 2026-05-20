/// Two-device convergence test harness (I-5).
///
/// Tests the merge layer (DriftMergeStore + MergeRouter + EntityMerger) using
/// two independent in-memory databases. No real Firestore is involved — to
/// simulate Device A pushing data that Device B pulls, we serialise Device A's
/// rows into wire-format maps and dispatch them through Device B's MergeRouter.
///
/// Scenarios:
///   1. Completion set-union  — after bidirectional merge, both devices have
///      both completions (INSERT OR IGNORE on natural key).
///   2. Track deactivation LWW — Device A deactivates a track; after Device B
///      merges that row its local track carries deactivatedAt.
///   3. Idempotent re-merge   — replaying the same rows twice is a no-op.
@Tags(['i5', 'two_device_sync'])
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/bookmark_merger.dart';
import 'package:learning_tracker/core/sync/merge/completion_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/learner_profile_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/streak_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';

import '../helpers/test_database.dart' show seedProfile;

// ── helpers ─────────────────────────────────────────────────────────────────

/// Build a fully-wired [MergeRouter] for [db].
MergeRouter _buildRouter(UserDatabase db) {
  final store = DriftMergeStore(db);
  return MergeRouter(
    mergers: <String, EntityMerger>{
      EntityKind.completion: CompletionEventMerger(store: store),
      EntityKind.streak: StreakEventMerger(db),
      EntityKind.learnerProfile: LearnerProfileMerger(store: store),
      EntityKind.trackConfig: TrackConfigMerger(store: store),
      EntityKind.bookmark: BookmarkMerger(store: store),
      EntityKind.settings: SettingsMerger(store: store),
      EntityKind.stageDefinition: StageDefinitionMerger(store: store),
    },
  );
}

/// Insert a completion event and return a wire-format map for the other device.
Future<Map<String, dynamic>> _insertCompletion(
  UserDatabase db, {
  required int profileId,
  required String sefariaRef,
  required DateTime eventTimestamp,
  int stageId = 1,
  String trackType = 'personal',
  String curriculumId = 'mishnayos',
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      eventTimestamp: eventTimestamp,
    ),
  );
  return {
    'curriculum_id': curriculumId,
    'sefaria_ref': sefariaRef,
    'stage_id': stageId,
    'track_type': trackType,
    'event_timestamp': eventTimestamp.toIso8601String(),
  };
}

/// Insert a curriculum track on [db] and return a wire-format map.
Future<Map<String, dynamic>> _insertTrack(
  UserDatabase db, {
  required int profileId,
  required DateTime activatedAt,
  String curriculumId = 'mishnayos',
  String trackType = 'personal',
}) async {
  await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: activatedAt,
          activatedAt: activatedAt,
        ),
      );
  return {
    'curriculum_id': curriculumId,
    'track_type': trackType,
    'is_active': true,
    'activated_at': activatedAt.toIso8601String(),
    'deactivated_at': null,
    'updated_at': activatedAt.toIso8601String(),
  };
}

// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  const profileId = 1;

  group('Two-device sync convergence', () {
    late UserDatabase deviceA;
    late UserDatabase deviceB;
    late MergeRouter routerA;
    late MergeRouter routerB;

    setUp(() async {
      deviceA = UserDatabase(NativeDatabase.memory());
      deviceB = UserDatabase(NativeDatabase.memory());
      await seedProfile(deviceA);
      await seedProfile(deviceB);
      routerA = _buildRouter(deviceA);
      routerB = _buildRouter(deviceB);
    });

    tearDown(() async {
      await deviceA.close();
      await deviceB.close();
    });

    // ── Scenario 1: completion set-union ─────────────────────────────────────

    test(
      'completion set-union: after bidirectional merge both devices have both completions',
      () async {
        final t0 = DateTime.utc(2026, 1, 1, 10, 0, 0);
        final t1 = DateTime.utc(2026, 1, 1, 10, 0, 1);

        // Each device inserts a distinct completion.
        final wireFromA = await _insertCompletion(
          deviceA,
          profileId: profileId,
          sefariaRef: 'Berakhot',
          eventTimestamp: t0,
        );
        final wireFromB = await _insertCompletion(
          deviceB,
          profileId: profileId,
          sefariaRef: 'Shabbat',
          eventTimestamp: t1,
        );

        // Bidirectional merge: A's row → B, B's row → A.
        await routerB.dispatch(
          profileId: profileId,
          kind: EntityKind.completion,
          rows: [wireFromA],
        );
        await routerA.dispatch(
          profileId: profileId,
          kind: EntityKind.completion,
          rows: [wireFromB],
        );

        final eventsA = await deviceA.completionEventDao.getEventsByProfile(
          profileId,
        );
        final eventsB = await deviceB.completionEventDao.getEventsByProfile(
          profileId,
        );

        expect(
          eventsA.map((e) => e.sefariaRef).toSet(),
          {'Berakhot', 'Shabbat'},
          reason: 'Device A must have both completions after pulling from B',
        );
        expect(
          eventsB.map((e) => e.sefariaRef).toSet(),
          {'Berakhot', 'Shabbat'},
          reason: 'Device B must have both completions after pulling from A',
        );
      },
    );

    // ── Scenario 2: track deactivation LWW ───────────────────────────────────

    test(
      'track deactivation propagates via LWW: Device B gets deactivatedAt after merging Device A',
      () async {
        final activatedAt = DateTime.utc(2026, 1, 1, 9, 0, 0);
        final deactivatedAt = DateTime.utc(2026, 1, 1, 12, 0, 0);

        // Both devices start with the same active track.
        await _insertTrack(
          deviceA,
          profileId: profileId,
          activatedAt: activatedAt,
        );
        await _insertTrack(
          deviceB,
          profileId: profileId,
          activatedAt: activatedAt,
        );

        // Device A deactivates its track.
        await (deviceA.update(deviceA.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals('mishnayos') &
                  t.trackType.equals('personal'),
            ))
            .write(
              CurriculumTracksCompanion(
                isActive: const Value(false),
                deactivatedAt: Value(deactivatedAt),
              ),
            );

        // Wire-format map representing Device A's deactivated track.
        final wireFromA = {
          'curriculum_id': 'mishnayos',
          'track_type': 'personal',
          'is_active': false,
          'activated_at': activatedAt.toIso8601String(),
          'deactivated_at': deactivatedAt.toIso8601String(),
          'updated_at': deactivatedAt.toIso8601String(),
        };

        // Device B merges Device A's track row.
        await routerB.dispatch(
          profileId: profileId,
          kind: EntityKind.trackConfig,
          rows: [wireFromA],
        );

        final trackB =
            await (deviceB.select(deviceB.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(profileId) &
                      t.curriculumId.equals('mishnayos') &
                      t.trackType.equals('personal'),
                ))
                .getSingleOrNull();

        expect(trackB, isNotNull, reason: 'Device B must still have the track');
        expect(
          trackB!.isActive,
          isFalse,
          reason: 'Track must be marked inactive on Device B after LWW merge',
        );
        expect(
          trackB.deactivatedAt!.millisecondsSinceEpoch,
          deactivatedAt.millisecondsSinceEpoch,
          reason:
              'Device B must carry the deactivatedAt timestamp from Device A',
        );
      },
    );

    // ── Scenario 3: idempotent re-merge ──────────────────────────────────────

    test(
      'completion re-merge is idempotent: replaying the same rows twice produces no duplicates',
      () async {
        final t0 = DateTime.utc(2026, 2, 1, 8, 0, 0);
        final wireRow = await _insertCompletion(
          deviceA,
          profileId: profileId,
          sefariaRef: 'Peah',
          eventTimestamp: t0,
        );

        // Dispatch the same row twice to Device B.
        await routerB.dispatch(
          profileId: profileId,
          kind: EntityKind.completion,
          rows: [wireRow],
        );
        await routerB.dispatch(
          profileId: profileId,
          kind: EntityKind.completion,
          rows: [wireRow],
        );

        final eventsB = await deviceB.completionEventDao.getEventsByProfile(
          profileId,
        );
        expect(
          eventsB.where((e) => e.sefariaRef == 'Peah').length,
          1,
          reason: 'INSERT OR IGNORE must collapse duplicate completion rows',
        );
      },
    );
  });
}
