import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/active_curriculum_dao.dart';
import 'package:learning_tracker/core/database/daos/bookmark_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/completion_event_dao.dart';
import 'package:learning_tracker/core/database/daos/curriculum_scope_dao.dart';
import 'package:learning_tracker/core/database/daos/daily_plan_dao.dart';
import 'package:learning_tracker/core/database/daos/goal_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_ledger_dao.dart';
import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/daos/point_config_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/daos/profile_program_dao.dart';
import 'package:learning_tracker/core/database/daos/sacred_window_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/daos/streak_dao.dart';
import 'package:learning_tracker/core/database/daos/streak_event_dao.dart';
import 'package:learning_tracker/core/database/daos/study_day_config_dao.dart';
import 'package:learning_tracker/core/database/daos/sync_queue_dao.dart';
import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/daos/track_learning_order_dao.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/tables/accounts.dart';
import 'package:learning_tracker/core/database/tables/bookmarks.dart';
import 'package:learning_tracker/core/database/tables/completion_events.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/tables/curriculum_scopes.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/daily_plans.dart';
import 'package:learning_tracker/core/database/tables/goals.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';
import 'package:learning_tracker/core/database/tables/learning_ledger.dart';
import 'package:learning_tracker/core/database/tables/learning_order.dart';
import 'package:learning_tracker/core/database/tables/outbox_table.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/tables/profile_programs.dart';
import 'package:learning_tracker/core/database/tables/sacred_window_entries.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/tables/streak_events.dart';
import 'package:learning_tracker/core/database/tables/streaks.dart';
import 'package:learning_tracker/core/database/tables/study_day_configs.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';
import 'package:learning_tracker/core/database/tables/track_learning_order.dart';
import 'package:learning_tracker/core/database/views/completions_view.dart';
import 'package:learning_tracker/core/time/ulid.dart';

part 'user_database.g.dart';

/// Mutable database containing all user data.
///
/// Schema v1 (DNI-322, E25 wipe-install boundary):
/// - Tables renamed: UserProfiles → Accounts, Profiles → LearnerProfiles
/// - profileId is now required (no withDefault) on all profile-scoped tables
/// - Bookmarks uses trackId FK instead of trackType TEXT
/// - schemaVersion bumped to 12; all old migration steps deleted
///
/// This database uses standard Drift migrations and holds all user-generated
/// content: profiles, progress, configuration, streaks, and sync state.
/// It is the only database that accepts writes at runtime.
@DriftDatabase(
  tables: [
    Accounts,
    LearnerProfiles,
    CurriculumTracks,
    CurriculumScopes,
    ProfilePrograms,
    StageDefinitions,
    PointConfigs,
    StudyDayConfigs,
    Completions,
    CompletionEvents,
    DailyPlans,
    LearningLedger,
    Bookmarks,
    LearningOrder,
    TrackLearningOrder,
    Goals,
    Streaks,
    StreakEvents,
    SyncQueue,
    TextDownloadStatuses,
    Outbox,
    SacredWindowEntries,
  ],
  views: [CompletionsView],
  daos: [
    ActiveCurriculumDao,
    CurriculumScopeDao,
    CompletionDao,
    CompletionEventDao,
    DailyPlanDao,
    LearningLedgerDao,
    GoalDao,
    PointConfigDao,
    StageDao,
    BookmarkDao,
    LearningOrderDao,
    TrackLearningOrderDao,
    TrackDao,
    ProfileDao,
    UserProfileDao,
    StreakDao,
    StreakEventDao,
    SyncQueueDao,
    TextDownloadStatusDao,
    StudyDayConfigDao,
    ProfileProgramDao,
    OutboxDao,
    SacredWindowDao,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  @override
  int get schemaVersion => 22;

  // drift_dev cannot express WHERE in a Dart-defined view's `as()` body
  // (cascade `..where()` confuses the generator).  The auto-generated SQL for
  // completions_view therefore omits the filter.  We drop and recreate the
  // view with this explicit SQL both on fresh install and during migrations.
  static const _completionsViewSql =
      'CREATE VIEW completions_view AS '
      'SELECT id, profile_id, curriculum_id, sefaria_ref, stage_id, '
      'track_type, track_id, points, event_timestamp '
      'FROM completion_events '
      'WHERE purged_at IS NULL';

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // C2: enable FK enforcement on every connection open (connection-level).
      beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
      onCreate: (Migrator m) async {
        await m.createAll();
        // Replace the auto-generated completions_view (no WHERE) with the
        // filtered version.
        await customStatement('DROP VIEW IF EXISTS completions_view');
        await customStatement(_completionsViewSql);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 15) {
          await m.createTable(sacredWindowEntries);
        }

        // C1 (v15 → v16): add derived_from_events to completions; backfill
        // existing rows that already have a matching completion_events record.
        if (from < 16) {
          await m.addColumn(completions, completions.derivedFromEvents);
          await customStatement('''
            UPDATE completions
            SET derived_from_events = 1
            WHERE EXISTS (
              SELECT 1 FROM completion_events ce
              WHERE ce.profile_id  = completions.profile_id
                AND ce.sefaria_ref = completions.sefaria_ref
                AND ce.stage_id    = completions.stage_id
                AND ce.track_type  = completions.track_type
            )
          ''');
        }

        // C2 (v16 → v17): add profileId FKs via table-recreate (SQLite does
        // not support ALTER TABLE ADD CONSTRAINT). FK enforcement is off
        // during recreation so existing data is copied without validation;
        // orphan cleanup runs after.
        if (from < 17) {
          await customStatement('PRAGMA foreign_keys = OFF');
          // Recreate the tables that receive the new profileId FK using
          // Drift's alterTable (TableMigration) pattern:
          //   create new table → copy data → drop old → rename.
          // learner_profiles is the FK target and does not need recreation.
          await m.alterTable(TableMigration(completions));
          await m.alterTable(TableMigration(completionEvents));
          await m.alterTable(TableMigration(streakEvents));
          await m.alterTable(TableMigration(learningLedger));
          await m.alterTable(TableMigration(bookmarks));
          await m.alterTable(TableMigration(goals));
          await m.alterTable(TableMigration(stageDefinitions));
          // Delete orphaned rows whose profile no longer exists.
          for (final t in [
            'completions',
            'completion_events',
            'streak_events',
            'learning_ledger',
            'bookmarks',
            'goals',
            'stage_definitions',
          ]) {
            await customStatement(
              'DELETE FROM $t WHERE profile_id NOT IN '
              '(SELECT id FROM learner_profiles)',
            );
          }
          await customStatement('PRAGMA foreign_keys = ON');
        }

        // C3 (v17 → v18): add purgedAt tombstone column to completion_events.
        // Guard: when migrating from v15 via alterTable in v16→v17 the column
        // may already exist (Drift always recreates tables with the current
        // schema). SQLite has no ADD COLUMN IF NOT EXISTS, so we check first.
        if (from < 18) {
          final cols = await customSelect(
            'PRAGMA table_info(completion_events)',
          ).get();
          if (!cols.any((r) => r.data['name'] == 'purged_at')) {
            await m.addColumn(completionEvents, completionEvents.purgedAt);
          }
        }

        // I-5 (v18 → v19): add entityKey dedup column to sync_queue.
        if (from < 19) {
          await m.addColumn(syncQueue, syncQueue.entityKey);
          // Backfill index — SQLite requires a new CREATE UNIQUE INDEX.
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS sync_queue_entity_key '
            'ON sync_queue (entity_key)',
          );
        }

        // C1 (v19 → v20): add trackId to completion_events and backfill it
        // from the completions projection so view-based queries can filter by
        // track.  Also create completions_view (new at v20) with the
        // purged_at IS NULL guard applied via raw SQL — see _completionsViewSql.
        // C1 (v19 → v20): add trackId + points to completion_events; backfill
        // both from completions; create filtered completions_view.
        // Guard: alterTable at v17 recreates completion_events with the
        // current schema, so track_id / points may already exist when
        // migrating from v15, v16, or v17.
        if (from < 20) {
          final evtCols = await customSelect(
            'PRAGMA table_info(completion_events)',
          ).get();
          if (!evtCols.any((r) => r.data['name'] == 'track_id')) {
            await m.addColumn(completionEvents, completionEvents.trackId);
          }
          if (!evtCols.any((r) => r.data['name'] == 'points')) {
            await m.addColumn(completionEvents, completionEvents.points);
          }
          await customStatement('''
            UPDATE completion_events
            SET track_id = COALESCE(track_id, (
              SELECT c.track_id FROM completions c
              WHERE c.profile_id  = completion_events.profile_id
                AND c.sefaria_ref = completion_events.sefaria_ref
                AND c.stage_id    = completion_events.stage_id
                AND c.track_type  = completion_events.track_type
              LIMIT 1
            )),
            points = COALESCE(NULLIF(points, 0), (
              SELECT c.points FROM completions c
              WHERE c.profile_id  = completion_events.profile_id
                AND c.sefaria_ref = completion_events.sefaria_ref
                AND c.stage_id    = completion_events.stage_id
                AND c.track_type  = completion_events.track_type
              LIMIT 1
            ), 0)
          ''');
          await customStatement('DROP VIEW IF EXISTS completions_view');
          await customStatement(_completionsViewSql);
        }

        // Edit-track (v20 → v21): add supersededAt to stage_definitions so
        // in-progress review items keep their stage FK while new items pick
        // up the replacement stages.
        // Guard: alterTable at v17 recreates stage_definitions with the current
        // schema, so the column may already exist when migrating from ≤ v16.
        if (from < 21) {
          final stageCols = await customSelect(
            'PRAGMA table_info(stage_definitions)',
          ).get();
          if (!stageCols.any((r) => r.data['name'] == 'superseded_at')) {
            await m.addColumn(stageDefinitions, stageDefinitions.supersededAt);
          }
        }

        // B1 (v21 → v22): completion identity is per-curriculum — widen the
        // natural key unique index to include curriculum_id.
        // Widening a unique index cannot create collisions: existing rows are
        // unique on the 4-tuple; the 5-tuple is at least as discriminating.
        if (from < 22) {
          await customStatement(
            'DROP INDEX IF EXISTS completion_events_natural_key',
          );
          await customStatement(
            'CREATE UNIQUE INDEX completion_events_natural_key '
            'ON completion_events '
            '(profile_id, sefaria_ref, stage_id, track_type, curriculum_id)',
          );
          // NOTE: Pre-v22 outbox rows for completion entity_kind use a 4-component
          // entityKey ("profileId:sefariaRef:stageId:trackType"). New rows use 5
          // components with curriculumId. Updating pre-existing rows would require
          // JSON extraction in SQLite (non-trivial). Transitional rows produce a
          // harmless double-push on next drain (both SetOptions(merge:true));
          // they age out naturally as the outbox is drained.
        }
      },
    );
  }
}
