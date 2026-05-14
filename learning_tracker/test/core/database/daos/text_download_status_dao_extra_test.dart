// Extra coverage for TextDownloadStatusDao — savePartialProgress &
// getPartialItemCount were not exercised by the baseline test file.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('TextDownloadStatusDao — partial progress', () {
    const curriculumId = 'bavli';

    test('savePartialProgress creates a row with storedItemCount', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 250,
      );

      final count =
          await db.textDownloadStatusDao.getPartialItemCount(curriculumId);
      expect(count, 250);
    });

    test('getPartialItemCount returns null when no row exists', () async {
      final count =
          await db.textDownloadStatusDao.getPartialItemCount('nonexistent');
      expect(count, isNull);
    });

    test(
      'savePartialProgress overwrites an existing row (upsert semantics)',
      () async {
        await db.textDownloadStatusDao.savePartialProgress(
          curriculumId: curriculumId,
          storedItemCount: 100,
        );
        await db.textDownloadStatusDao.savePartialProgress(
          curriculumId: curriculumId,
          storedItemCount: 300,
        );

        final count =
            await db.textDownloadStatusDao.getPartialItemCount(curriculumId);
        expect(count, 300);
      },
    );

    test(
      'savePartialProgress and markDownloaded share the same row (upsert)',
      () async {
        await db.textDownloadStatusDao.savePartialProgress(
          curriculumId: curriculumId,
          storedItemCount: 500,
        );
        // Completing the download replaces the partial row.
        await db.textDownloadStatusDao.markDownloaded(
          curriculumId: curriculumId,
          itemCount: 1000,
          textVersion: '2.0.0',
        );

        final status = await db.textDownloadStatusDao.getStatus(curriculumId);
        expect(status, isNotNull);
        expect(status!.itemCount, 1000);
        expect(status.textVersion, '2.0.0');
        // storedItemCount is null after a full download row (markDownloaded
        // sets it to null explicitly).
        expect(status.storedItemCount, isNull);
      },
    );

    test('getPartialItemCount returns null after clearDownloadStatus', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 123,
      );
      await db.textDownloadStatusDao.clearDownloadStatus(curriculumId);

      final count =
          await db.textDownloadStatusDao.getPartialItemCount(curriculumId);
      expect(count, isNull);
    });
  });
}
