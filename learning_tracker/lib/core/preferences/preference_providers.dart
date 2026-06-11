import 'dart:async';
import 'dart:ui';

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
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
  /// Tracks whether we have bound a non-sentinel (>0) profile's observer at
  /// least once.  Used by the IL-1 sentinel guard.
  bool _hasBindingForRealProfile = false;

  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    final pref = ref.watch(hebrewTermsPreferenceProvider);
    // IL-1 fix: do NOT re-bind the SharedPreferences observer when profileId
    // TRANSITIONS BACK to the sentinel value 0 after we have already seen a
    // real (>0) profile id.  The sentinel is emitted transiently whenever
    // userDatabaseProvider is invalidated (e.g. during the offline-signup DB
    // switch) and then the real profile id is restored moments later.
    // Without this guard, build() re-fires with id==0, _bindObserver reads
    // no stored pref for the sentinel, falls back to pref.defaultValue (Hebrew
    // ON), and overwrites the user's explicit English choice.
    //
    // On cold-start the profileId may be 0 from the beginning (before any
    // profile is loaded); in that case _hasBindingForRealProfile is false so
    // we bind normally and let the profile-0 pref (or default) drive the
    // initial state.  The guard ONLY activates when transitioning FROM a
    // non-zero id back to 0.
    if (profileId == 0 && _hasBindingForRealProfile) {
      // Transient sentinel — keep the last valid state.
      return state;
    }
    if (profileId != 0) {
      _hasBindingForRealProfile = true;
    }
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

/// Supported UI locales. The app UI language follows the DEVICE language —
/// there is intentionally no in-app switcher — so this set only resolves the
/// device locale to a bundled translation, English by default.
const Set<String> kSupportedUiLanguageCodes = {'en', 'he'};

/// Resolves the device's preferred locales to a supported UI locale, English by
/// default. Mirrors Flutter's MaterialApp resolution (which drives the UI, since
/// `MaterialApp.locale` is null) so background notifications — read without a
/// BuildContext via [currentAppLocaleProvider] — match the on-screen language.
Locale resolveDeviceUiLocale(List<Locale> deviceLocales) {
  for (final locale in deviceLocales) {
    if (kSupportedUiLanguageCodes.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return const Locale('en');
}

/// The UI locale the app is currently rendering in — derived from the DEVICE
/// language (there is no in-app language setting). Consumed by notification
/// providers to localize background text where no BuildContext is available;
/// invalidated on a runtime device-locale change by
/// `LearningTrackerApp.didChangeLocales`.
@Riverpod(keepAlive: true)
Locale currentAppLocale(Ref ref) =>
    resolveDeviceUiLocale(PlatformDispatcher.instance.locales);

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
