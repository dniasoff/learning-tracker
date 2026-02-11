import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/data/services/text_download_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'text_display_providers.g.dart';

/// Provider for the text cache repository.
@Riverpod(keepAlive: true)
TextCacheRepository textCacheRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);

  return TextCacheRepository(textCacheDao: database.textCacheDao);
}

/// Provider for fetching text by Sefaria reference.
@riverpod
Future<TextContent?> textContent(Ref ref, String sefariaRef) async {
  final repository = ref.watch(textCacheRepositoryProvider);
  return repository.getText(sefariaRef);
}

/// Provider for font size preference.
@Riverpod(keepAlive: true)
class FontSizeNotifier extends _$FontSizeNotifier {
  @override
  FontSize build() {
    return TextDisplayPreferences.instance.fontSize;
  }

  Future<void> setFontSize(FontSize size) async {
    await TextDisplayPreferences.instance.setFontSize(size);
    state = size;
  }
}

/// Provider for nikud display preference.
@Riverpod(keepAlive: true)
class ShowNikud extends _$ShowNikud {
  @override
  bool build() {
    return TextDisplayPreferences.instance.showNikud;
  }

  Future<void> toggle() async {
    final newValue = !state;
    await TextDisplayPreferences.instance.setShowNikud(newValue);
    state = newValue;
  }
}

/// Provider for the text download service.
@Riverpod(keepAlive: true)
TextDownloadService textDownloadService(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return TextDownloadService(
    textCacheDao: database.textCacheDao,
    textDownloadStatusDao: database.textDownloadStatusDao,
  );
}

/// Provider to check if text is downloaded for a curriculum.
@riverpod
Future<bool> isTextDownloaded(Ref ref, CurriculumId curriculumId) async {
  final service = ref.watch(textDownloadServiceProvider);
  return service.isDownloaded(curriculumId);
}
