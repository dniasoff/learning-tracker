import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

/// Storage path prefix for all content.
const String _contentPrefix = 'content/v1';

/// Download state for cloud content fetch.
enum ContentDownloadState {
  notStarted,
  downloading,
  parsing,
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

/// Manifest describing available content in Firebase Storage.
class ContentManifest {
  const ContentManifest({
    required this.schemaVersion,
    required this.updatedAt,
    required this.curricula,
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    final curricula = <String, CurriculumManifestEntry>{};
    final curriculaJson = json['curricula'] as Map<String, dynamic>? ?? {};
    for (final entry in curriculaJson.entries) {
      curricula[entry.key] = CurriculumManifestEntry.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    return ContentManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      updatedAt: json['updatedAt'] as String? ?? '',
      curricula: curricula,
    );
  }

  final int schemaVersion;
  final String updatedAt;
  final Map<String, CurriculumManifestEntry> curricula;
}

/// Manifest entry for a single curriculum.
class CurriculumManifestEntry {
  const CurriculumManifestEntry({required this.hierarchy, required this.text});

  factory CurriculumManifestEntry.fromJson(Map<String, dynamic> json) {
    return CurriculumManifestEntry(
      hierarchy: ContentTypeManifest.fromJson(
        json['hierarchy'] as Map<String, dynamic>? ?? {},
      ),
      text: TextContentManifest.fromJson(
        json['text'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  final ContentTypeManifest hierarchy;
  final TextContentManifest text;
}

/// Manifest for hierarchy content.
class ContentTypeManifest {
  const ContentTypeManifest({
    required this.version,
    required this.languages,
    this.totalItems = 0,
  });

  factory ContentTypeManifest.fromJson(Map<String, dynamic> json) {
    return ContentTypeManifest(
      version: json['version'] as String? ?? '0',
      languages:
          (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      totalItems: json['totalItems'] as int? ?? 0,
    );
  }

  final String version;
  final List<String> languages;
  final int totalItems;
}

/// Manifest for text content with chunk info.
class TextContentManifest {
  const TextContentManifest({
    required this.version,
    required this.languages,
    required this.chunks,
  });

  factory TextContentManifest.fromJson(Map<String, dynamic> json) {
    final chunks = <String, TextChunkInfo>{};
    final chunksJson = json['chunks'] as Map<String, dynamic>? ?? {};
    for (final entry in chunksJson.entries) {
      chunks[entry.key] = TextChunkInfo.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    return TextContentManifest(
      version: json['version'] as String? ?? '0',
      languages:
          (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      chunks: chunks,
    );
  }

  final String version;
  final List<String> languages;
  final Map<String, TextChunkInfo> chunks;
}

/// Info about a single text chunk (level1 grouping).
class TextChunkInfo {
  const TextChunkInfo({required this.items, required this.sizeBytes});

  factory TextChunkInfo.fromJson(Map<String, dynamic> json) {
    return TextChunkInfo(
      items: json['items'] as int? ?? 0,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }

  final int items;
  final int sizeBytes;
}

/// Service for fetching curriculum content from Firebase Cloud Storage.
///
/// Content is stored at:
///   content/v1/manifest.json
///   content/v1/{curriculum}/hierarchy/{language}.json.gz
///   content/v1/{curriculum}/text/{language}/{chunk}.json.gz
class CloudContentService {
  CloudContentService({required FirebaseStorage storage}) : _storage = storage;

  final FirebaseStorage _storage;

  /// Cached manifest to avoid repeated downloads.
  ContentManifest? _cachedManifest;

  /// Fetch the content manifest.
  ///
  /// Returns cached version if available. Pass [forceRefresh] to re-fetch.
  Future<ContentManifest> getManifest({bool forceRefresh = false}) async {
    if (_cachedManifest != null && !forceRefresh) {
      return _cachedManifest!;
    }

    try {
      final ref = _storage.ref('$_contentPrefix/manifest.json');
      final data = await ref.getData();

      if (data == null) {
        throw const ContentDownloadException('Manifest not found');
      }

      final jsonString = utf8.decode(data);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _cachedManifest = ContentManifest.fromJson(json);
      return _cachedManifest!;
    } catch (e) {
      AppLogger.instance.error(
        'CloudContentService: failed to fetch manifest',
        e,
      );
      rethrow;
    }
  }

  /// Download and parse hierarchy content for a curriculum.
  ///
  /// Downloads gzipped JSON from Firebase Storage, decompresses, and parses.
  Future<({List<ContentItem> items, CurriculumHierarchyConfig config})>
  downloadHierarchy({
    required CurriculumId curriculum,
    required String languageCode,
  }) async {
    final path =
        '$_contentPrefix/${curriculum.storageKey}/hierarchy/$languageCode.json.gz';

    AppLogger.instance.info('CloudContentService: downloading hierarchy $path');

    final ref = _storage.ref(path);
    final data = await ref.getData();

    if (data == null) {
      throw ContentDownloadException('No hierarchy found at $path');
    }

    // Decompress gzip
    final decompressed = _decompressGzip(data);
    final jsonString = utf8.decode(decompressed);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    return _parseHierarchyJson(json);
  }

  /// Download and parse a text content chunk.
  ///
  /// Text is chunked by level1 value (e.g., masechta, seder).
  /// Path: content/v1/{curriculum}/text/{language}/{chunk}.json.gz
  Future<List<({String ref, String he, String en})>> downloadTextChunk({
    required CurriculumId curriculum,
    required String languageCode,
    required String chunkKey,
  }) async {
    final path =
        '$_contentPrefix/${curriculum.storageKey}/text/$languageCode/$chunkKey.json.gz';

    AppLogger.instance.info(
      'CloudContentService: downloading text chunk $path',
    );

    final ref = _storage.ref(path);
    final data = await ref.getData();

    if (data == null) {
      throw ContentDownloadException('No text chunk found at $path');
    }

    final decompressed = _decompressGzip(data);
    final jsonString = utf8.decode(decompressed);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    final itemsJson = json['items'] as List;
    return itemsJson.map((item) {
      final m = item as Map<String, dynamic>;
      return (
        ref: m['ref'] as String,
        he: m['he'] as String? ?? '',
        en: m['en'] as String? ?? '',
      );
    }).toList();
  }

  /// Check if newer content is available by comparing manifest versions.
  ///
  /// Returns curricula that have newer hierarchy versions than local.
  Future<List<CurriculumId>> checkForUpdates({
    required List<CurriculumId> activeCurricula,
    required Map<String, String> localVersions,
  }) async {
    try {
      final manifest = await getManifest(forceRefresh: true);
      final updates = <CurriculumId>[];

      for (final curriculum in activeCurricula) {
        final entry = manifest.curricula[curriculum.storageKey];
        if (entry == null) continue;

        final localVersion = localVersions[curriculum.storageKey];
        if (localVersion == null || localVersion != entry.hierarchy.version) {
          updates.add(curriculum);
        }
      }

      return updates;
    } catch (e) {
      AppLogger.instance.error(
        'CloudContentService: failed to check for updates',
        e,
      );
      return [];
    }
  }

  /// Decompress gzip data. Falls back to raw data if not gzipped.
  Uint8List _decompressGzip(Uint8List data) {
    try {
      return Uint8List.fromList(gzip.decode(data));
    } catch (_) {
      // Not gzipped, return as-is
      return data;
    }
  }

  /// Parse hierarchy JSON into items and config.
  ({List<ContentItem> items, CurriculumHierarchyConfig config})
  _parseHierarchyJson(Map<String, dynamic> json) {
    final configJson = json['hierarchyConfig'] as Map<String, dynamic>;
    final config = CurriculumHierarchyConfig(
      curriculumId: configJson['curriculumId'] as String,
      levelLabels: (configJson['levelLabels'] as List)
          .map((e) => e as String)
          .toList(),
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
}

/// Exception thrown when content download fails.
class ContentDownloadException implements Exception {
  const ContentDownloadException(this.message);

  final String message;

  @override
  String toString() => 'ContentDownloadException: $message';
}
