import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:learning_tracker/core/constants/text_content_config.dart';
import 'package:learning_tracker/core/database/daos/text_cache_dao.dart';
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

class TextDownloadService {
  TextDownloadService({
    required TextCacheDao textCacheDao,
    required TextDownloadStatusDao textDownloadStatusDao,
    http.Client? httpClient,
  }) : _textCacheDao = textCacheDao,
       _textDownloadStatusDao = textDownloadStatusDao,
       _httpClient = httpClient ?? http.Client();

  final TextCacheDao _textCacheDao;
  final TextDownloadStatusDao _textDownloadStatusDao;
  final http.Client _httpClient;

  /// Checks if text content is already downloaded for a curriculum.
  Future<bool> isDownloaded(CurriculumId curriculum) {
    return _textDownloadStatusDao.isDownloaded(curriculum.storageKey);
  }

  /// Downloads and stores text content for a curriculum.
  Stream<TextDownloadProgress> downloadCurriculum(
    CurriculumId curriculum,
  ) async* {
    try {
      // 1. Download
      yield const TextDownloadProgress(state: TextDownloadState.downloading);

      final url = TextContentConfig.downloadUrl(curriculum.storageKey);
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode != 200) {
        yield TextDownloadProgress(
          state: TextDownloadState.failed,
          error: 'Download failed: HTTP ${response.statusCode}',
        );
        return;
      }

      // 2. Decompress + parse
      yield const TextDownloadProgress(state: TextDownloadState.parsing);

      final bytes = gzip.decode(response.bodyBytes);
      final jsonString = utf8.decode(bytes);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>;
      final totalItems = items.length;

      // 3. Check for partial progress (resume support)
      const batchSize = 500;
      final previousCount =
          await _textDownloadStatusDao.getPartialItemCount(
            curriculum.storageKey,
          ) ??
          0;
      var stored = previousCount;

      // 4. Batch insert, skipping already-stored items
      for (var i = previousCount; i < items.length; i += batchSize) {
        final batchItems = items.skip(i).take(batchSize).toList();

        await _textCacheDao.storeBatch(
          batchItems.map((item) {
            final m = item as Map<String, dynamic>;
            return (
              sefariaRef: m['ref'] as String,
              hebrewText: m['he'] as String,
              englishText: m['en'] as String,
            );
          }).toList(),
        );

        stored = (i + batchSize).clamp(0, totalItems);

        // Checkpoint after each batch
        await _textDownloadStatusDao.savePartialProgress(
          curriculumId: curriculum.storageKey,
          storedItemCount: stored,
        );

        yield TextDownloadProgress(
          state: TextDownloadState.storing,
          itemsStored: stored,
          totalItems: totalItems,
        );
      }

      // 5. Mark as downloaded (clears partial progress)
      await _textDownloadStatusDao.markDownloaded(
        curriculumId: curriculum.storageKey,
        itemCount: totalItems,
        textVersion: TextContentConfig.textVersion,
      );

      yield TextDownloadProgress(
        state: TextDownloadState.completed,
        itemsStored: totalItems,
        totalItems: totalItems,
      );
    } catch (e) {
      yield TextDownloadProgress(
        state: TextDownloadState.failed,
        error: e.toString(),
      );
    }
  }
}
