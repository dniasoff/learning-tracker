import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';

part 'curriculum_content_fetcher.freezed.dart';

/// Result of fetching all content for a curriculum.
///
/// `@freezed` generates field-wise `==`/`hashCode`/`copyWith`/`toString`
/// (previously this class had no `==` at all and fell back to identity —
/// AUD-core-network-01).
@freezed
abstract class FetchResult with _$FetchResult {
  const factory FetchResult({
    /// All content items in the curriculum hierarchy.
    required List<ContentItem> items,

    /// Configuration describing the hierarchy structure.
    required CurriculumHierarchyConfig hierarchyConfig,
  }) = _FetchResult;
}

/// Abstract interface for curriculum-specific Sefaria API adapters.
///
/// Each curriculum (Mishnayos, Bavli, etc.) has its own implementation
/// that knows how to parse Sefaria's response format into a normalized
/// [ContentItem] hierarchy. This follows the adapter pattern (D6).
abstract class CurriculumContentFetcher {
  /// The curriculum this fetcher handles.
  String get curriculumId;

  /// Fetches the complete content hierarchy for this curriculum.
  ///
  /// Returns all [ContentItem]s at every level of the hierarchy,
  /// including both container nodes and leaf nodes.
  ///
  /// Throws [SefariaApiException] if the API is unreachable or returns
  /// an unrecoverable error.
  Future<FetchResult> fetchAllContent();

  /// Fetches the text content for a specific Sefaria reference.
  ///
  /// Returns both Hebrew and English text for the given [sefariaRef].
  /// Optionally filter by [lang] ('he' for Hebrew, 'en' for English).
  ///
  /// Returns the text as a string. If both languages are requested
  /// (default), returns Hebrew text followed by English separated by
  /// a newline.
  Future<String> fetchText(String sefariaRef, {String? lang});
}

/// Exception thrown when a Sefaria API call fails.
class SefariaApiException extends NetworkException {
  const SefariaApiException(super.message, {this.statusCode, super.cause});

  final int? statusCode;

  @override
  String toString() =>
      'SefariaApiException: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}'
      '${cause != null ? ' caused by: $cause' : ''}';
}
