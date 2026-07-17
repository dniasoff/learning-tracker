import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'text_display_providers.g.dart';

/// Provider for the text cache repository.
///
/// Awaits [contentDatabaseProvider] so the repository is only created once
/// the content DB is ready (extraction completes on first launch).
@Riverpod(keepAlive: true)
Future<TextCacheRepository> textCacheRepository(Ref ref) async {
  final database = await ref.watch(contentDatabaseProvider.future);

  return TextCacheRepository(
    textCacheDao: database.contentTextCacheDao,
    dailyContentDao: database.dailyContentDao,
  );
}

/// Provider for fetching text by Sefaria reference.
@riverpod
Future<TextContent?> textContent(Ref ref, String sefariaRef) async {
  final repository = await ref.watch(textCacheRepositoryProvider.future);
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
