import 'dart:async';

import 'package:learning_tracker/core/database/daos/text_download_status_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

enum TextDownloadState {
  notStarted,
  downloading,
  parsing,
  storing,
  completed,
  failed,
}

class TextDownloadProgress {
  const TextDownloadProgress({
    required this.state,
    this.itemsStored = 0,
    this.totalItems = 0,
    this.error,
  });

  final TextDownloadState state;
  final int itemsStored;
  final int totalItems;
  final String? error;

  double get progress {
    if (state == TextDownloadState.storing && totalItems > 0) {
      return itemsStored / totalItems;
    }
    if (state == TextDownloadState.completed) return 1.0;
    return 0.0;
  }
}

/// Service for checking text download status.
///
/// In the offline-first architecture (Epic 19), all text content is bundled
/// in the seed database. Runtime downloading is no longer needed.
/// The [downloadCurriculum] method is deprecated and will be removed.
class TextDownloadService {
  TextDownloadService({required TextDownloadStatusDao textDownloadStatusDao})
    : _textDownloadStatusDao = textDownloadStatusDao;

  final TextDownloadStatusDao _textDownloadStatusDao;

  /// Checks if text content is already downloaded for a curriculum.
  Future<bool> isDownloaded(CurriculumId curriculum) {
    return _textDownloadStatusDao.isDownloaded(curriculum.storageKey);
  }

  /// @deprecated — Text content is now bundled in the seed database.
  /// This method will be removed in a future story.
  Stream<TextDownloadProgress> downloadCurriculum(
    CurriculumId curriculum,
  ) async* {
    // In offline-first mode, all content is pre-bundled.
    // Mark as completed immediately.
    yield const TextDownloadProgress(
      state: TextDownloadState.completed,
      itemsStored: 0,
      totalItems: 0,
    );
  }
}
