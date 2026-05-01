import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/data/services/text_download_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'text_display_providers.g.dart';

/// Provider for the text cache repository.
@Riverpod(keepAlive: true)
TextCacheRepository textCacheRepository(Ref ref) {
  final database = ref.watch(contentDatabaseProvider);

  return TextCacheRepository(textCacheDao: database.contentTextCacheDao);
}

/// Provider for fetching text by Sefaria reference.
@riverpod
Future<TextContent?> textContent(Ref ref, String sefariaRef) async {
  final repository = ref.watch(textCacheRepositoryProvider);
  return repository.getText(sefariaRef);
}

/// Provider for font size preference (per learner profile).
@Riverpod(keepAlive: true)
class FontSizeNotifier extends _$FontSizeNotifier {
  @override
  FontSize build() {
    final profileId = ref.watch(activeProfileIdProvider);
    ref.listen(activeProfileIdProvider, (prev, next) {
      if (prev != next) {
        _reload(next);
      }
    });
    _reload(profileId);
    return FontSize.medium;
  }

  Future<void> _reload(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final idx = ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, profileId);
    if (idx >= 0 && idx < FontSize.values.length) {
      state = FontSize.values[idx];
    }
  }

  Future<void> setFontSize(FontSize size) async {
    final profileId = ref.read(activeProfileIdProvider);
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      ProfileScopedPreferenceKeys.textFontSize(profileId),
      size.index,
    );
    await ref.read(syncEngineProvider)?.pushUiPreferencesSnapshot();
  }
}

/// Provider for nikud display preference (per learner profile).
@Riverpod(keepAlive: true)
class ShowNikud extends _$ShowNikud {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    ref.listen(activeProfileIdProvider, (prev, next) {
      if (prev != next) {
        _reload(next);
      }
    });
    _reload(profileId);
    return true;
  }

  Future<void> _reload(int profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = ProfileScopedPreferenceKeys.readShowNikud(prefs, profileId);
    if (v != state) {
      state = v;
    }
  }

  Future<void> toggle() async {
    final profileId = ref.read(activeProfileIdProvider);
    final newValue = !state;
    state = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      ProfileScopedPreferenceKeys.textShowNikud(profileId),
      newValue,
    );
    await ref.read(syncEngineProvider)?.pushUiPreferencesSnapshot();
  }
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
