import 'dart:async';
import 'dart:ui';

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/app_locale_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:learning_tracker/core/preferences/nikud_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/preferences/transliteration_variant_preference.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart'
    show syncWriteFacadeProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preference_providers.g.dart';

/// Long-lived singleton holding the [HebrewTermsPreference] object. Riverpod
/// keeps it alive so the underlying broadcast stream survives route changes.
@Riverpod(keepAlive: true)
HebrewTermsPreference hebrewTermsPreference(Ref ref) {
  final pref = HebrewTermsPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

@Riverpod(keepAlive: true)
HebrewDatePreference hebrewDatePreference(Ref ref) {
  final pref = HebrewDatePreference();
  ref.onDispose(pref.dispose);
  return pref;
}

@Riverpod(keepAlive: true)
NikudPreference nikudPreference(Ref ref) {
  final pref = NikudPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

@Riverpod(keepAlive: true)
AppLocalePreference appLocalePreference(Ref ref) {
  final pref = AppLocalePreference();
  ref.onDispose(pref.dispose);
  return pref;
}

@Riverpod(keepAlive: true)
TransliterationVariantPreference transliterationVariantPreference(Ref ref) {
  final pref = TransliterationVariantPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

@Riverpod(keepAlive: true)
TextDisplayPreference textDisplayPreference(Ref ref) {
  final pref = TextDisplayPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

void _bindObserver<T>(
  Ref ref,
  ProfileScopedPreference<T> pref,
  int profileId,
  void Function(T value) onValue,
) {
  final sub = pref.observe(profileId).listen(onValue);
  ref.onDispose(sub.cancel);
  pref.read(profileId).then(onValue);
}

Future<void> _writeAndPushSnapshot<T>(
  Ref ref,
  ProfileScopedPreference<T> pref,
  int profileId,
  T value,
) async {
  await pref.write(profileId, value);
  await ref.read(syncWriteFacadeProvider)?.pushUiPreferencesSnapshot();
}

/// Whether to render Jewish learning terms in Hebrew script for the active
/// profile. This is the **only** `core/` entry point for the toggle —
/// `core/labels/` reads here, never via `features/settings/`.
@Riverpod(keepAlive: true)
class UseHebrewTerms extends _$UseHebrewTerms {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final pref = ref.watch(hebrewTermsPreferenceProvider);
    _bindObserver(ref, pref, profileId, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(bool value) async {
    final profileId = ref.read(activeProfileIdProvider);
    final pref = ref.read(hebrewTermsPreferenceProvider);
    state = value;
    await _writeAndPushSnapshot(ref, pref, profileId, value);
  }
}

@Riverpod(keepAlive: true)
class UseHebrewDate extends _$UseHebrewDate {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final pref = ref.watch(hebrewDatePreferenceProvider);
    _bindObserver(ref, pref, profileId, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(bool value) async {
    final profileId = ref.read(activeProfileIdProvider);
    final pref = ref.read(hebrewDatePreferenceProvider);
    state = value;
    await _writeAndPushSnapshot(ref, pref, profileId, value);
  }
}

@Riverpod(keepAlive: true)
class ShowNikudPref extends _$ShowNikudPref {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final pref = ref.watch(nikudPreferenceProvider);
    _bindObserver(ref, pref, profileId, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> toggle() async => set(!state);

  Future<void> set(bool value) async {
    if (value == state) return;
    final profileId = ref.read(activeProfileIdProvider);
    final pref = ref.read(nikudPreferenceProvider);
    state = value;
    await _writeAndPushSnapshot(ref, pref, profileId, value);
  }
}

@Riverpod(keepAlive: true)
class CurrentAppLocale extends _$CurrentAppLocale {
  @override
  Locale build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final pref = ref.watch(appLocalePreferenceProvider);
    _bindObserver(ref, pref, profileId, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(Locale locale) async {
    final profileId = ref.read(activeProfileIdProvider);
    final pref = ref.read(appLocalePreferenceProvider);
    state = locale;
    await _writeAndPushSnapshot(ref, pref, profileId, locale);
  }
}

@Riverpod(keepAlive: true)
class CurrentTransliterationVariant extends _$CurrentTransliterationVariant {
  @override
  TransliterationVariant build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final pref = ref.watch(transliterationVariantPreferenceProvider);
    _bindObserver(ref, pref, profileId, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(TransliterationVariant variant) async {
    final profileId = ref.read(activeProfileIdProvider);
    final pref = ref.read(transliterationVariantPreferenceProvider);
    state = variant;
    // Transliteration variant is local-only — no Firestore push.
    await pref.write(profileId, variant);
  }
}

@Riverpod(keepAlive: true)
class CurrentFontSize extends _$CurrentFontSize {
  @override
  FontSize build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final pref = ref.watch(textDisplayPreferenceProvider);
    _bindObserver(ref, pref, profileId, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(FontSize size) async {
    final profileId = ref.read(activeProfileIdProvider);
    final pref = ref.read(textDisplayPreferenceProvider);
    state = size;
    await _writeAndPushSnapshot(ref, pref, profileId, size);
  }
}
