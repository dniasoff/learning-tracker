import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/content_download_statuses.dart';

part 'content_download_status_dao.g.dart';

@DriftAccessor(tables: [ContentDownloadStatuses])
class ContentDownloadStatusDao extends DatabaseAccessor<AppDatabase>
    with _$ContentDownloadStatusDaoMixin {
  ContentDownloadStatusDao(super.db);

  /// Check if content is downloaded for a curriculum and language.
  Future<bool> isDownloaded(String curriculumId, String languageCode) async {
    final query = select(contentDownloadStatuses)
      ..where(
        (t) =>
            t.curriculumId.equals(curriculumId) &
            t.languageCode.equals(languageCode),
      );
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Get the downloaded version for a curriculum and language.
  Future<String?> getDownloadedVersion(
    String curriculumId,
    String languageCode,
  ) async {
    final query = select(contentDownloadStatuses)
      ..where(
        (t) =>
            t.curriculumId.equals(curriculumId) &
            t.languageCode.equals(languageCode),
      );
    final result = await query.getSingleOrNull();
    return result?.contentVersion;
  }

  /// Get all downloaded versions as a map of curriculumId -> version.
  Future<Map<String, String>> getAllDownloadedVersions() async {
    final results = await select(contentDownloadStatuses).get();
    final map = <String, String>{};
    for (final r in results) {
      map[r.curriculumId] = r.contentVersion;
    }
    return map;
  }

  /// Mark content as downloaded.
  Future<void> markDownloaded({
    required String curriculumId,
    required String languageCode,
    required String contentVersion,
    required int itemCount,
  }) async {
    await into(contentDownloadStatuses).insertOnConflictUpdate(
      ContentDownloadStatusesCompanion.insert(
        curriculumId: curriculumId,
        languageCode: languageCode,
        contentVersion: contentVersion,
        itemCount: itemCount,
        downloadedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Get all downloaded curricula IDs.
  Future<List<String>> getDownloadedCurricula() async {
    final results = await select(contentDownloadStatuses).get();
    return results.map((r) => r.curriculumId).toSet().toList();
  }

  /// Delete download status for a curriculum (used when content is cleared).
  Future<void> clearForCurriculum(String curriculumId) async {
    await (delete(contentDownloadStatuses)
          ..where((t) => t.curriculumId.equals(curriculumId)))
        .go();
  }
}
