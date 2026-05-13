import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/data/services/text_download_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'text_display_providers.g.dart';

/// Provider for the text cache repository.
@Riverpod(keepAlive: true)
TextCacheRepository textCacheRepository(Ref ref) {
  final database = ref.watch(contentDatabaseProvider);

  return TextCacheRepository(
    textCacheDao: database.contentTextCacheDao,
    dailyContentDao: database.dailyContentDao,
  );
}

/// Provider for fetching text by Sefaria reference.
@riverpod
Future<TextContent?> textContent(Ref ref, String sefariaRef) async {
  final repository = ref.watch(textCacheRepositoryProvider);
  return repository.getText(sefariaRef);
}

/// Facade over [currentFontSizeProvider] kept under the existing
/// `fontSizeProvider` name to avoid churning the text-display call sites.
/// The single source of truth lives in `core/preferences/`.
@Riverpod(keepAlive: true)
class FontSizeNotifier extends _$FontSizeNotifier {
  @override
  FontSize build() => ref.watch(currentFontSizeProvider);

  Future<void> setFontSize(FontSize size) =>
      ref.read(currentFontSizeProvider.notifier).set(size);
}

/// Facade over [showNikudPrefProvider] kept under the existing
/// `showNikudProvider` name to avoid churning consumers.
@Riverpod(keepAlive: true)
class ShowNikud extends _$ShowNikud {
  @override
  bool build() => ref.watch(showNikudPrefProvider);

  Future<void> toggle() => ref.read(showNikudPrefProvider.notifier).toggle();

  Future<void> set(bool value) =>
      ref.read(showNikudPrefProvider.notifier).set(value);
}

/// Provider for the text download service.
@Riverpod(keepAlive: true)
TextDownloadService textDownloadService(Ref ref) {
  final userDb = ref.watch(userDatabaseProvider);
  return TextDownloadService(
    textDownloadStatusDao: userDb.textDownloadStatusDao,
  );
}

/// Provider to check if text is downloaded for a curriculum.
@riverpod
Future<bool> isTextDownloaded(Ref ref, CurriculumId curriculumId) async {
  final service = ref.watch(textDownloadServiceProvider);
  return service.isDownloaded(curriculumId);
}
