import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/text_download_status.dart';

part 'text_download_status_dao.g.dart';

@DriftAccessor(tables: [TextDownloadStatuses])
class TextDownloadStatusDao extends DatabaseAccessor<AppDatabase>
    with _$TextDownloadStatusDaoMixin {
  TextDownloadStatusDao(super.db);

  /// Checks if text content has been downloaded for a curriculum.
  Future<bool> isDownloaded(String curriculumId) async {
    final row = await (select(
      textDownloadStatuses,
    )..where((t) => t.curriculumId.equals(curriculumId))).getSingleOrNull();
    return row != null;
  }

  /// Marks a curriculum's text content as downloaded.
  Future<void> markDownloaded({
    required String curriculumId,
    required int itemCount,
    required String textVersion,
  }) async {
    await into(textDownloadStatuses).insertOnConflictUpdate(
      TextDownloadStatusesCompanion.insert(
        curriculumId: curriculumId,
        itemCount: itemCount,
        textVersion: textVersion,
        downloadedAt: DateTime.now(),
      ),
    );
  }

  /// Clears the download status for a curriculum.
  Future<void> clearDownloadStatus(String curriculumId) async {
    await (delete(
      textDownloadStatuses,
    )..where((t) => t.curriculumId.equals(curriculumId))).go();
  }

  /// Returns the download status for a curriculum, or null if not downloaded.
  Future<TextDownloadStatuse?> getStatus(String curriculumId) async {
    return (select(
      textDownloadStatuses,
    )..where((t) => t.curriculumId.equals(curriculumId))).getSingleOrNull();
  }
}
