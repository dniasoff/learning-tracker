import 'package:dio/dio.dart';
import 'package:learning_tracker/core/database/content/daos/text_cache_dao.dart';

/// Model for fetched text content.
class TextContent {
  TextContent({
    required this.sefariaRef,
    required this.hebrewText,
    required this.englishText,
  });

  final String sefariaRef;
  final String hebrewText;
  final String englishText;
}

/// Repository for cached Sefaria text content.
/// Tries the local cache first, then falls back to the Sefaria API.
class TextCacheRepository {
  TextCacheRepository({required this.textCacheDao, required this.dio});

  final ContentTextCacheDao textCacheDao;
  final Dio dio;

  /// Retrieves text for a given Sefaria reference.
  /// Returns cached text if available, otherwise fetches from the Sefaria API.
  Future<TextContent?> getText(String sefariaRef) async {
    final cached = await textCacheDao.getText(sefariaRef);
    if (cached != null) {
      return TextContent(
        sefariaRef: cached.sefariaRef,
        hebrewText: cached.hebrewText,
        englishText: cached.englishText,
      );
    }
    return _fetchFromApi(sefariaRef);
  }

  /// Returns list of all cached Sefaria references.
  Future<List<String>> getCachedRefs() => textCacheDao.getAllCachedRefs();

  Future<TextContent?> _fetchFromApi(String sefariaRef) async {
    try {
      final encodedRef = Uri.encodeComponent(sefariaRef);
      final response = await dio.get<Map<String, dynamic>>(
        '/v3/texts/$encodedRef',
      );
      final data = response.data;
      if (data == null) return null;

      final versions = data['versions'] as List<dynamic>? ?? const [];
      String? he;
      String? en;
      for (final version in versions) {
        if (version is! Map<String, dynamic>) continue;
        final lang =
            (version['actualLanguage'] as String?) ??
            (version['language'] as String?) ??
            '';
        final text = version['text'];
        if (lang == 'he' && he == null) {
          he = _extractText(text);
        } else if (lang == 'en' && en == null) {
          en = _extractText(text);
        }
      }

      if ((he == null || he.isEmpty) && (en == null || en.isEmpty)) {
        return null;
      }

      return TextContent(
        sefariaRef: sefariaRef,
        hebrewText: he ?? '',
        englishText: en ?? '',
      );
    } on DioException {
      return null;
    }
  }

  static String _extractText(dynamic text) {
    if (text == null) return '';
    if (text is String) return _stripHtml(text);
    if (text is List) {
      return text.map(_extractText).where((s) => s.isNotEmpty).join('\n');
    }
    return '';
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp('<[^>]*>'), '').trim();
}
