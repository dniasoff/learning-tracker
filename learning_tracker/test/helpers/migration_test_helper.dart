/// Migration test helper (Phase 0 harness).
///
/// Provides [openDbAtVersion] — a factory that creates an in-memory
/// [UserDatabase] pre-initialised with an old schema and a set
/// user_version so that Drift's migration runner fires when the
/// database is first opened.
///
/// Usage:
/// ```dart
/// final db = openDbAtVersion(15, _v15Schema());
/// addTearDown(db.close);
/// // DB is now at UserDatabase.schemaVersion (all migrations ran).
/// // Verify post-migration state:
/// final completions = await db.select(db.completionEvents).get();
/// ```
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

/// Opens an in-memory [UserDatabase] starting from [oldVersion].
///
/// The [setupSql] statements are executed against the raw SQLite database
/// before Drift takes over, establishing the schema for [oldVersion]. Drift
/// then detects the mismatch between [oldVersion] and [UserDatabase.schemaVersion]
/// and runs every migration step in between.
///
/// Passing an empty [setupSql] is valid — use it when you only want to verify
/// the end-state schema without exercising a specific migration path.
UserDatabase openDbAtVersion(int oldVersion, List<String> setupSql) {
  return UserDatabase(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = OFF');
        for (final stmt in setupSql) {
          if (stmt.trim().isNotEmpty) {
            db.execute(stmt);
          }
        }
        db.execute('PRAGMA user_version = $oldVersion');
      },
    ),
  );
}

// ── v15 full schema ──────────────────────────────────────────────────────────
//
// Includes every table that the v16→v17 migration touches (alterTable +
// orphan-cleanup queries), so migrating from v15 to the current version works
// correctly in an in-memory test database.
//
// FK constraints are intentionally absent — they are added by the v16→v17
// migration step via alterTable(TableMigration(...)). The setup runs with
// PRAGMA foreign_keys = OFF so SQLite accepts the data regardless.

/// SQL statements that create the v15 schema and seed test data for the
/// v15→v16 migration gate (add `derived_from_events` to completions + backfill).
List<String> v15SchemaForC1() => [
  // ── Core lookup tables (needed for orphan-cleanup JOIN) ───────────────────
  '''
  CREATE TABLE "accounts" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "email" TEXT NOT NULL UNIQUE,
    "firebase_uid" TEXT UNIQUE,
    "password_hash" TEXT,
    "tier" TEXT NOT NULL DEFAULT "localBorn",
    "display_name" TEXT NOT NULL DEFAULT "",
    "user_mode" TEXT NOT NULL DEFAULT "adult",
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE "learner_profiles" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "account_id" INTEGER NOT NULL,
    "display_name" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "avatar_index" INTEGER NOT NULL DEFAULT 0,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
  ''',
  // ── Track / progress tables ────────────────────────────────────────────────
  '''
  CREATE TABLE "curriculum_tracks" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "track_type" TEXT NOT NULL,
    "is_active" INTEGER NOT NULL DEFAULT 1,
    "activated_at" INTEGER NOT NULL,
    "deactivated_at" INTEGER,
    "pace_reset_date" INTEGER,
    "deleted_at" INTEGER
  )
  ''',
  '''
  CREATE TABLE "completions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "sefaria_ref" TEXT NOT NULL,
    "stage_id" INTEGER NOT NULL,
    "track_type" TEXT NOT NULL,
    "track_id" INTEGER NOT NULL REFERENCES "curriculum_tracks"("id"),
    "completed_at" INTEGER NOT NULL,
    "points" INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE "completion_events" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "sefaria_ref" TEXT NOT NULL,
    "stage_id" INTEGER NOT NULL,
    "track_type" TEXT NOT NULL,
    "event_timestamp" INTEGER NOT NULL,
    "created_at" INTEGER NOT NULL,
    "prior_mark_only" INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE "streak_events" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "event_type" TEXT NOT NULL,
    "day_utc" INTEGER NOT NULL,
    "event_timestamp" INTEGER NOT NULL,
    "client_device_id" TEXT,
    "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
  '''
  CREATE TABLE "learning_ledger" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "ulid" TEXT NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "unit_type" TEXT NOT NULL,
    "unit_identifier" TEXT NOT NULL,
    "unit_display_name_he" TEXT NOT NULL,
    "unit_display_name_en" TEXT NOT NULL,
    "track_type" TEXT NOT NULL,
    "track_id" INTEGER,
    "completed_at" INTEGER NOT NULL,
    "completion_number" INTEGER NOT NULL,
    "marked_by" INTEGER NOT NULL,
    "is_manual" INTEGER NOT NULL DEFAULT 0,
    "created_at" INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
  )
  ''',
  '''
  CREATE TABLE "bookmarks" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "track_id" INTEGER NOT NULL REFERENCES "curriculum_tracks"("id"),
    "sefaria_ref" TEXT NOT NULL,
    "updated_at" INTEGER NOT NULL,
    UNIQUE ("profile_id", "curriculum_id", "track_id")
  )
  ''',
  '''
  CREATE TABLE "goals" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "track_id" INTEGER NOT NULL REFERENCES "curriculum_tracks"("id"),
    "target_percent" REAL NOT NULL DEFAULT 100.0,
    "target_date" INTEGER,
    "description" TEXT NOT NULL DEFAULT "",
    "date_type" TEXT NOT NULL DEFAULT "gregorian",
    "goal_type" TEXT NOT NULL DEFAULT "deadline",
    "pace_value" INTEGER,
    "pace_unit" TEXT,
    "learning_unit" TEXT,
    "created_at" INTEGER NOT NULL,
    "updated_at" INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE "stage_definitions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "profile_id" INTEGER NOT NULL,
    "curriculum_id" TEXT NOT NULL,
    "track_id" INTEGER NOT NULL REFERENCES "curriculum_tracks"("id"),
    "stage_order" INTEGER NOT NULL,
    "stage_name" TEXT NOT NULL,
    "delay_days" INTEGER NOT NULL,
    "is_default" INTEGER NOT NULL DEFAULT 0,
    "schedule_type" TEXT NOT NULL DEFAULT "delay",
    "days_of_week" TEXT,
    "rolling_window_size" INTEGER,
    UNIQUE ("profile_id", "curriculum_id", "stage_order", "track_id")
  )
  ''',
  '''
  CREATE TABLE "sync_queue" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "operation_type" TEXT NOT NULL,
    "payload" TEXT NOT NULL,
    "queued_at" INTEGER NOT NULL,
    "retry_count" INTEGER NOT NULL DEFAULT 0,
    "last_error" TEXT
  )
  ''',
  // ── Seed: account + profile (required for orphan-cleanup JOIN) ────────────
  'INSERT INTO "accounts" VALUES (1, "seed@example.com", NULL, NULL, "localBorn", "Seed", "adult", 1000000, 1000000)',
  'INSERT INTO "learner_profiles" VALUES (1, 1, "Seed", "adult", 0, 1000000, 1000000)',
  // ── Seed: track so completions can reference it ────────────────────────────
  'INSERT INTO "curriculum_tracks" VALUES (1, 1, "bavli", "personal", 1, 1000000, NULL, NULL, NULL)',
  // Seed one completion with a matching event (should get derived=1 after backfill).
  'INSERT INTO "completions" VALUES (1, 1, "bavli", "Berakhot 2a", 1, "personal", 1, 1000000, 10)',
  // Seed one completion with NO matching event (should stay derived=0).
  'INSERT INTO "completions" VALUES (2, 1, "bavli", "Berakhot 2b", 1, "personal", 1, 1000001, 10)',
  // Seed the event for the first completion only.
  'INSERT INTO "completion_events" VALUES (1, 1, "bavli", "Berakhot 2a", 1, "personal", 1000000, 1000000, 0)',
];
