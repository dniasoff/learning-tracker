import 'package:learning_tracker/core/database/daos/content_download_status_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';

/// Service that checks for content updates on app launch.
///
/// Compares local content versions against Firestore metadata
/// to detect when newer content is available.
class ContentVersionCheckService {
  ContentVersionCheckService({
    required CloudContentService cloudContentService,
    required ContentDownloadStatusDao contentDownloadStatusDao,
  }) : _cloudContentService = cloudContentService,
       _contentDownloadStatusDao = contentDownloadStatusDao;

  final CloudContentService _cloudContentService;
  final ContentDownloadStatusDao _contentDownloadStatusDao;

  /// Check if any active curricula have newer content available.
  ///
  /// Returns the list of curricula with available updates.
  Future<List<CurriculumId>> checkForUpdates(
    List<CurriculumId> activeCurricula,
  ) async {
    try {
      final localVersions =
          await _contentDownloadStatusDao.getAllDownloadedVersions();

      return _cloudContentService.checkForUpdates(
        activeCurricula,
        localVersions,
      );
    } catch (e) {
      AppLogger.instance.error(
        'ContentVersionCheckService: failed to check for updates',
        e,
      );
      return [];
    }
  }

  /// Check if content needs to be re-fetched for active curricula.
  ///
  /// Returns curricula that are active but have no downloaded content.
  /// Used after restore/reinstall.
  Future<List<CurriculumId>> getMissingContent(
    List<CurriculumId> activeCurricula,
  ) async {
    final downloaded = await _contentDownloadStatusDao.getDownloadedCurricula();
    final downloadedSet = downloaded.toSet();

    return activeCurricula
        .where((c) => !downloadedSet.contains(c.storageKey))
        .toList();
  }
}
