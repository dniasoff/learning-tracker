import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'text_display_providers.g.dart';

/// Provider for the text cache repository.
@Riverpod(keepAlive: true)
TextCacheRepository textCacheRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final fetcher = ref.watch(mishnaFetcherProvider);

  return TextCacheRepository(
    textCacheDao: database.textCacheDao,
    contentFetcher: fetcher,
  );
}

/// Provider for fetching text by Sefaria reference.
@riverpod
Future<TextContent?> textContent(
  Ref ref,
  String sefariaRef,
) async {
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

  void setFontSize(FontSize size) {
    TextDisplayPreferences.instance.setFontSize(size);
    state = size;
  }
}
