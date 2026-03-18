import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

/// Download state for cloud content fetch.
enum ContentDownloadState {
  notStarted,
  downloading,
  parsing,
  storing,
  completed,
  failed,
}

/// Progress snapshot during content download.
class ContentDownloadProgress {
  const ContentDownloadProgress({
    required this.state,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.error,
  });

  final ContentDownloadState state;
  final int bytesTransferred;
  final int totalBytes;
  final String? error;

  double get progress {
    if (state == ContentDownloadState.downloading && totalBytes > 0) {
      return bytesTransferred / totalBytes;
    }
    if (state == ContentDownloadState.completed) return 1.0;
    return 0.0;
  }
}

/// Content version metadata stored in Firestore.
class ContentVersionInfo {
  const ContentVersionInfo({
    required this.version,
    required this.updatedAt,
    required this.sizeBytes,
    required this.languages,
  });

  factory ContentVersionInfo.fromFirestore(Map<String, dynamic> data) {
    return ContentVersionInfo(
      version: data['version'] as String? ?? '0',
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime(2000),
      sizeBytes: data['size_bytes'] as int? ?? 0,
      languages: (data['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  final String version;
  final DateTime updatedAt;
  final int sizeBytes;
  final List<String> languages;
}

/// Service for fetching curriculum content from Firebase Cloud Storage.
///
/// Content is stored at `content/{curriculum_id}/{language_code}.json`.
/// Version metadata is in Firestore at `content_versions/{curriculum_id}`.
class CloudContentService {
  CloudContentService({
    required FirebaseStorage storage,
    required FirebaseFirestore firestore,
  }) : _storage = storage,
       _firestore = firestore;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  /// Fetch content from Cloud Storage for a curriculum and language.
  ///
  /// Returns a stream of progress updates. The final update contains
  /// the parsed content items.
  Stream<ContentDownloadProgress> downloadContent({
    required CurriculumId curriculum,
    required String languageCode,
  }) async* {
    try {
      yield const ContentDownloadProgress(
        state: ContentDownloadState.downloading,
      );

      final ref = _storage.ref('content/${curriculum.storageKey}/$languageCode.json');
      final data = await ref.getData();

      if (data == null) {
        yield ContentDownloadProgress(
          state: ContentDownloadState.failed,
          error: 'No content found for ${curriculum.storageKey}/$languageCode',
        );
        return;
      }

      yield ContentDownloadProgress(
        state: ContentDownloadState.downloading,
        bytesTransferred: data.length,
        totalBytes: data.length,
      );

      yield const ContentDownloadProgress(
        state: ContentDownloadState.parsing,
      );

      // Content is downloaded and ready
      yield ContentDownloadProgress(
        state: ContentDownloadState.completed,
        bytesTransferred: data.length,
        totalBytes: data.length,
      );

      AppLogger.instance.info(
        'CloudContentService: downloaded ${curriculum.storageKey}/$languageCode '
        '(${data.length} bytes)',
      );
    } catch (e) {
      AppLogger.instance.error(
        'CloudContentService: failed to download ${curriculum.storageKey}/$languageCode',
        e,
      );
      yield ContentDownloadProgress(
        state: ContentDownloadState.failed,
        error: e.toString(),
      );
    }
  }

  /// Parse downloaded content blob into items and config.
  Future<({List<ContentItem> items, CurriculumHierarchyConfig config})>
      parseContent({
    required CurriculumId curriculum,
    required String languageCode,
  }) async {
    final ref = _storage.ref('content/${curriculum.storageKey}/$languageCode.json');
    final data = await ref.getData();

    if (data == null) {
      throw ContentDownloadException(
        'No content found for ${curriculum.storageKey}/$languageCode',
      );
    }

    final jsonString = utf8.decode(data);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    final configJson = json['hierarchyConfig'] as Map<String, dynamic>;
    final config = CurriculumHierarchyConfig(
      curriculumId: configJson['curriculumId'] as String,
      levelLabels:
          (configJson['levelLabels'] as List).map((e) => e as String).toList(),
      totalItems: configJson['totalItems'] as int,
    );

    final itemsJson = json['items'] as List;
    final items = itemsJson.map((itemJson) {
      final item = itemJson as Map<String, dynamic>;
      return ContentItem(
        curriculumId: item['curriculumId'] as String,
        level1: item['level1'] as String,
        level2: item['level2'] as String?,
        level3: item['level3'] as String?,
        level4: item['level4'] as String?,
        displayNameHe: item['displayNameHe'] as String,
        displayNameEn: item['displayNameEn'] as String,
        sefariaRef: item['sefariaRef'] as String,
        sortOrder: item['sortOrder'] as int,
        isLeaf: item['isLeaf'] as bool,
      );
    }).toList();

    return (items: items, config: config);
  }

  /// Check content version for a curriculum from Firestore.
  ///
  /// Returns null if no version info exists.
  Future<ContentVersionInfo?> getContentVersion(
    CurriculumId curriculum,
  ) async {
    try {
      final doc = await _firestore
          .collection('content_versions')
          .doc(curriculum.storageKey)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return ContentVersionInfo.fromFirestore(doc.data()!);
    } catch (e) {
      AppLogger.instance.error(
        'CloudContentService: failed to check version for ${curriculum.storageKey}',
        e,
      );
      return null;
    }
  }

  /// Check if newer content is available for any active curriculum.
  ///
  /// Compares Firestore version metadata against locally stored versions.
  Future<List<CurriculumId>> checkForUpdates(
    List<CurriculumId> activeCurricula,
    Map<String, String> localVersions,
  ) async {
    final updates = <CurriculumId>[];

    for (final curriculum in activeCurricula) {
      final remoteVersion = await getContentVersion(curriculum);
      if (remoteVersion == null) continue;

      final localVersion = localVersions[curriculum.storageKey];
      if (localVersion == null || localVersion != remoteVersion.version) {
        updates.add(curriculum);
      }
    }

    return updates;
  }
}

/// Exception thrown when content download fails.
class ContentDownloadException implements Exception {
  const ContentDownloadException(this.message);

  final String message;

  @override
  String toString() => 'ContentDownloadException: $message';
}
