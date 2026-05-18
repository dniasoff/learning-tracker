/// I-5 pull-on-launch smoke test.
///
/// Scenario: a device that launches with an empty local DB must pull
/// completion_events from Firestore so the completions_view is populated.
///
/// This test exercises the merge layer (CompletionEventMerger +
/// DriftMergeStore) which is the final stage of the Firestore→local pipeline.
/// Wire-format maps represent documents as they arrive from Firestore; the
/// merger writes them to the local DB via CompletionEventDao.appendEvent, and
/// the assertion reads back through completions_view via
/// db.completionDao.getCompletionsByProfile — the same path the UI consumes.
@Tags(['integration', 'i5'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
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

// ── helpers ──────────────────────────────────────────────────────────────────

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

/// Builds a Firestore wire-format map for a completion event document.
Map<String, dynamic> _firestoreCompletion({
  required String sefariaRef,
  required DateTime eventTimestamp,
  String curriculumId = 'mishnayos',
  int stageId = 1,
  String trackType = 'personal',
}) => {
  'curriculum_id': curriculumId,
  'sefaria_ref': sefariaRef,
  'stage_id': stageId,
  'track_type': trackType,
  'event_timestamp': eventTimestamp.toIso8601String(),
};

// ── tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group(
    'I-5 — pull-on-launch: completion_events arrive in completions_view after first pull',
    () {
      late UserDatabase db;
      late MergeRouter router;

      const profileId = 1;

      setUp(() async {
        db = UserDatabase(NativeDatabase.memory());
        await seedProfile(db);
        router = _buildRouter(db);
      });

      tearDown(() async {
        await db.close();
      });

      test(
        'empty DB receives 3 Firestore completion_events and all appear in completions_view',
        () async {
          // Arrange: three Firestore documents as they would arrive during a
          // pull, representing the remote completion history for this user.
          final t0 = DateTime.utc(2026, 3, 1, 8, 0, 0);
          final t1 = DateTime.utc(2026, 3, 2, 9, 0, 0);
          final t2 = DateTime.utc(2026, 3, 3, 10, 0, 0);

          final firestoreDocs = [
            _firestoreCompletion(sefariaRef: 'Berakhot 1a', eventTimestamp: t0),
            _firestoreCompletion(sefariaRef: 'Berakhot 2a', eventTimestamp: t1),
            _firestoreCompletion(sefariaRef: 'Berakhot 3a', eventTimestamp: t2),
          ];

          // Pre-condition: local DB is empty for this profile.
          final before = await db.completionDao.getCompletionsByProfile(
            profileId,
          );
          expect(before, isEmpty, reason: 'DB must be empty before pull');

          // Act: dispatch the Firestore documents through the merge layer —
          // this is what SyncEngine does during a pull on launch.
          await router.dispatch(
            profileId: profileId,
            kind: EntityKind.completion,
            rows: firestoreDocs,
          );

          // Assert: all three completions are now visible through
          // completions_view, which is the C1-backed read path the UI uses.
          final after = await db.completionDao.getCompletionsByProfile(
            profileId,
          );

          expect(
            after.length,
            3,
            reason: 'completions_view must contain exactly 3 rows after pull',
          );

          final refs = after.map((c) => c.sefariaRef).toSet();
          expect(
            refs,
            {'Berakhot 1a', 'Berakhot 2a', 'Berakhot 3a'},
            reason: 'all three pulled sefariaRefs must be visible in the view',
          );

          // Verify profileId is correctly recorded on every row.
          expect(
            after.every((c) => c.profileId == profileId),
            isTrue,
            reason: 'all completions must be scoped to the correct profileId',
          );
        },
      );

      test(
        're-pull of the same documents is idempotent — no duplicates in completions_view',
        () async {
          final t0 = DateTime.utc(2026, 4, 1, 8, 0, 0);
          final doc = _firestoreCompletion(
            sefariaRef: 'Shabbat 10a',
            eventTimestamp: t0,
          );

          // Simulate two pulls of the same document (network retry / re-launch).
          await router.dispatch(
            profileId: profileId,
            kind: EntityKind.completion,
            rows: [doc],
          );
          await router.dispatch(
            profileId: profileId,
            kind: EntityKind.completion,
            rows: [doc],
          );

          final after = await db.completionDao.getCompletionsByProfile(
            profileId,
          );
          expect(
            after.where((c) => c.sefariaRef == 'Shabbat 10a').length,
            1,
            reason:
                'INSERT OR IGNORE must collapse duplicate pull into one row',
          );
        },
      );
    },
  );
}
