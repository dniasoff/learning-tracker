// AUD-settings-04 (DB-3) regression coverage.
//
// importData()'s 16 per-table import loops used to insert rows one at a
// time via an awaited `_database.into(table).insert(...)` inside a `for`
// loop — every row paid its own SQL round trip even though the whole
// method already runs inside one `_database.transaction()`. The fix
// collects each table's rows into a list and writes them with a single
// `_database.batch((b) => b.insertAll(table, rows))` call instead.
//
// This is verified at the real Drift/SQLite level (not a mocked
// collaborator) via a [QueryInterceptor] that counts single-row
// [QueryInterceptor.runInsert] calls versus batched
// [QueryInterceptor.runBatched] calls while importing a large
// `completionEvents` fixture — completionEvents is the table the finding
// calls out by name (years of daily completions is the realistic case a
// per-row loop multiplies import wall-clock time on).
//
// Before the fix this test fails: a per-row loop produces one runInsert
// call per row (rowCount), so `insertCallsDuringImport` is NOT `lessThan
// (rowCount)`. After the fix, the whole `completionEvents` section is
// written via a single runBatched call and `insertCallsDuringImport`
// stays at 0.
import 'dart:convert';

import 'package:drift/drift.dart'
    show ApplyInterceptor, BatchedStatements, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

import '../../../../helpers/data_export_fixtures.dart';
import '../../../../helpers/drift_memory.dart';

/// Counts single-row INSERT statements ([runInsert]) versus batched
/// statement groups ([runBatched]) flowing through the executor.
///
/// A per-row awaited insert loop produces one [runInsert] call per row.
/// `batch()`/`insertAll` collapses same-shape rows into a single
/// [runBatched] call carrying every row's argument set (see
/// `package:drift/src/runtime/api/batch.dart` — `Batch._runWith` calls
/// `executor.runBatched(...)` exactly once per `batch()` invocation).
class _InsertCountInterceptor extends QueryInterceptor {
  int insertCalls = 0;
  int batchedCalls = 0;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    insertCalls++;
    return executor.runInsert(statement, args);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    batchedCalls++;
    return executor.runBatched(statements);
  }
}

void main() {
  late UserDatabase db;
  late DataExportImportService service;
  late _InsertCountInterceptor interceptor;

  setUp(() async {
    interceptor = _InsertCountInterceptor();
    db = UserDatabase(NativeDatabase.memory().interceptWith(interceptor));
    service = DataExportImportService(
      database: db,
      appVersionFetcher: () async => '1.0.0',
    );
    // seedProfile's 2 inserts (accounts + learnerProfiles) run through the
    // same intercepted db — captured as the baseline below so the
    // assertions only measure importData()'s own statements.
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  group(
    'DataExportImportService.importData — batched inserts (AUD-settings-04, DB-3)',
    () {
      test('imports 1,200 completionEvents rows via batch()/insertAll, not a '
          'per-row awaited insert loop', () async {
        const rowCount = 1200;
        final payload = exportPayloadMap()
          ..['completionEvents'] = [
            for (var i = 0; i < rowCount; i++)
              {
                'profileId': 1,
                'curriculumId': 'bavli',
                'sefariaRef': 'Berakhot.${i}a',
                'stageId': 1,
                'trackType': 'personal',
                'trackId': 1,
                'eventTimestamp': '2026-03-01T00:00:00.000Z',
                'createdAt': '2026-03-01T00:00:00.000Z',
                'points': 5,
              },
          ];
        final jsonString = jsonEncode(payload);

        final baselineInsertCalls = interceptor.insertCalls;
        final baselineBatchedCalls = interceptor.batchedCalls;

        await service.importData(jsonString);

        final insertCallsDuringImport =
            interceptor.insertCalls - baselineInsertCalls;
        final batchedCallsDuringImport =
            interceptor.batchedCalls - baselineBatchedCalls;

        // Sanity: the rows actually landed.
        final events = await db.select(db.completionEvents).get();
        expect(events, hasLength(rowCount));

        // The defect: a per-row awaited insert loop issues `rowCount`
        // individual runInsert calls. The fix issues zero — the whole
        // section goes through one runBatched call instead.
        expect(
          insertCallsDuringImport,
          lessThan(rowCount),
          reason:
              'importData() must not issue one runInsert call per row '
              '(DB-3) — expected a bounded number of calls via '
              'batch()/insertAll, got $insertCallsDuringImport for '
              '$rowCount rows',
        );
        expect(
          batchedCallsDuringImport,
          greaterThan(0),
          reason:
              'importData() should route the completionEvents insert '
              'through _database.batch()/insertAll',
        );
      });
    },
  );
}
