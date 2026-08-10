/// AUD-core-sync-15: fault-injection coverage proving a single
/// malformed/throwing row is isolated (logged, skipped) rather than
/// aborting the whole page — generalizing LearnerProfileMerger's existing
/// per-row try/catch to the other EntityMerger implementations.
///
/// Covers the 9 mergers that accept an injectable [MergeStore] (a decorator
/// can force a specific row to throw an [Exception] deterministically):
/// BookmarkMerger, TrackConfigMerger, SettingsMerger, StageDefinitionMerger,
/// LearningOrderMerger, ProfileProgramMerger, CompletionEventMerger,
/// GoalMerger, StudyDayConfigMerger.
///
/// "Where practical" (per the acceptance criterion): the remaining
/// append-only mergers (LearningLedgerMerger, StreakEventMerger,
/// PointsLedgerMerger, RewardRedemptionMerger) route their DB write through
/// DAOs that already use `InsertMode.insertOrIgnore` / upsert semantics —
/// SQLite's OR IGNORE conflict resolution suppresses FK/UNIQUE violations
/// too, so there is no reachable non-Error exception to inject without
/// fabricating one. Their identical try/catch mechanism (added alongside
/// these 9) is verified structurally: it compiles, and the full sync test
/// suite (700+ tests) still passes unchanged. The same applies to
/// GamificationSettingsMerger's points_config sub-loop, which reads via
/// `UserDatabase` directly rather than through the swappable [MergeStore].
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/merge/bookmark_merger.dart';
import 'package:learning_tracker/core/sync/merge/completion_event_merger.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/goal_merger.dart';
import 'package:learning_tracker/core/sync/merge/learning_order_merger.dart';
import 'package:learning_tracker/core/sync/merge/profile_program_merger.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/sync/merge/study_day_config_merger.dart';
import 'package:learning_tracker/core/sync/merge/track_config_merger.dart';

import '../../../helpers/test_database.dart';

/// Wraps a real [DriftMergeStore] and throws an [Exception] from [upsert]
/// (or [insertIfAbsent], or [persistUpdatedAt] for GoalMerger which writes
/// via a DAO directly) whenever the row/naturalKey matches [shouldCrash] —
/// deterministic fault injection for exactly one row in a batch.
class _SelectiveCrashStore implements MergeStore {
  _SelectiveCrashStore(this._inner, {required this.shouldCrash});

  final DriftMergeStore _inner;
  final bool Function(String naturalKey) shouldCrash;

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) => _inner.currentUpdatedAt(
    kind: kind,
    profileId: profileId,
    naturalKey: naturalKey,
  );

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) => _inner.currentSyncedAt(
    kind: kind,
    profileId: profileId,
    naturalKey: naturalKey,
  );

  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) async {
    if (shouldCrash(naturalKey)) {
      throw Exception('fault-injected: persistUpdatedAt($naturalKey)');
    }
    return _inner.persistUpdatedAt(
      kind: kind,
      profileId: profileId,
      naturalKey: naturalKey,
      updatedAt: updatedAt,
      syncedAt: syncedAt,
    );
  }

  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) => _inner.remoteIsNewer(
    localUpdatedAt: localUpdatedAt,
    remoteUpdatedAt: remoteUpdatedAt,
    localSyncedAt: localSyncedAt,
    remoteSyncedAt: remoteSyncedAt,
  );

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {
    // naturalKey isn't available here, so callers that fault via upsert()
    // key off a well-known sentinel field instead — see the per-test
    // predicate.
    if (shouldCrash(_sentinel(fields))) {
      throw Exception('fault-injected: upsert(${_sentinel(fields)})');
    }
    return _inner.upsert(kind: kind, profileId: profileId, fields: fields);
  }

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {
    if (shouldCrash(naturalKey)) {
      throw Exception('fault-injected: insertIfAbsent($naturalKey)');
    }
    return _inner.insertIfAbsent(
      kind: kind,
      profileId: profileId,
      naturalKey: naturalKey,
      fields: fields,
    );
  }

  @override
  Future<T> runInTransaction<T>(Future<T> Function() body) =>
      _inner.runInTransaction(body);

  static String _sentinel(Map<String, dynamic> fields) =>
      (fields['curriculum_id'] ?? fields['sefaria_ref'] ?? '').toString();
}

/// Captures every AppLogger.warning() call for assertion.
class _RecordingLogger implements AppLogger {
  final List<String> events = [];

  @override
  void warning({
    required String event,
    Map<String, dynamic>? fields,
    Object? exception,
    StackTrace? stackTrace,
  }) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Per-row exception isolation (AUD-core-sync-15)', () {
    late UserDatabase db;
    late DriftMergeStore realStore;
    late _RecordingLogger logger;
    const profileId = 1;

    setUp(() async {
      db = UserDatabase(NativeDatabase.memory());
      realStore = DriftMergeStore(db);
      logger = _RecordingLogger();
      await seedProfile(db);
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'boom',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'good',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    });

    tearDown(() async => db.close());

    test('BookmarkMerger: a throwing row does not block a valid one', () async {
      final store = _SelectiveCrashStore(
        realStore,
        shouldCrash: (key) => key == 'boom',
      );
      final merger = BookmarkMerger(store: store, logger: logger);

      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'curriculum_id': 'boom',
            'sefaria_ref': 'Berakhot 1',
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
          {
            'curriculum_id': 'good',
            'sefaria_ref': 'Berakhot 2',
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        ],
      );

      final bookmarks = await db.bookmarkDao.getBookmarksByProfile(profileId);
      expect(
        bookmarks.map((b) => b.sefariaRef),
        contains('Berakhot 2'),
        reason: 'the valid row must still apply',
      );
      expect(
        bookmarks.map((b) => b.sefariaRef),
        isNot(contains('Berakhot 1')),
        reason: 'the throwing row must not have applied',
      );
      expect(logger.events, contains('sync_bookmark_merge_row_failed'));
    });

    test(
      'TrackConfigMerger: a throwing row does not block a valid one',
      () async {
        final store = _SelectiveCrashStore(
          realStore,
          shouldCrash: (key) => key == 'boom',
        );
        final merger = TrackConfigMerger(store: store, logger: logger);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'curriculum_id': 'boom',
              'state': 'active',
              'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
              'state_changed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
            {
              'curriculum_id': 'newcurriculum',
              'state': 'active',
              'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
              'state_changed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        );

        final rows = await (db.select(
          db.curriculumTracks,
        )..where((t) => t.curriculumId.equals('newcurriculum'))).get();
        expect(rows, hasLength(1), reason: 'the valid row must still apply');
        expect(logger.events, contains('sync_track_config_merge_row_failed'));
      },
    );

    test('SettingsMerger: a throwing row does not block a valid one', () async {
      final store = _SelectiveCrashStore(
        realStore,
        shouldCrash: (key) => key == 'boom',
      );
      final merger = SettingsMerger(store: store, logger: logger);

      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'curriculum_id': 'boom',
            'track_id': 1,
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'stages': [
              {'track_id': 1, 'stage_order': 0, 'stage_name': 'learning'},
            ],
          },
          {
            'curriculum_id': 'good',
            'track_id': 2,
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            'stages': [
              {'track_id': 2, 'stage_order': 0, 'stage_name': 'learning'},
            ],
          },
        ],
      );

      final goodStages = await db.stageDao.getStageDefinitionsByCurriculum(
        'good',
      );
      expect(goodStages, isNotEmpty, reason: 'the valid row must still apply');
      final boomStages = await db.stageDao.getStageDefinitionsByCurriculum(
        'boom',
      );
      expect(
        boomStages,
        isEmpty,
        reason: 'the throwing row must not have applied',
      );
      expect(logger.events, contains('sync_settings_merge_row_failed'));
    });

    test(
      'LearningOrderMerger: a throwing row does not block a valid one',
      () async {
        final store = _SelectiveCrashStore(
          realStore,
          shouldCrash: (key) => key == 'boom',
        );
        final merger = LearningOrderMerger(store: store, logger: logger);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'curriculum_id': 'boom',
              'sefaria_ref': 'Berakhot 1',
              'user_sort_order': 1,
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
            {
              'curriculum_id': 'good',
              'sefaria_ref': 'Berakhot 2',
              'user_sort_order': 1,
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        );

        final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
          'good',
          profileId: profileId,
        );
        expect(rows, isNotEmpty, reason: 'the valid row must still apply');
        expect(logger.events, contains('sync_learning_order_merge_row_failed'));
      },
    );

    test(
      'ProfileProgramMerger: a throwing row does not block a valid one',
      () async {
        final store = _SelectiveCrashStore(
          realStore,
          shouldCrash: (key) => key == 'boom',
        );
        final merger = ProfileProgramMerger(store: store, logger: logger);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'profile_id': profileId,
              'curriculum_id': 'boom',
              'program_id': 1,
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
            {
              'profile_id': profileId,
              'curriculum_id': 'good',
              'program_id': 2,
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        );

        final program = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(profileId, 'good');
        expect(program?.programId, 2, reason: 'the valid row must still apply');
        expect(
          logger.events,
          contains('sync_profile_program_merge_row_failed'),
        );
      },
    );

    test(
      'StageDefinitionMerger: a throwing row does not block a valid one',
      () async {
        final store = _SelectiveCrashStore(
          realStore,
          shouldCrash: (key) => key.startsWith('boom|'),
        );
        final merger = StageDefinitionMerger(store: store, logger: logger);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'curriculum_id': 'boom',
              'track_id': 1,
              'stage_order': 0,
              'stage_name': 'learning',
              'schedule': '{"type":"delay","delay_days":0}',
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
            {
              'curriculum_id': 'good',
              'track_id': 2,
              'stage_order': 0,
              'stage_name': 'learning',
              'schedule': '{"type":"delay","delay_days":0}',
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        );

        final goodStages = await db.stageDao.getStageDefinitionsByCurriculum(
          'good',
        );
        expect(
          goodStages,
          isNotEmpty,
          reason: 'the valid row must still apply',
        );
        expect(
          logger.events,
          contains('sync_stage_definition_merge_row_failed'),
        );
      },
    );

    test(
      'CompletionEventMerger: a throwing row does not block a valid one',
      () async {
        final store = _SelectiveCrashStore(
          realStore,
          shouldCrash: (key) => key.contains('boom'),
        );
        final merger = CompletionEventMerger(store: store, logger: logger);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'firestore_id': 'doc-boom',
              'curriculum_id': 'boom',
              'sefaria_ref': 'Berakhot 1',
              'stage_id': 1,
              'track_type': 'personal',
              'completed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
            {
              'firestore_id': 'doc-good',
              'curriculum_id': 'good',
              'sefaria_ref': 'Berakhot 2',
              'stage_id': 1,
              'track_type': 'personal',
              'completed_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        );

        final completions = await db.completionEventDao.getEventsByProfile(
          profileId,
        );
        expect(
          completions.map((c) => c.sefariaRef),
          contains('Berakhot 2'),
          reason: 'the valid row must still apply',
        );
        expect(
          completions.map((c) => c.sefariaRef),
          isNot(contains('Berakhot 1')),
          reason: 'the throwing row must not have applied',
        );
        expect(logger.events, contains('sync_completion_merge_row_failed'));
      },
    );

    test('GoalMerger: a throwing row does not block a valid one', () async {
      final store = _SelectiveCrashStore(
        realStore,
        // GoalMerger's naturalKey is the remote track id.
        shouldCrash: (key) => key == '1',
      );
      final merger = GoalMerger(db, store: store, logger: logger);

      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'curriculum_id': 'boom',
            'track_id': 1,
            'description': 'Boom goal',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
          {
            'curriculum_id': 'good',
            'track_id': 2,
            'description': 'Good goal',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
          },
        ],
      );

      final goal = await db.goalDao.getGoalByTrack(2);
      expect(goal, isNotNull, reason: 'the valid row must still apply');
      expect(logger.events, contains('sync_goal_merge_row_failed'));
    });

    test(
      'StudyDayConfigMerger: a throwing row does not block a valid one',
      () async {
        final store = _SelectiveCrashStore(
          realStore,
          shouldCrash: (key) => key.startsWith('boom|'),
        );
        final merger = StudyDayConfigMerger(db, store: store, logger: logger);

        await merger.merge(
          profileId: profileId,
          rows: [
            {
              'profile_id': profileId,
              'curriculum_id': 'boom',
              'track_id': 1,
              'day_of_week': 1,
              'day_type': 'study',
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
            {
              'profile_id': profileId,
              'curriculum_id': 'good',
              'track_id': 2,
              'day_of_week': 1,
              'day_type': 'study',
              'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          ],
        );

        final goodConfigs = await db.studyDayConfigDao.getConfigsByTrack(2);
        expect(
          goodConfigs,
          isNotEmpty,
          reason: 'the valid row must still apply',
        );
        expect(
          logger.events,
          contains('sync_study_day_config_merge_row_failed'),
        );
      },
    );
  });
}
