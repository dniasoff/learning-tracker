import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart'
    show kNoProfilePreferenceSentinel;
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderLanguage {
  const ReaderLanguage(
    this.code,
    this.englishName,
    this.hebrewName,
    this.nativeName,
  );
  final String code;
  final String englishName;
  final String hebrewName;
  final String nativeName;

  String label(bool hebrewUi) =>
      '${hebrewUi ? hebrewName : englishName} · $nativeName ($code)';
}

/// Common ISO 639-1 languages, shown with an English and Hebrew label plus
/// the language's native name. The callable accepts any valid ISO language tag.
const readerLanguages = <ReaderLanguage>[
  ReaderLanguage('ar', 'Arabic', 'ערבית', 'العربية'),
  ReaderLanguage('bn', 'Bengali', 'בנגלית', 'বাংলা'),
  ReaderLanguage('bg', 'Bulgarian', 'בולגרית', 'Български'),
  ReaderLanguage('zh', 'Chinese', 'סינית', '中文'),
  ReaderLanguage('hr', 'Croatian', 'קרואטית', 'Hrvatski'),
  ReaderLanguage('cs', 'Czech', 'צ׳כית', 'Čeština'),
  ReaderLanguage('da', 'Danish', 'דנית', 'Dansk'),
  ReaderLanguage('nl', 'Dutch', 'הולנדית', 'Nederlands'),
  ReaderLanguage('en', 'English', 'אנגלית', 'English'),
  ReaderLanguage('fa', 'Persian', 'פרסית', 'فارسی'),
  ReaderLanguage('fi', 'Finnish', 'פינית', 'Suomi'),
  ReaderLanguage('fr', 'French', 'צרפתית', 'Français'),
  ReaderLanguage('de', 'German', 'גרמנית', 'Deutsch'),
  ReaderLanguage('el', 'Greek', 'יוונית', 'Ελληνικά'),
  ReaderLanguage('he', 'Hebrew', 'עברית', 'עברית'),
  ReaderLanguage('hi', 'Hindi', 'הינדית', 'हिन्दी'),
  ReaderLanguage('hu', 'Hungarian', 'הונגרית', 'Magyar'),
  ReaderLanguage('id', 'Indonesian', 'אינדונזית', 'Bahasa Indonesia'),
  ReaderLanguage('it', 'Italian', 'איטלקית', 'Italiano'),
  ReaderLanguage('ja', 'Japanese', 'יפנית', '日本語'),
  ReaderLanguage('ko', 'Korean', 'קוריאנית', '한국어'),
  ReaderLanguage('ms', 'Malay', 'מלאית', 'Bahasa Melayu'),
  ReaderLanguage('no', 'Norwegian', 'נורווגית', 'Norsk'),
  ReaderLanguage('pl', 'Polish', 'פולנית', 'Polski'),
  ReaderLanguage('pt', 'Portuguese', 'פורטוגזית', 'Português'),
  ReaderLanguage('ro', 'Romanian', 'רומנית', 'Română'),
  ReaderLanguage('ru', 'Russian', 'רוסית', 'Русский'),
  ReaderLanguage('sr', 'Serbian', 'סרבית', 'Српски'),
  ReaderLanguage('es', 'Spanish', 'ספרדית', 'Español'),
  ReaderLanguage('sw', 'Swahili', 'סווהילית', 'Kiswahili'),
  ReaderLanguage('sv', 'Swedish', 'שוודית', 'Svenska'),
  ReaderLanguage('th', 'Thai', 'תאית', 'ไทย'),
  ReaderLanguage('tr', 'Turkish', 'טורקית', 'Türkçe'),
  ReaderLanguage('uk', 'Ukrainian', 'אוקראינית', 'Українська'),
  ReaderLanguage('ur', 'Urdu', 'אורדו', 'اردو'),
  ReaderLanguage('yi', 'Yiddish', 'יידיש', 'ייִדיש'),
];

class ReaderTranslationLanguagePreference {
  static const defaultValue = 'sefaria';
  Future<String> read(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('text_display_language_p$profileId') ?? defaultValue;
  }

  Future<void> write(String profileId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('text_display_language_p$profileId', value);
  }
}

final readerTranslationLanguageProvider =
    NotifierProvider<ReaderTranslationLanguageNotifier, String>(
      ReaderTranslationLanguageNotifier.new,
    );

class ReaderTranslationLanguageNotifier extends Notifier<String> {
  String? _activeProfileId;

  @override
  String build() {
    final profileId =
        ref.watch(selectedProfileIdProvider) ?? kNoProfilePreferenceSentinel;
    _activeProfileId = profileId;
    ref.listen(selectedProfileIdProvider, (previous, next) {
      if (next != null) _load(next);
    });
    _load(profileId);
    return ReaderTranslationLanguagePreference.defaultValue;
  }

  Future<void> _load(String profileId) async {
    final value = await ReaderTranslationLanguagePreference().read(profileId);
    if (ref.mounted && _activeProfileId == profileId) state = value;
  }

  Future<void> setLanguage(String code) async {
    final profileId =
        ref.read(selectedProfileIdProvider) ?? kNoProfilePreferenceSentinel;
    final previous = state;
    state = code;
    try {
      await ReaderTranslationLanguagePreference().write(profileId, code);
    } catch (_) {
      state = previous;
    }
  }
}

class PhraseTranslationKey {
  const PhraseTranslationKey(this.ref, this.language);
  final String ref;
  final String language;
  @override
  bool operator ==(Object other) =>
      other is PhraseTranslationKey &&
      other.ref == ref &&
      other.language == language;
  @override
  int get hashCode => Object.hash(ref, language);
}

class PhraseTranslation {
  const PhraseTranslation(this.source, this.translation);
  final String source;
  final String translation;
}

String _localCacheKey(PhraseTranslationKey key) =>
    'phrase_translation_${Uri.encodeComponent(key.ref)}_${key.language}_v1';

final phraseTranslationProvider =
    FutureProvider.family<List<PhraseTranslation>, PhraseTranslationKey>((
      ref,
      key,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _localCacheKey(key);
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final rows = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
        return rows
            .map(
              (row) => PhraseTranslation(
                row['source'] as String,
                row['translation'] as String,
              ),
            )
            .toList();
      }
      final resolver = ref.read(accountFunctionsProvider);
      final functions = await resolver();
      final result = await functions
          .httpsCallable('translatePhrases')
          .call<Map<String, dynamic>>({
            'sefariaRef': key.ref,
            'targetLanguage': key.language,
          });
      final phrases = (result.data['phrases'] as List)
          .cast<Map<dynamic, dynamic>>()
          .map(
            (row) => PhraseTranslation(
              row['source'] as String,
              row['translation'] as String,
            ),
          )
          .toList(growable: false);
      await prefs.setString(
        cacheKey,
        jsonEncode(
          phrases
              .map((p) => {'source': p.source, 'translation': p.translation})
              .toList(),
        ),
      );
      return phrases;
    });
