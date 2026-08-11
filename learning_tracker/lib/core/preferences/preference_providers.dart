import 'dart:async';
import 'dart:ui';

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/hebrew_date_preference.dart';
import 'package:learning_tracker/core/preferences/hebrew_terms_preference.dart';
import 'package:learning_tracker/core/preferences/nikud_preference.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference.dart';
import 'package:learning_tracker/core/preferences/siyum_granularity_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preference.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/preferences/transliteration_variant_preference.dart';
import 'package:learning_tracker/core/utils/guarded_persist.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart'
    show MilestoneLevel;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preference_providers.g.dart';

/// Long-lived singleton holding the [HebrewTermsPreference] object. Riverpod
/// keeps it alive so the underlying broadcast stream survives route changes.
// keepAlive: profile-scoped store; lives for the app session.
@Riverpod(keepAlive: true)
HebrewTermsPreference hebrewTermsPreference(Ref ref) {
  final pref = HebrewTermsPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

// keepAlive: profile-scoped store; lives for the app session.
@Riverpod(keepAlive: true)
HebrewDatePreference hebrewDatePreference(Ref ref) {
  final pref = HebrewDatePreference();
  ref.onDispose(pref.dispose);
  return pref;
}

// keepAlive: profile-scoped store; lives for the app session.
@Riverpod(keepAlive: true)
NikudPreference nikudPreference(Ref ref) {
  final pref = NikudPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

// keepAlive: profile-scoped store; lives for the app session.
@Riverpod(keepAlive: true)
TransliterationVariantPreference transliterationVariantPreference(Ref ref) {
  final pref = TransliterationVariantPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

// keepAlive: profile-scoped store; lives for the app session.
@Riverpod(keepAlive: true)
TextDisplayPreference textDisplayPreference(Ref ref) {
  final pref = TextDisplayPreference();
  ref.onDispose(pref.dispose);
  return pref;
}

/// Long-lived store for the per-(profile, curriculum) siyum-granularity
/// preference. Keyed by [CurriculumId] because the value is per-curriculum;
/// the underlying broadcast stream survives route changes so the journey and
/// settings screens stay in sync.
// keepAlive: profile-scoped store; lives for the app session.
@Riverpod(keepAlive: true)
SiyumGranularityPreference siyumGranularityPreference(
  Ref ref,
  CurriculumId curriculum,
) {
  final pref = SiyumGranularityPreference(curriculum);
  ref.onDispose(pref.dispose);
  return pref;
}

/// Fixed storage bucket used for every profile-scoped preference before any
/// real profile has ever been selected (AD-24 replacement for the old `0`
/// int sentinel — [ProfileScopedPreference]'s key space is non-nullable, so
/// "no profile yet" still needs SOME concrete bucket to read/write).
const _kNoProfileSentinel = '_no_profile_';

void _bindObserver<T>(
  Ref ref,
  ProfileScopedPreference<T> pref,
  String profileId,
  void Function(T value) onValue,
) {
  // SM-4: guard the post-await state write. `pref.read(...)` awaits
  // SharedPreferences.getInstance() internally; if the container/ref is
  // disposed while that read is still in flight, the `.then` continuation
  // must no-op instead of touching `state` on an unmounted Ref.
  void guardedOnValue(T value) {
    if (!ref.mounted) return;
    onValue(value);
  }

  final sub = pref.observe(profileId).listen(guardedOnValue);
  ref.onDispose(sub.cancel);
  pref.read(profileId).then(guardedOnValue);
}

/// Shared IL-1 sentinel guard for keepAlive preference notifiers whose
/// `build()` follows the `ref.watch(activeProfileIdProvider)` +
/// `_bindObserver(...)` shape.
///
/// `activeProfileIdProvider` transiently emits `null` whenever the active
/// profile is being re-resolved (e.g. during an account switch), before
/// settling back to the real profile id moments later. Without this guard,
/// `build()` re-fires with a null id, `_bindObserver` reads no stored pref
/// for [_kNoProfileSentinel], falls back to `pref.defaultValue`, and
/// overwrites the user's explicit choice — visibly flipping the setting and
/// silently misfiling any toggle tapped inside that window under the
/// sentinel bucket.
///
/// Mix this in and call [sentinelBlocksRebind] as the first statement of
/// `build()`:
///
/// ```dart
/// @override
/// bool build() {
///   final profileId = ref.watch(activeProfileIdProvider);
///   if (sentinelBlocksRebind(profileId)) return state;
///   final pref = ref.watch(hebrewDatePreferenceProvider);
///   _bindObserver(ref, pref, profileId ?? _kNoProfileSentinel, (value) {
///     if (value != state) state = value;
///   });
///   return pref.defaultValue;
/// }
/// ```
///
/// On cold-start [profileId] may be `null` from the beginning (before any
/// profile is loaded); [sentinelBlocksRebind] returns false in that case so
/// callers bind normally and let the sentinel-bucket pref (or default) drive
/// the initial state. The guard ONLY activates when transitioning FROM a
/// real id back to `null`.
mixin _SentinelGuardedPreference<T> {
  /// Tracks whether we have bound a non-sentinel (real) profile's observer at
  /// least once.
  bool _hasBindingForRealProfile = false;

  /// Returns true when [profileId] is `null` (the transient sentinel) and
  /// `build()` should bail out early, preserving the notifier's current
  /// state instead of re-binding the observer.
  bool sentinelBlocksRebind(String? profileId) {
    if (profileId == null && _hasBindingForRealProfile) {
      return true;
    }
    if (profileId != null) {
      _hasBindingForRealProfile = true;
    }
    return false;
  }
}

Future<void> _writeAndPersist<T>(
  ProfileScopedPreference<T> pref,
  String profileId,
  T value,
) async {
  await pref.write(profileId, value);
}

/// Whether to render Jewish learning terms in Hebrew script for the active
/// profile. This is the **only** `core/` entry point for the toggle —
/// `core/labels/` reads here, never via `features/settings/`.
// keepAlive: mirrors a persisted preference; must survive widget unmounts.
@Riverpod(keepAlive: true)
class UseHebrewTerms extends _$UseHebrewTerms
    with _SentinelGuardedPreference<bool> {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    // IL-1 fix: do NOT re-bind the SharedPreferences observer when profileId
    // transiently reverts to `null` after a real profile id has already
    // been observed. See _SentinelGuardedPreference for details.
    if (sentinelBlocksRebind(profileId)) return state;
    final pref = ref.watch(hebrewTermsPreferenceProvider);
    _bindObserver(ref, pref, profileId ?? _kNoProfileSentinel, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(bool value) async {
    final profileId = ref.read(activeProfileIdProvider) ?? _kNoProfileSentinel;
    final pref = ref.read(hebrewTermsPreferenceProvider);
    final previous = state;
    state = value;
    // AUD-core-preferences-04 (EH-2): a plain-value Notifier has no error
    // channel, so a failed write must be caught explicitly — otherwise the
    // optimistic `state = value` above silently diverges from what actually
    // persisted, with zero explanation to the user.
    await guardedPersist(
      event: 'use_hebrew_terms_persist_failed',
      write: () => _writeAndPersist(pref, profileId, value),
      onFailure: () => state = previous,
    );
  }
}

// keepAlive: mirrors a persisted preference; must survive widget unmounts.
@Riverpod(keepAlive: true)
class UseHebrewDate extends _$UseHebrewDate
    with _SentinelGuardedPreference<bool> {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    // IL-1 fix: see _SentinelGuardedPreference — do NOT re-bind when
    // profileId transiently reverts to `null`.
    if (sentinelBlocksRebind(profileId)) return state;
    final pref = ref.watch(hebrewDatePreferenceProvider);
    _bindObserver(ref, pref, profileId ?? _kNoProfileSentinel, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(bool value) async {
    final profileId = ref.read(activeProfileIdProvider) ?? _kNoProfileSentinel;
    final pref = ref.read(hebrewDatePreferenceProvider);
    final previous = state;
    state = value;
    // AUD-core-preferences-04 (EH-2): see UseHebrewTerms.set — guard the
    // persistence write so a failure logs + rolls back instead of leaving
    // state silently diverged from the persisted value.
    await guardedPersist(
      event: 'use_hebrew_date_persist_failed',
      write: () => _writeAndPersist(pref, profileId, value),
      onFailure: () => state = previous,
    );
  }
}

// keepAlive: mirrors a persisted preference; must survive widget unmounts.
@Riverpod(keepAlive: true)
class ShowNikudPref extends _$ShowNikudPref
    with _SentinelGuardedPreference<bool> {
  @override
  bool build() {
    final profileId = ref.watch(activeProfileIdProvider);
    // IL-1 fix: see _SentinelGuardedPreference — do NOT re-bind when
    // profileId transiently reverts to `null`.
    if (sentinelBlocksRebind(profileId)) return state;
    final pref = ref.watch(nikudPreferenceProvider);
    _bindObserver(ref, pref, profileId ?? _kNoProfileSentinel, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> toggle() async => set(!state);

  Future<void> set(bool value) async {
    if (value == state) return;
    final profileId = ref.read(activeProfileIdProvider) ?? _kNoProfileSentinel;
    final pref = ref.read(nikudPreferenceProvider);
    final previous = state;
    state = value;
    // AUD-core-preferences-04 (EH-2): see UseHebrewTerms.set.
    await guardedPersist(
      event: 'show_nikud_persist_failed',
      write: () => _writeAndPersist(pref, profileId, value),
      onFailure: () => state = previous,
    );
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
// keepAlive: read by background notification code with no widget listener.
@Riverpod(keepAlive: true)
Locale currentAppLocale(Ref ref) =>
    resolveDeviceUiLocale(PlatformDispatcher.instance.locales);

/// The EFFECTIVE Hebrew-script decision for domain/curriculum labels: Hebrew
/// script is used when the device UI language is Hebrew (a Hebrew device shows
/// Hebrew terms automatically, and the per-profile toggle is hidden there) OR
/// when the per-profile Hebrew-Terms [useHebrewTermsProvider] toggle is on.
///
/// This is the single locale-aware source every LABEL-RENDERING path must read
/// — the breadcrumb / curriculum-tree renderers previously read the raw
/// [useHebrewTermsProvider] toggle, so on a Hebrew device with the toggle
/// persisted OFF (and hidden) they leaked Latin transliteration. Mirrors the
/// `resolveUseHebrewTerms` logic used by `DomainTermLabels`.
@riverpod
bool effectiveUseHebrewTerms(Ref ref) =>
    ref.watch(currentAppLocaleProvider).languageCode == 'he' ||
    ref.watch(useHebrewTermsProvider);

// keepAlive: mirrors a persisted preference; must survive widget unmounts.
@Riverpod(keepAlive: true)
class CurrentTransliterationVariant extends _$CurrentTransliterationVariant
    with _SentinelGuardedPreference<TransliterationVariant> {
  @override
  TransliterationVariant build() {
    final profileId = ref.watch(activeProfileIdProvider);
    // IL-1 fix: see _SentinelGuardedPreference — do NOT re-bind when
    // profileId transiently reverts to `null`.
    if (sentinelBlocksRebind(profileId)) return state;
    final pref = ref.watch(transliterationVariantPreferenceProvider);
    _bindObserver(ref, pref, profileId ?? _kNoProfileSentinel, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(TransliterationVariant variant) async {
    final profileId = ref.read(activeProfileIdProvider) ?? _kNoProfileSentinel;
    final pref = ref.read(transliterationVariantPreferenceProvider);
    final previous = state;
    state = variant;
    // Transliteration variant is local-only — no Firestore push.
    // AUD-core-preferences-04 (EH-2): see UseHebrewTerms.set.
    await guardedPersist(
      event: 'transliteration_variant_persist_failed',
      write: () => pref.write(profileId, variant),
      onFailure: () => state = previous,
    );
  }
}

// keepAlive: mirrors a persisted preference; must survive widget unmounts.
@Riverpod(keepAlive: true)
class CurrentFontSize extends _$CurrentFontSize
    with _SentinelGuardedPreference<FontSize> {
  @override
  FontSize build() {
    final profileId = ref.watch(activeProfileIdProvider);
    // IL-1 fix: see _SentinelGuardedPreference — do NOT re-bind when
    // profileId transiently reverts to `null`.
    if (sentinelBlocksRebind(profileId)) return state;
    final pref = ref.watch(textDisplayPreferenceProvider);
    _bindObserver(ref, pref, profileId ?? _kNoProfileSentinel, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(FontSize size) async {
    final profileId = ref.read(activeProfileIdProvider) ?? _kNoProfileSentinel;
    final pref = ref.read(textDisplayPreferenceProvider);
    final previous = state;
    state = size;
    // AUD-core-preferences-04 (EH-2): see UseHebrewTerms.set.
    await guardedPersist(
      event: 'current_font_size_persist_failed',
      write: () => _writeAndPersist(pref, profileId, size),
      onFailure: () => state = previous,
    );
  }
}

/// The finest [MilestoneLevel] the active profile wants celebrated for
/// [curriculum] (a Riverpod family keyed by curriculum). Defaults to
/// [MilestoneLevel.unit] — the finest tier — so an unset preference reproduces
/// the current shipped behaviour. The journey layer reads this and suppresses
/// any milestone finer than the chosen level; it can only ever remove
/// emissions, never add one.
// keepAlive: mirrors a persisted preference; must survive widget unmounts.
@Riverpod(keepAlive: true)
class SiyumGranularity extends _$SiyumGranularity
    with _SentinelGuardedPreference<MilestoneLevel> {
  @override
  MilestoneLevel build(CurriculumId curriculum) {
    final profileId = ref.watch(activeProfileIdProvider);
    // IL-1 fix: see _SentinelGuardedPreference — do NOT re-bind when
    // profileId transiently reverts to `null`.
    if (sentinelBlocksRebind(profileId)) return state;
    final pref = ref.watch(siyumGranularityPreferenceProvider(curriculum));
    _bindObserver(ref, pref, profileId ?? _kNoProfileSentinel, (value) {
      if (value != state) state = value;
    });
    return pref.defaultValue;
  }

  Future<void> set(MilestoneLevel level) async {
    if (level == state) return;
    final profileId = ref.read(activeProfileIdProvider) ?? _kNoProfileSentinel;
    final pref = ref.read(siyumGranularityPreferenceProvider(curriculum));
    final previous = state;
    state = level;
    // Siyum granularity is local-only — no Firestore push (mirrors
    // CurrentTransliterationVariant.set).
    // AUD-core-preferences-04 (EH-2): see UseHebrewTerms.set — guard the
    // persistence write so a failure logs + rolls back instead of leaving
    // state silently diverged from the persisted value.
    await guardedPersist(
      event: 'siyum_granularity_persist_failed',
      write: () => pref.write(profileId, level),
      onFailure: () => state = previous,
    );
  }
}
