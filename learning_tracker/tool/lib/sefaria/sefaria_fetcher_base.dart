import 'package:dio/dio.dart';

import 'package:learning_tracker/core/network/sefaria/curriculum_content_fetcher.dart';

/// Base class for curriculum fetchers providing shared Sefaria API logic.
abstract class SefariaFetcherBase implements CurriculumContentFetcher {
  SefariaFetcherBase({required this.dio});

  final Dio dio;

  @override
  Future<String> fetchText(String sefariaRef, {String? lang}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v3/texts/${Uri.encodeComponent(sefariaRef)}',
      );

      final data = response.data;
      if (data == null) {
        throw const SefariaApiException('Empty response from Sefaria');
      }

      final versions = data['versions'] as List<dynamic>? ?? [];

      String? hebrewText;
      String? englishText;

      for (final version in versions) {
        if (version is! Map<String, dynamic>) continue;
        final versionLang =
            version['actualLanguage'] as String? ??
            version['language'] as String? ??
            '';
        final text = version['text'];
        final textStr = _extractText(text);

        if (versionLang == 'he' && hebrewText == null) {
          hebrewText = textStr;
        } else if (versionLang == 'en' && englishText == null) {
          englishText = textStr;
        }
      }

      if (lang == 'he') return hebrewText ?? '';
      if (lang == 'en') return englishText ?? '';

      // Return both languages, Hebrew first.
      final parts = <String>[
        if (hebrewText != null && hebrewText.isNotEmpty) hebrewText,
        if (englishText != null && englishText.isNotEmpty) englishText,
      ];
      return parts.join('\n');
    } on DioException catch (e) {
      throw SefariaApiException(
        'Failed to fetch text for $sefariaRef',
        statusCode: e.response?.statusCode,
        cause: e,
      );
    }
  }

  /// Fetches the shape data for a category from the Sefaria API.
  Future<List<Map<String, dynamic>>> fetchShape(String category) async {
    try {
      final response = await dio.get<dynamic>('/api/shape/$category');

      final data = response.data;
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      throw SefariaApiException(
        'Unexpected shape response format for $category',
      );
    } on DioException catch (e) {
      throw SefariaApiException(
        'Failed to fetch shape for $category',
        statusCode: e.response?.statusCode,
        cause: e,
      );
    }
  }

  /// Fetches shape data for a single book (returns a map, not a list).
  Future<Map<String, dynamic>> fetchBookShape(String title) async {
    try {
      final response = await dio.get<dynamic>(
        '/api/shape/${Uri.encodeComponent(title)}',
      );

      final data = response.data;
      if (data is List && data.isNotEmpty && data.first is Map) {
        return (data.first as Map).cast<String, dynamic>();
      }
      if (data is Map) {
        return data.cast<String, dynamic>();
      }
      throw SefariaApiException('Unexpected shape response format for $title');
    } on DioException catch (e) {
      throw SefariaApiException(
        'Failed to fetch shape for $title',
        statusCode: e.response?.statusCode,
        cause: e,
      );
    }
  }

  /// Extracts a plain-text string from a Sefaria text field.
  ///
  /// The text field can be a string, a list of strings, or a nested list.
  String _extractText(dynamic text) {
    if (text is String) return _stripHtml(text);
    if (text is List) {
      return text.map(_extractText).where((s) => s.isNotEmpty).join(' ');
    }
    return '';
  }

  /// Strips basic HTML tags from Sefaria text content.
  static String _stripHtml(String html) {
    return html.replaceAll(RegExp('<[^>]*>'), '');
  }
}
