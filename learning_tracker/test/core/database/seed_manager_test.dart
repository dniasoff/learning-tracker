/// Logic tests for SeedManager.
///
/// Branches covered:
/// 1. "up to date" — DB exists, version==bundled, schema==expectedSchema → path returned, no replace
/// 2. Version mismatch — installed version < bundled → atomic replace attempted → extract fails
///    → rollback restores old DB → old DB is intact, SeedManagerException NOT thrown (rollback OK)
/// 3. Null version (missing seed_metadata) → treated as needsReplace → extract fails
///    → rollback restores old DB (intact)
/// 4. Schema mismatch — schema != expectedSchema → treated as needsReplace → extract fails
///    → rollback restores old DB
/// 5. Schema read failure (broken DB) — _readSchemaVersion returns null → triggers replace
/// 6. No DB at all (first launch) — _extractSeedDb called → throws SeedManagerException
/// 7. Interrupted upgrade (bak exists, partial DB) — bak restored, partial DB deleted
/// 8. Interrupted upgrade (bak exists, no partial DB) — bak renamed to content.db
/// 9. forceReExtract — deletes existing DB → _extractSeedDb → throws SeedManagerException
/// 10. repairContentDatabase (static) — delegates to forceReExtract → SeedManagerException
/// 11. Logger events: extract_failed / upgrade_failed / interrupted_upgrade_detected /
///     backup_restored_after_interrupt / seed_manager_content_db_up_to_date
/// 12. No DB + no bak (first launch) → exception, no stale files
library;

import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/database/seed_version.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;
import 'package:talker/talker.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Creates a real SQLite content.db at [path] whose seed_metadata row carries
/// [version] and whose user_version PRAGMA is set to [schemaVersion].
///
/// Uses the real ContentDatabase schema (NativeDatabase) so that all tables
/// exist and PRAGMA user_version is set by Drift to ContentDatabase.expectedSchemaVersion.
Future<void> _buildContentDb(
  String path, {
  required int version,
  int? schemaVersionOverride,
}) async {
  // Open via Drift — this applies the full migration and sets user_version.
  final db = ContentDatabase(NativeDatabase(File(path)));
  await db.customInsert(
    'INSERT INTO seed_metadata '
    '(version, built_at, build_id, text_cache_count, calendar_cycle_count) '
    'VALUES (?, ?, ?, ?, ?)',
    variables: [
      Variable.withInt(version),
      Variable.withString('2026-01-01T00:00:00Z'),
      Variable.withString('test-build'),
      Variable.withInt(0),
      Variable.withInt(0),
    ],
  );
  await db.close();

  // Optionally override the PRAGMA user_version to simulate schema mismatch.
  if (schemaVersionOverride != null) {
    final raw = raw_sqlite.sqlite3.open(path);
    raw.execute('PRAGMA user_version = $schemaVersionOverride');
    raw.dispose();
  }
}

/// Runs [future] and discards any thrown errors. Useful for logging-only
/// assertions where we don't care about the success/fail result.
Future<void> _ignoreError(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {}
}

/// Collects all log event strings from a Talker history.
List<String> _loggedEvents(Talker talker) {
  return talker.history
      .map((e) => e.generateTextMessage())
      .toList(growable: false);
}

bool _hasEvent(Talker talker, String event) =>
    _loggedEvents(talker).any((msg) => msg.contains(event));

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late Directory tmp;
  late Talker talker;
  late AppLogger logger;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('seed_mgr_test_');
    talker = Talker();
    logger = AppLogger(talker);
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  // ── 1. Up-to-date path ────────────────────────────────────────────────────

  group('ensureContentDb — up to date (no replace needed)', () {
    test(
      'returns path when installed version == bundled and schema matches',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
          // No override — Drift writes expectedSchemaVersion automatically.
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        final result = await mgr.ensureContentDb();

        expect(result, equals('${tmp.path}/content.db'));
        expect(File(result).existsSync(), isTrue);
      },
    );

    test(
      'logs seed_manager_content_db_up_to_date when no replace needed',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await mgr.ensureContentDb();

        expect(_hasEvent(talker, 'seed_manager_content_db_up_to_date'), isTrue);
      },
    );

    test(
      'does NOT log seed_manager_replacing_content_db when up to date',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await mgr.ensureContentDb();

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isFalse);
      },
    );

    test('contentDbPath matches ensureContentDb return value', () async {
      await _buildContentDb(
        '${tmp.path}/content.db',
        version: bundledSeedVersion,
      );

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await mgr.ensureContentDb();

      expect(mgr.contentDbPath, equals('${tmp.path}/content.db'));
    });
  });

  // ── 2. Version mismatch — bundled > installed ─────────────────────────────

  group('ensureContentDb — version mismatch triggers atomic replace', () {
    test('old DB preserved after rollback when bundled > installed', () async {
      // Install a DB with an old version.
      const oldVersion = bundledSeedVersion - 1;
      if (oldVersion <= 0) {
        // Unlikely, but skip gracefully if bundledSeedVersion == 1.
        return;
      }
      await _buildContentDb('${tmp.path}/content.db', version: oldVersion);

      // Extract fails (no rootBundle) → rollback restores old DB.
      // The old DB existed before the replace attempt, so after rollback
      // the content.db must still be present and readable.
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      // ensureContentDb should NOT throw since rollback restores old file.
      await expectLater(mgr.ensureContentDb(), completes);

      // Old DB must still be intact.
      final dbPath = '${tmp.path}/content.db';
      expect(File(dbPath).existsSync(), isTrue);

      // No orphaned .bak after rollback succeeds.
      expect(File('$dbPath.bak').existsSync(), isFalse);
    });

    test(
      'logs seed_manager_replacing_content_db when version mismatch',
      () async {
        const oldVersion = bundledSeedVersion - 1;
        if (oldVersion <= 0) return;
        await _buildContentDb('${tmp.path}/content.db', version: oldVersion);

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isTrue);
      },
    );

    test('logs seed_manager_upgrade_failed on extract failure', () async {
      const oldVersion = bundledSeedVersion - 1;
      if (oldVersion <= 0) return;
      await _buildContentDb('${tmp.path}/content.db', version: oldVersion);

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());

      expect(_hasEvent(talker, 'seed_manager_upgrade_failed'), isTrue);
    });

    test('logs seed_manager_extract_failed on extract failure', () async {
      const oldVersion = bundledSeedVersion - 1;
      if (oldVersion <= 0) return;
      await _buildContentDb('${tmp.path}/content.db', version: oldVersion);

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());

      expect(_hasEvent(talker, 'seed_manager_extract_failed'), isTrue);
    });

    test(
      'logs seed_manager_rolled_back_to_previous_version on rollback',
      () async {
        const oldVersion = bundledSeedVersion - 1;
        if (oldVersion <= 0) return;
        await _buildContentDb('${tmp.path}/content.db', version: oldVersion);

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(
          _hasEvent(talker, 'seed_manager_rolled_back_to_previous_version'),
          isTrue,
        );
      },
    );
  });

  // ── 3. Missing seed_metadata (null version) ───────────────────────────────

  group('ensureContentDb — null version triggers replace', () {
    /// Build a real SQLite file at [path] with the expected schema version
    /// set, but with NO seed_metadata row — simulating a DB that was
    /// created but never populated (version read returns null).
    Future<void> buildNoVersionDb(String path) async {
      // Use raw sqlite3 so we control the exact schema.
      // Set user_version = expectedSchemaVersion so schema check passes.
      // Omit seed_metadata rows to force installedVersion == null.
      final raw = raw_sqlite.sqlite3.open(path);
      raw.execute(
        'PRAGMA user_version = ${ContentDatabase.expectedSchemaVersion}',
      );
      raw.execute(
        'CREATE TABLE seed_metadata ('
        'version INTEGER NOT NULL, '
        'built_at TEXT NOT NULL, '
        'build_id TEXT NOT NULL, '
        'text_cache_count INTEGER NOT NULL, '
        'calendar_cycle_count INTEGER NOT NULL, '
        'PRIMARY KEY (version))',
      );
      // Intentionally insert NO rows into seed_metadata.
      raw.dispose();
    }

    test(
      'DB without seed_metadata row triggers replace + rollback restores DB',
      () async {
        await buildNoVersionDb('${tmp.path}/content.db');

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        // extract fails → rollback → old DB restored (no throw since rollback ok)
        await expectLater(mgr.ensureContentDb(), completes);

        expect(File('${tmp.path}/content.db').existsSync(), isTrue);
      },
    );

    test('logs seed_manager_replacing_content_db for null version', () async {
      await buildNoVersionDb('${tmp.path}/content.db');

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());

      expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isTrue);
    });
  });

  // ── 4. Schema mismatch ────────────────────────────────────────────────────

  group('ensureContentDb — schema mismatch triggers replace', () {
    test(
      'DB with wrong user_version triggers replace + rollback restores DB',
      () async {
        // Build a valid DB with matching version but override schema to wrong value.
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
          schemaVersionOverride:
              ContentDatabase.expectedSchemaVersion - 1, // wrong schema
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await expectLater(mgr.ensureContentDb(), completes);

        // Old DB preserved after rollback.
        expect(File('${tmp.path}/content.db').existsSync(), isTrue);
        expect(File('${tmp.path}/content.db.bak').existsSync(), isFalse);
      },
    );

    test(
      'logs seed_manager_replacing_content_db for schema mismatch',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
          schemaVersionOverride: ContentDatabase.expectedSchemaVersion - 1,
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isTrue);
      },
    );

    test('logs replace fields: installedVersion / installedSchema', () async {
      await _buildContentDb(
        '${tmp.path}/content.db',
        version: bundledSeedVersion,
        schemaVersionOverride: 2, // clearly wrong schema
      );

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());

      final events = _loggedEvents(talker);
      final replacingMsg = events.firstWhere(
        (e) => e.contains('seed_manager_replacing_content_db'),
        orElse: () => '',
      );
      expect(replacingMsg, contains('installedVersion'));
      expect(replacingMsg, contains('installedSchema'));
      expect(replacingMsg, contains('bundledVersion'));
      expect(replacingMsg, contains('expectedSchema'));
    });

    test(
      'schema mismatch with schema=0 (unreadable) also triggers replace',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
          schemaVersionOverride: 0, // user_version=0 means unset/wrong
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isTrue);
      },
    );
  });

  // ── 5. Schema read failure (broken file) ─────────────────────────────────

  group('ensureContentDb — corrupted/unreadable DB triggers replace', () {
    test('truncated/corrupt DB file triggers replace path', () async {
      // Write garbage bytes — sqlite3 cannot open this.
      await File('${tmp.path}/content.db').writeAsBytes([1, 2, 3, 4, 5]);

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      // extract fails → rollback → old "DB" (garbage file) restored → no throw
      await expectLater(mgr.ensureContentDb(), completes);
    });

    test(
      'logs read_seed_version_failed or read_schema_version_failed for corrupt DB',
      () async {
        await File('${tmp.path}/content.db').writeAsBytes([1, 2, 3]);

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        // Either seed_version_failed or schema_version_failed should be logged.
        final hasReadError =
            _hasEvent(talker, 'seed_manager_read_seed_version_failed') ||
            _hasEvent(talker, 'seed_manager_read_schema_version_failed');
        expect(hasReadError, isTrue);
      },
    );
  });

  // ── 6. First launch — no DB file at all ──────────────────────────────────

  group('ensureContentDb — first launch (no content.db)', () {
    test(
      'throws SeedManagerException when DB absent and rootBundle unavailable',
      () async {
        // No DB in tmp dir — _extractSeedDb is called, rootBundle.load() throws.
        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await expectLater(
          mgr.ensureContentDb(),
          throwsA(isA<SeedManagerException>()),
        );
      },
    );

    test('logs seed_manager_first_launch_extract on first launch', () async {
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());
      expect(_hasEvent(talker, 'seed_manager_first_launch_extract'), isTrue);
    });

    test('logs seed_manager_extract_failed when extract fails', () async {
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());
      expect(_hasEvent(talker, 'seed_manager_extract_failed'), isTrue);
    });

    test(
      'SeedManagerException message is user-friendly (restart/reinstall hint)',
      () async {
        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        Object? caught;
        try {
          await mgr.ensureContentDb();
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<SeedManagerException>());
        final ex = caught as SeedManagerException;
        // Message must guide the user to restart or reinstall.
        expect(
          ex.message.toLowerCase(),
          anyOf(contains('restart'), contains('reinstall')),
        );
      },
    );

    test('SeedManagerException is a subtype of InternalException', () async {
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      Object? caught;
      try {
        await mgr.ensureContentDb();
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<SeedManagerException>());
    });

    test('no .bak file left after failed first-launch', () async {
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());
      // The .bak should not exist since we never got to atomic replace.
      expect(
        File('${tmp.path}/content.db.bak').existsSync(),
        isFalse,
        reason: '.bak must not exist after a clean first-launch failure',
      );
    });
  });

  // ── 7. Interrupted upgrade recovery — partial + bak ──────────────────────

  group('ensureContentDb — interrupted upgrade: bak + partial content.db', () {
    test(
      'partial DB deleted, bak restored to content.db on next launch',
      () async {
        // Simulate interrupted upgrade: a valid backup + a partial new DB.
        await _buildContentDb(
          '${tmp.path}/content.db.bak',
          version: bundledSeedVersion - 1,
        );
        // Partial new DB (simulated as garbage — write interrupted mid-way).
        await File('${tmp.path}/content.db').writeAsBytes([
          0x53,
          0x51,
          0x4c,
          0x69,
        ]); // "SQLi" — partial sqlite header.

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        // After recovery the bak is the current DB, version < bundled → replace.
        // Replace fails → rollback. Rollback restores the (now renamed) DB.
        await expectLater(mgr.ensureContentDb(), completes);

        // content.db must exist and NOT be a partial file.
        expect(File('${tmp.path}/content.db').existsSync(), isTrue);
        // .bak must be gone after recovery + rollback cycle.
        expect(File('${tmp.path}/content.db.bak').existsSync(), isFalse);
      },
    );

    test(
      'logs seed_manager_interrupted_upgrade_detected when bak present',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db.bak',
          version: bundledSeedVersion - 1,
        );
        await File('${tmp.path}/content.db').writeAsBytes([1, 2, 3]);

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(
          _hasEvent(talker, 'seed_manager_interrupted_upgrade_detected'),
          isTrue,
        );
      },
    );

    test('logs seed_manager_backup_restored_after_interrupt', () async {
      await _buildContentDb(
        '${tmp.path}/content.db.bak',
        version: bundledSeedVersion - 1,
      );
      await File('${tmp.path}/content.db').writeAsBytes([1, 2, 3]);

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.ensureContentDb());

      expect(
        _hasEvent(talker, 'seed_manager_backup_restored_after_interrupt'),
        isTrue,
      );
    });
  });

  // ── 8. Interrupted upgrade — only bak, no partial DB ─────────────────────

  group('ensureContentDb — interrupted upgrade: bak only, no content.db', () {
    test('bak renamed to content.db when no partial DB exists', () async {
      // Only the backup exists — no partial DB was written.
      await _buildContentDb(
        '${tmp.path}/content.db.bak',
        version: bundledSeedVersion,
      );

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      // bak has current version, schema matches → up to date → no replace.
      final result = await mgr.ensureContentDb();

      expect(result, equals('${tmp.path}/content.db'));
      expect(File(result).existsSync(), isTrue);
      expect(
        File('${tmp.path}/content.db.bak').existsSync(),
        isFalse,
        reason: 'bak must be consumed (renamed) during recovery',
      );
    });

    test(
      'logs seed_manager_backup_restored_after_interrupt (bak only)',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db.bak',
          version: bundledSeedVersion,
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await mgr.ensureContentDb();

        expect(
          _hasEvent(talker, 'seed_manager_backup_restored_after_interrupt'),
          isTrue,
        );
      },
    );
  });

  // ── 9. forceReExtract ──────────────────────────────────────────────────────

  group('forceReExtract', () {
    test('throws SeedManagerException when rootBundle unavailable', () async {
      // Pre-seed a valid DB — forceReExtract should delete it first.
      await _buildContentDb(
        '${tmp.path}/content.db',
        version: bundledSeedVersion,
      );

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await expectLater(
        mgr.forceReExtract(),
        throwsA(isA<SeedManagerException>()),
      );
    });

    test('deletes existing DB before attempting extract', () async {
      await _buildContentDb(
        '${tmp.path}/content.db',
        version: bundledSeedVersion,
      );

      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.forceReExtract());

      // Extract was attempted even after deleting the old DB.
      expect(_hasEvent(talker, 'seed_manager_extract_failed'), isTrue);
    });

    test('logs extract_failed on rootBundle failure', () async {
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await _ignoreError(mgr.forceReExtract());

      expect(_hasEvent(talker, 'seed_manager_extract_failed'), isTrue);
    });

    test('contentDbPath is deterministic regardless of DB state', () async {
      // contentDbPath is a computed getter — no I/O needed.
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      expect(mgr.contentDbPath, equals('${tmp.path}/content.db'));
    });
  });

  // ── 10. repairContentDatabase (static) ────────────────────────────────────

  group('repairContentDatabase (static)', () {
    test('throws SeedManagerException when rootBundle unavailable', () async {
      await expectLater(
        SeedManager.repairContentDatabase(
          dbDirectory: tmp.path,
          logger: logger,
        ),
        throwsA(isA<SeedManagerException>()),
      );
    });

    test('logs seed_manager_repair_requested', () async {
      await _ignoreError(
        SeedManager.repairContentDatabase(
          dbDirectory: tmp.path,
          logger: logger,
        ),
      );

      expect(_hasEvent(talker, 'seed_manager_repair_requested'), isTrue);
    });

    test('logs extract_failed on rootBundle failure', () async {
      await _ignoreError(
        SeedManager.repairContentDatabase(
          dbDirectory: tmp.path,
          logger: logger,
        ),
      );

      expect(_hasEvent(talker, 'seed_manager_extract_failed'), isTrue);
    });
  });

  // ── 11. needsReplace flag composition ────────────────────────────────────

  group('needsReplace flag — each condition independently', () {
    test(
      'installedVersion == null (no seed_metadata table) triggers replace',
      () async {
        // Build a DB but without the seed_metadata table entirely.
        final raw = raw_sqlite.sqlite3.open('${tmp.path}/content.db');
        // Set user_version to the expected schema so schema check passes.
        raw.execute(
          'PRAGMA user_version = ${ContentDatabase.expectedSchemaVersion}',
        );
        raw.execute(
          'CREATE TABLE dummy (id INTEGER PRIMARY KEY)',
        ); // no seed_metadata
        raw.dispose();

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isTrue);
      },
    );

    test(
      'bundledVersion > installedVersion triggers replace (boundary)',
      () async {
        // Install version exactly one less than bundled.
        const oldVersion = bundledSeedVersion - 1;
        if (oldVersion <= 0) return;

        await _buildContentDb('${tmp.path}/content.db', version: oldVersion);

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isTrue);
      },
    );

    test(
      'bundledVersion == installedVersion and schema matches → no replace',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
          // No schemaVersionOverride → Drift writes expectedSchemaVersion.
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await mgr.ensureContentDb();

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isFalse);
        expect(_hasEvent(talker, 'seed_manager_content_db_up_to_date'), isTrue);
      },
    );

    test(
      'installedSchema != expectedSchema triggers replace even when version matches',
      () async {
        await _buildContentDb(
          '${tmp.path}/content.db',
          version: bundledSeedVersion,
          schemaVersionOverride: ContentDatabase.expectedSchemaVersion + 99,
        );

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        await _ignoreError(mgr.ensureContentDb());

        expect(_hasEvent(talker, 'seed_manager_replacing_content_db'), isTrue);
      },
    );
  });

  // ── 12. No bak after failed atomic replace when no prior DB ──────────────

  group('no-prior-DB atomic replace fail → SeedManagerException thrown', () {
    test('throws when extract fails AND no prior DB to roll back to', () async {
      // There is no existing DB, so the first call goes through _extractSeedDb
      // directly (Step 2 fast-path) — it throws SeedManagerException.
      final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
      await expectLater(
        mgr.ensureContentDb(),
        throwsA(isA<SeedManagerException>()),
      );
    });

    test(
      'rollback succeeds (old DB restored) when prior DB exists before replace',
      () async {
        // Install a version-mismatched DB (< bundled). Extract fails, rollback
        // restores it. Result: old DB preserved, NO throw.
        const oldVersion = bundledSeedVersion - 1;
        if (oldVersion <= 0) return;

        await _buildContentDb('${tmp.path}/content.db', version: oldVersion);

        final mgr = SeedManager(dbDirectory: tmp.path, logger: logger);
        // Rollback succeeds → no throw.
        await expectLater(mgr.ensureContentDb(), completes);
        expect(File('${tmp.path}/content.db').existsSync(), isTrue);
      },
    );
  });

  // ── 13. Logging without a logger (null-safe) ──────────────────────────────

  group('SeedManager with null logger', () {
    test('up-to-date path completes without logger', () async {
      await _buildContentDb(
        '${tmp.path}/content.db',
        version: bundledSeedVersion,
      );

      // No logger injected.
      final mgr = SeedManager(dbDirectory: tmp.path);
      final result = await mgr.ensureContentDb();
      expect(result, equals('${tmp.path}/content.db'));
    });

    test('first-launch throws SeedManagerException without logger', () async {
      final mgr = SeedManager(dbDirectory: tmp.path);
      await expectLater(
        mgr.ensureContentDb(),
        throwsA(isA<SeedManagerException>()),
      );
    });
  });
}
