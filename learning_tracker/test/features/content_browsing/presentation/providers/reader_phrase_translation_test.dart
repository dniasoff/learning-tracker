import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/reader_phrase_translation.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockCallableResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

class _Profile extends SelectedProfileId {
  @override
  String? build() => 'profile-1';
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

  test(
    'phrase translations are reused from local storage without another callable',
    () async {
      final functions = _MockFunctions();
      final callable = _MockCallable();
      final result = _MockCallableResult();
      when(
        () => functions.httpsCallable('translatePhrases'),
      ).thenReturn(callable);
      when(
        () => callable.call<Map<String, dynamic>>({
          'sefariaRef': 'Mishnah Berakhot 1:1',
          'targetLanguage': 'es',
        }),
      ).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'phrases': [
          {'source': 'מֵאֵימָתַי', 'translation': '¿Desde cuándo?'},
        ],
        'cached': false,
      });
      final container = ProviderContainer(
        overrides: [
          accountFunctionsProvider.overrideWithValue(() async => functions),
        ],
      );
      addTearDown(container.dispose);
      const key = PhraseTranslationKey('Mishnah Berakhot 1:1', 'es');
      final first = await container.read(phraseTranslationProvider(key).future);
      container.invalidate(phraseTranslationProvider(key));
      final second = await container.read(
        phraseTranslationProvider(key).future,
      );
      expect(first.single.translation, '¿Desde cuándo?');
      expect(second.single.source, 'מֵאֵימָתַי');
      verify(
        () => callable.call<Map<String, dynamic>>({
          'sefariaRef': 'Mishnah Berakhot 1:1',
          'targetLanguage': 'es',
        }),
      ).called(1);
    },
  );
}
