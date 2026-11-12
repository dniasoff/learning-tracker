import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/reader_phrase_translation.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile extends SelectedProfileId {
  @override
  String? build() => 'profile-1';
}

class _FakeTranslator implements ReaderPhraseTranslator {
  final calls =
      <({String source, String sourceLanguage, String targetLanguage})>[];
  Error? error;

  @override
  Future<String> translate({
    required String source,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    calls.add((
      source: source,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    ));
    if (error case final failure?) throw failure;
    return 'translated: $source';
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('selected reader language persists for the active profile', () async {
    final container = ProviderContainer(
      overrides: [selectedProfileIdProvider.overrideWith(_Profile.new)],
    );
    addTearDown(container.dispose);
    container.read(readerTranslationLanguageProvider);
    await container
        .read(readerTranslationLanguageProvider.notifier)
        .setLanguage('es');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('text_display_language_pprofile-1'), 'es');
  });

  test('reader languages match the supported on-device translation set', () {
    final readerLanguageCodes = readerLanguages
        .map((language) => language.code)
        .toSet();
    expect(
      readerLanguageCodes.difference(mlKitTranslationLanguageCodes),
      isEmpty,
    );
    expect(readerLanguages.any((language) => language.code == 'yi'), isFalse);
    expect(readerLanguages.any((language) => language.code == 'sr'), isTrue);
  });

  test(
    'uses Sefaria English when available and caches per phrase and language',
    () async {
      final translator = _FakeTranslator();
      final container = ProviderContainer(
        overrides: [
          readerPhraseTranslatorProvider.overrideWithValue(translator),
        ],
      );
      addTearDown(container.dispose);
      const key = PhraseTranslationKey(
        'Genesis 1:1',
        'es',
        englishText: 'In the beginning',
        hebrewText: 'בְּרֵאשִׁית',
      );

      final first = await container.read(phraseTranslationProvider(key).future);
      container.invalidate(phraseTranslationProvider(key));
      final second = await container.read(
        phraseTranslationProvider(key).future,
      );

      expect(first.single.source, 'In the beginning');
      expect(first.single.sourceLanguage, 'en');
      expect(first.single.translation, 'translated: In the beginning');
      expect(second.single.translation, first.single.translation);
      expect(translator.calls, [
        (
          source: 'In the beginning',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        ),
      ]);
    },
  );

  test('falls back to Hebrew when the segment has no English source', () async {
    final translator = _FakeTranslator();
    final container = ProviderContainer(
      overrides: [readerPhraseTranslatorProvider.overrideWithValue(translator)],
    );
    addTearDown(container.dispose);
    const key = PhraseTranslationKey(
      'Mishnah Berakhot 1:1',
      'fr',
      hebrewText: 'מֵאֵימָתַי',
    );

    final result = await container.read(phraseTranslationProvider(key).future);

    expect(result.single.source, 'מֵאֵימָתַי');
    expect(result.single.sourceLanguage, 'he');
    expect(translator.calls.single.sourceLanguage, 'he');
  });

  test('any translation failure returns the reader fallback value', () async {
    final translator = _FakeTranslator()..error = StateError('model failed');
    final container = ProviderContainer(
      overrides: [readerPhraseTranslatorProvider.overrideWithValue(translator)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(
        phraseTranslationProvider(
          const PhraseTranslationKey(
            'Genesis 1:1',
            'es',
            englishText: 'In the beginning',
          ),
        ).future,
      ),
      isEmpty,
    );
  });
}
