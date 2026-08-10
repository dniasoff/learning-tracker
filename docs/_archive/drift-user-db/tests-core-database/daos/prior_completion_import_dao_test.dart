import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() => db.close());

  PriorCompletionImportsCompanion makeImport({
    int profileId = 1,
    String curriculumId = 'mishnayos',
    String sefariaRef = 'Berakhot.1a',
    int stageId = 1,
    String trackType = 'personal',
    String source = 'bulkInTrack',
  }) => PriorCompletionImportsCompanion.insert(
    profileId: profileId,
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: trackType,
    source: source,
  );

  group('batchInsertImports', () {
    test('inserts single row and it is found via isImported', () async {
      await db.priorCompletionImportDao.batchInsertImports([makeImport()]);

      final found = await db.priorCompletionImportDao.isImported(
        profileId: 1,
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot.1a',
        stageId: 1,
        trackType: 'personal',
      );
      expect(found, isTrue);
    });

    test('inserts multiple rows without throwing', () async {
      final batch = [
        makeImport(sefariaRef: 'Berakhot.1a'),
        makeImport(sefariaRef: 'Berakhot.2a'),
      ];
      // Insert twice — insertOrIgnore should not throw even without a UNIQUE key.
      await db.priorCompletionImportDao.batchInsertImports(batch);
      await db.priorCompletionImportDao.batchInsertImports(batch);

      // No UNIQUE key on natural key fields, so both batches insert independently.
      final rows = await db.select(db.priorCompletionImports).get();
      expect(rows, hasLength(4));
    });
  });

  group('isImported', () {
    test('returns false when no row exists', () async {
      final found = await db.priorCompletionImportDao.isImported(
        profileId: 1,
        curriculumId: 'mishnayos',
        sefariaRef: 'missing.ref',
        stageId: 1,
        trackType: 'personal',
      );
      expect(found, isFalse);
    });

    test('does not match a different sefariaRef', () async {
      await db.priorCompletionImportDao.batchInsertImports([
        makeImport(sefariaRef: 'Berakhot.1a'),
      ]);

      final found = await db.priorCompletionImportDao.isImported(
        profileId: 1,
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot.2a',
        stageId: 1,
        trackType: 'personal',
      );
      expect(found, isFalse);
    });
  });

  group('deleteImportsForItem', () {
    test('removes all rows matching the item key', () async {
      await db.priorCompletionImportDao.batchInsertImports([
        makeImport(stageId: 1),
        makeImport(stageId: 2),
        makeImport(sefariaRef: 'OtherRef.1a'),
      ]);

      await db.priorCompletionImportDao.deleteImportsForItem(
        profileId: 1,
        sefariaRef: 'Berakhot.1a',
        curriculumId: 'mishnayos',
        trackType: 'personal',
      );

      final rows = await db.select(db.priorCompletionImports).get();
      // Only the OtherRef row survives — both stageId variants deleted.
      expect(rows, hasLength(1));
      expect(rows.first.sefariaRef, 'OtherRef.1a');
    });
  });

  group('deleteImport', () {
    test('removes exactly one row matching the full natural key', () async {
      await db.priorCompletionImportDao.batchInsertImports([
        makeImport(stageId: 1),
        makeImport(stageId: 2),
      ]);

      await db.priorCompletionImportDao.deleteImport(
        profileId: 1,
        curriculumId: 'mishnayos',
        sefariaRef: 'Berakhot.1a',
        stageId: 1,
        trackType: 'personal',
      );

      final rows = await db.select(db.priorCompletionImports).get();
      expect(rows, hasLength(1));
      expect(rows.first.stageId, 2);
    });

    test('is a no-op when the row does not exist', () async {
      await db.priorCompletionImportDao.batchInsertImports([makeImport()]);

      await db.priorCompletionImportDao.deleteImport(
        profileId: 1,
        curriculumId: 'mishnayos',
        sefariaRef: 'Nonexistent.1a',
        stageId: 1,
        trackType: 'personal',
      );

      final rows = await db.select(db.priorCompletionImports).get();
      expect(rows, hasLength(1));
    });
  });
}
