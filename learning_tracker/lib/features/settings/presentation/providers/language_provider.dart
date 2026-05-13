import 'dart:ui';

import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'language_provider.g.dart';

/// Supported content languages, keyed by language code.
///
/// Must stay in sync with `AppLocalizations.supportedLocales` and the
/// `.arb` files under `lib/l10n/`.
const Map<String, String> supportedLanguages = <String, String>{
  'he': 'עברית',
  'en': 'English',
};

/// Facade over [currentAppLocaleProvider] exposing the selected language as a
/// plain code (e.g. `en`, `he`) for UI pickers. Writes go through
/// [CurrentAppLocale.set] so the change actually propagates to
/// `MaterialApp.locale`.
@riverpod
class LanguageNotifier extends _$LanguageNotifier {
  @override
  String build() {
    final locale = ref.watch(currentAppLocaleProvider);
    return supportedLanguages.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.containsKey(code)) return;
    await ref.read(currentAppLocaleProvider.notifier).set(Locale(code));
  }
}
