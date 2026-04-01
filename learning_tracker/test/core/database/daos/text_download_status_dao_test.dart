import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('TextDownloadStatusDao', () {
    const curriculumId = 'mishnayos';

    test('isDownloaded returns false for unknown curriculum', () async {
      final result = await db.textDownloadStatusDao.isDownloaded(curriculumId);
      expect(result, isFalse);
    });

    test('markDownloaded stores status', () async {
      await db.textDownloadStatusDao.markDownloaded(
        curriculumId: curriculumId,
        itemCount: 4219,
        textVersion: '1.0.0',
      );

      final status = await db.textDownloadStatusDao.getStatus(curriculumId);
      expect(status, isNotNull);
      expect(status!.curriculumId, curriculumId);
      expect(status.itemCount, 4219);
      expect(status.textVersion, '1.0.0');
    });

    test('isDownloaded returns true after markDownloaded', () async {
      await db.textDownloadStatusDao.markDownloaded(
        curriculumId: curriculumId,
        itemCount: 100,
        textVersion: '1.0.0',
      );

      final result = await db.textDownloadStatusDao.isDownloaded(curriculumId);
      expect(result, isTrue);
    });

    test('clearDownloadStatus removes the record', () async {
      await db.textDownloadStatusDao.markDownloaded(
        curriculumId: curriculumId,
        itemCount: 100,
        textVersion: '1.0.0',
      );

      await db.textDownloadStatusDao.clearDownloadStatus(curriculumId);

      final result = await db.textDownloadStatusDao.isDownloaded(curriculumId);
      expect(result, isFalse);
    });

    test('getStatus returns the status record', () async {
      await db.textDownloadStatusDao.markDownloaded(
        curriculumId: curriculumId,
        itemCount: 4219,
        textVersion: '2.0.0',
      );

      final status = await db.textDownloadStatusDao.getStatus(curriculumId);
      expect(status, isNotNull);
      expect(status!.curriculumId, curriculumId);
      expect(status.itemCount, 4219);
      expect(status.textVersion, '2.0.0');
      expect(status.downloadedAt, isA<DateTime>());
    });

    test('getStatus returns null for non-existent curriculum', () async {
      final status = await db.textDownloadStatusDao.getStatus('nonexistent');
      expect(status, isNull);
    });
  });
}
