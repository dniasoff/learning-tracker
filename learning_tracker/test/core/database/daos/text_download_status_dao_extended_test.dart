/// Extended tests for TextDownloadStatusDao covering savePartialProgress
/// and getPartialItemCount — methods not covered by the existing test.
library;

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

  const curriculumId = 'mishnayos';

  // ── savePartialProgress ───────────────────────────────────────────────────

  group('TextDownloadStatusDao.savePartialProgress', () {
    test('stores storedItemCount for a curriculum', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 250,
      );

      final status = await db.textDownloadStatusDao.getStatus(curriculumId);
      expect(status, isNotNull);
      expect(status!.storedItemCount, 250);
    });

    test('updates storedItemCount when called again', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 100,
      );
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 500,
      );

      final status = await db.textDownloadStatusDao.getStatus(curriculumId);
      expect(status!.storedItemCount, 500);
    });

    test('partial progress creates an entry with itemCount=0 and empty version',
        () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 50,
      );

      final status = await db.textDownloadStatusDao.getStatus(curriculumId);
      expect(status!.itemCount, 0);
      expect(status.textVersion, '');
    });

    test('marking downloaded after partial progress updates the record', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 1000,
      );

      await db.textDownloadStatusDao.markDownloaded(
        curriculumId: curriculumId,
        itemCount: 4219,
        textVersion: '2.0.0',
      );

      final status = await db.textDownloadStatusDao.getStatus(curriculumId);
      expect(status!.itemCount, 4219);
      expect(status.textVersion, '2.0.0');
    });
  });

  // ── getPartialItemCount ───────────────────────────────────────────────────

  group('TextDownloadStatusDao.getPartialItemCount', () {
    test('returns null when no record exists', () async {
      final count = await db.textDownloadStatusDao.getPartialItemCount(
        curriculumId,
      );
      expect(count, isNull);
    });

    test('returns storedItemCount after savePartialProgress', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 750,
      );

      final count = await db.textDownloadStatusDao.getPartialItemCount(
        curriculumId,
      );
      expect(count, 750);
    });

    test('returns null storedItemCount when markDownloaded clears it', () async {
      // markDownloaded sets storedItemCount to null.
      await db.textDownloadStatusDao.markDownloaded(
        curriculumId: curriculumId,
        itemCount: 4219,
        textVersion: '1.0.0',
      );

      final count = await db.textDownloadStatusDao.getPartialItemCount(
        curriculumId,
      );
      expect(count, isNull);
    });

    test('returns 0 storedItemCount when explicitly set to 0', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: curriculumId,
        storedItemCount: 0,
      );

      final count = await db.textDownloadStatusDao.getPartialItemCount(
        curriculumId,
      );
      expect(count, 0);
    });

    test('different curricula have independent partial progress', () async {
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: 'mishnayos',
        storedItemCount: 100,
      );
      await db.textDownloadStatusDao.savePartialProgress(
        curriculumId: 'bavli',
        storedItemCount: 200,
      );

      final mishnayosCount = await db.textDownloadStatusDao.getPartialItemCount(
        'mishnayos',
      );
      final bavliCount = await db.textDownloadStatusDao.getPartialItemCount(
        'bavli',
      );
      expect(mishnayosCount, 100);
      expect(bavliCount, 200);
    });
  });
}
