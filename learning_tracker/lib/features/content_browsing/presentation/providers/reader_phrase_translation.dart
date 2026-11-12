import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart'
    show kNoProfilePreferenceSentinel;
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

/// Languages supported by ML Kit on-device translation.
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
  ReaderLanguage('es', 'Spanish', 'ספרדית', 'Español'),
  ReaderLanguage('sw', 'Swahili', 'סווהילית', 'Kiswahili'),
  ReaderLanguage('sv', 'Swedish', 'שוודית', 'Svenska'),
  ReaderLanguage('th', 'Thai', 'תאית', 'ไทย'),
  ReaderLanguage('tr', 'Turkish', 'טורקית', 'Türkçe'),
  ReaderLanguage('uk', 'Ukrainian', 'אוקראינית', 'Українська'),
  ReaderLanguage('ur', 'Urdu', 'אורדו', 'اردو'),
];

/// Official ML Kit translation language codes. Keep [readerLanguages] within
/// this set so the picker never offers a language without an installed model.
const mlKitTranslationLanguageCodes = <String>{
  'ar',
  'bg',
  'bn',
  'cs',
  'da',
  'de',
  'el',
  'en',
  'es',
  'fa',
  'fi',
  'fr',
  'he',
  'hi',
  'hr',
  'hu',
  'id',
  'it',
  'ja',
  'ko',
  'ms',
  'nl',
  'no',
  'pl',
  'pt',
  'ro',
  'ru',
  'sv',
  'sw',
  'th',
  'tr',
  'uk',
  'ur',
  'zh',
};

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
  const PhraseTranslationKey(
    this.ref,
    this.language, {
    this.englishText = '',
    this.hebrewText = '',
  });
  final String ref;
  final String language;
  final String englishText;
  final String hebrewText;

  String get sourceText => englishText.isNotEmpty ? englishText : hebrewText;
  String get sourceLanguage => englishText.isNotEmpty ? 'en' : 'he';

  @override
  bool operator ==(Object other) =>
      other is PhraseTranslationKey &&
      other.ref == ref &&
      other.language == language &&
      other.englishText == englishText &&
      other.hebrewText == hebrewText;
  @override
  int get hashCode => Object.hash(ref, language, englishText, hebrewText);
}

class PhraseTranslation {
  const PhraseTranslation(
    this.source,
    this.translation, {
    this.sourceLanguage = 'he',
  });
  final String source;
  final String translation;
  final String sourceLanguage;
}

String _localCacheKey(PhraseTranslationKey key) {
  final sourceHash = sha256.convert(utf8.encode(key.sourceText));
  return 'phrase_translation_${Uri.encodeComponent(key.ref)}_${key.language}_${sourceHash}_v2';
}

abstract interface class ReaderPhraseTranslator {
  Future<String> translate({
    required String source,
    required String sourceLanguage,
    required String targetLanguage,
  });
}

final readerPhraseTranslatorProvider = Provider<ReaderPhraseTranslator>(
  (ref) => _MlKitReaderPhraseTranslator(),
);

class _MlKitReaderPhraseTranslator implements ReaderPhraseTranslator {
  static final Map<String, Future<void>> _modelDownloads = {};
  final _modelManager = OnDeviceTranslatorModelManager();

  TranslateLanguage _language(String code) => TranslateLanguage.values
      .firstWhere((language) => language.bcpCode == code);

  Future<void> _ensureModel(String languageCode) =>
      _modelDownloads.putIfAbsent(languageCode, () async {
        try {
          if (!await _modelManager.isModelDownloaded(languageCode) &&
              !await _modelManager.downloadModel(languageCode)) {
            throw StateError('Could not download translation model');
          }
        } finally {
          unawaited(_modelDownloads.remove(languageCode));
        }
      });

  @override
  Future<String> translate({
    required String source,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final from = _language(sourceLanguage);
    final to = _language(targetLanguage);
    if (from == to) return source;
    for (final language in {from, to}) {
      await _ensureModel(language.bcpCode);
    }
    final translator = OnDeviceTranslator(
      sourceLanguage: from,
      targetLanguage: to,
    );
    try {
      return await translator.translateText(source);
    } finally {
      await translator.close();
    }
  }
}

/// Explicit retry signal for a failed phrase-translation request.
final phraseTranslationRetryProvider =
    NotifierProvider.family<
      PhraseTranslationRetryNotifier,
      int,
      PhraseTranslationKey
    >(PhraseTranslationRetryNotifier.new);

class PhraseTranslationRetryNotifier extends Notifier<int> {
  PhraseTranslationRetryNotifier(PhraseTranslationKey _);

  @override
  int build() => 0;

  void retry() => state++;
}

final phraseTranslationProvider =
    FutureProvider.family<List<PhraseTranslation>, PhraseTranslationKey>((
      ref,
      key,
    ) async {
      ref.watch(phraseTranslationRetryProvider(key));
      try {
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = _localCacheKey(key);
        final cached = prefs.getString(cacheKey);
        if (cached != null) {
          final rows = (jsonDecode(cached) as List)
              .cast<Map<String, dynamic>>();
          return rows
              .map(
                (row) => PhraseTranslation(
                  row['source'] as String,
                  row['translation'] as String,
                  sourceLanguage: row['sourceLanguage'] as String,
                ),
              )
              .toList(growable: false);
        }
        if (key.sourceText.isEmpty ||
            !mlKitTranslationLanguageCodes.contains(key.language)) {
          return const <PhraseTranslation>[];
        }
        final translation = await ref
            .read(readerPhraseTranslatorProvider)
            .translate(
              source: key.sourceText,
              sourceLanguage: key.sourceLanguage,
              targetLanguage: key.language,
            );
        if (translation.trim().isEmpty) {
          return const <PhraseTranslation>[];
        }
        final phrase = PhraseTranslation(
          key.sourceText,
          translation,
          sourceLanguage: key.sourceLanguage,
        );
        await prefs.setString(
          cacheKey,
          jsonEncode([
            {
              'source': phrase.source,
              'translation': phrase.translation,
              'sourceLanguage': phrase.sourceLanguage,
            },
          ]),
        );
        return [phrase];
      } catch (_) {
        // Translation is best-effort; every failure uses the reader fallback.
        return const <PhraseTranslation>[];
      }
    });
