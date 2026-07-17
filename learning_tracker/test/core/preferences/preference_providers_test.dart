// Regression tests for AUD-core-preferences-01: the IL-1 sentinel-0 guard
// must exist on ALL FIVE keepAlive preference notifiers in
// preference_providers.dart (UseHebrewTerms, UseHebrewDate, ShowNikudPref,
// CurrentTransliterationVariant, CurrentFontSize) — not just UseHebrewTerms.
//
// BACKGROUND (see the original IL-1 fix, commit a8f05140, and
// test/core/preferences/hebrew_terms_sentinel_test.dart): activeProfileIdProvider
// transiently emits the sentinel value 0 whenever userDatabaseProvider is
// invalidated (e.g. during the offline-signup DB switch), before settling
// back to the real profile id moments later. A notifier whose build() calls
// ref.watch(activeProfileIdProvider) and unconditionally re-binds its
// SharedPreferences observer will, for the duration of that transient
// window, rebind to profile-0's stored/legacy/default value — visibly
// flipping the setting away from the user's real choice, and silently
// misfiling any toggle tapped inside that window under profile 0's key.
//
// UseHebrewTerms already carries the guard (_hasBindingForRealProfile).
// UseHebrewDate, ShowNikudPref, CurrentTransliterationVariant and
// CurrentFontSize used the byte-for-byte identical
// ref.watch(activeProfileIdProvider) + _bindObserver(...) shape but had no
// guard.
//
// Each test below drives a real-id -> 0 -> real-id transition through a
// ProviderContainer and asserts the notifier's state is preserved
// throughout — i.e. it never observably becomes profile 0's (default)
// value while the real profile id is merely transiting through the
// sentinel.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A mutable [ActiveProfileId] that can be updated after build, simulating
/// activeProfileIdProvider's real-id -> sentinel(0) -> real-id transition
/// (same shape as the K-series tests in
/// test/features/notifications/presentation/providers/reminder_enabled_cold_start_test.dart).
class _MutableProfileId extends ActiveProfileId {
  final int _initial;

  _MutableProfileId(this._initial);

  @override
  int build() => _initial;

  void set(int id) => state = id;
}

/// Builds a container with a [_MutableProfileId] starting at [startId], plus
/// the notifier so tests can drive profile-id transitions directly.
(ProviderContainer, _MutableProfileId) _makeContainer({required int startId}) {
  late _MutableProfileId notifier;
  final container = ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(() {
        notifier = _MutableProfileId(startId);
        return notifier;
      }),
    ],
  );
  container.read(activeProfileIdProvider);
  return (container, notifier);
}

/// Triggers a (re)build via [read] if one is pending, then drains the
/// microtask/task queue so the async `pref.read(profileId).then(onValue)`
/// chain inside `_bindObserver` (preference_providers.dart) settles, and
/// returns the settled value.
///
/// A single `container.read(provider)` only returns the SYNCHRONOUS part of
/// build() (`pref.defaultValue`, or the preserved `state` under the
/// sentinel guard) — the real persisted value arrives one async hop later.
/// Reading again after `pumpEventQueue()` observes the settled state.
Future<T> _readSettled<T>(T Function() read) async {
  read();
  await pumpEventQueue();
  return read();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const realProfileId = 42;

  group('AUD-core-preferences-01 — IL-1 sentinel-0 guard, all 5 notifiers', () {
    test(
      'UseHebrewDate preserves real-profile state across a 0-sentinel blip',
      () async {
        // Real profile 42 explicitly chose English (Gregorian) calendar —
        // the non-default value. Profile 0 has nothing stored, so an
        // unguarded rebind would fall back to defaultValue (true).
        SharedPreferences.setMockInitialValues({
          ProfileScopedPreferenceKeys.useHebrewCalendar(realProfileId): false,
        });

        final (container, profileNotifier) = _makeContainer(
          startId: realProfileId,
        );
        addTearDown(container.dispose);

        expect(
          await _readSettled(() => container.read(useHebrewDateProvider)),
          isFalse,
          reason: 'Real profile 42 persisted false (English calendar)',
        );

        // Transient sentinel-0 blip (offline-signup DB switch).
        profileNotifier.set(0);
        expect(
          await _readSettled(() => container.read(useHebrewDateProvider)),
          isFalse,
          reason:
              'Sentinel-0 blip must NOT rebind onto profile 0\'s default '
              '(true) — the guard must preserve the last real value',
        );

        // Real id resettles.
        profileNotifier.set(realProfileId);
        expect(
          await _readSettled(() => container.read(useHebrewDateProvider)),
          isFalse,
          reason: 'State must remain correct after the id resettles',
        );
      },
    );

    test(
      'ShowNikudPref preserves real-profile state across a 0-sentinel blip',
      () async {
        SharedPreferences.setMockInitialValues({
          ProfileScopedPreferenceKeys.textShowNikud(realProfileId): false,
        });

        final (container, profileNotifier) = _makeContainer(
          startId: realProfileId,
        );
        addTearDown(container.dispose);

        expect(
          await _readSettled(() => container.read(showNikudPrefProvider)),
          isFalse,
        );

        profileNotifier.set(0);
        expect(
          await _readSettled(() => container.read(showNikudPrefProvider)),
          isFalse,
          reason:
              'Sentinel-0 blip must NOT rebind onto profile 0\'s default '
              '(true nikud) — the guard must preserve the last real value',
        );

        profileNotifier.set(realProfileId);
        expect(
          await _readSettled(() => container.read(showNikudPrefProvider)),
          isFalse,
        );
      },
    );

    test('CurrentTransliterationVariant preserves real-profile state across a '
        '0-sentinel blip', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.transliterationVariant(realProfileId):
            TransliterationVariant.sephardi.name,
      });

      final (container, profileNotifier) = _makeContainer(
        startId: realProfileId,
      );
      addTearDown(container.dispose);

      expect(
        await _readSettled(
          () => container.read(currentTransliterationVariantProvider),
        ),
        TransliterationVariant.sephardi,
      );

      profileNotifier.set(0);
      expect(
        await _readSettled(
          () => container.read(currentTransliterationVariantProvider),
        ),
        TransliterationVariant.sephardi,
        reason:
            'Sentinel-0 blip must NOT rebind onto profile 0\'s default '
            '(ashkenazi) — the guard must preserve the last real value',
      );

      profileNotifier.set(realProfileId);
      expect(
        await _readSettled(
          () => container.read(currentTransliterationVariantProvider),
        ),
        TransliterationVariant.sephardi,
      );
    });

    test(
      'CurrentFontSize preserves real-profile state across a 0-sentinel blip',
      () async {
        SharedPreferences.setMockInitialValues({
          ProfileScopedPreferenceKeys.textFontSize(realProfileId):
              FontSize.large.index,
        });

        final (container, profileNotifier) = _makeContainer(
          startId: realProfileId,
        );
        addTearDown(container.dispose);

        expect(
          await _readSettled(() => container.read(currentFontSizeProvider)),
          FontSize.large,
        );

        profileNotifier.set(0);
        expect(
          await _readSettled(() => container.read(currentFontSizeProvider)),
          FontSize.large,
          reason:
              'Sentinel-0 blip must NOT rebind onto profile 0\'s default '
              '(medium) — the guard must preserve the last real value',
        );

        profileNotifier.set(realProfileId);
        expect(
          await _readSettled(() => container.read(currentFontSizeProvider)),
          FontSize.large,
        );
      },
    );

    test('UseHebrewTerms preserves real-profile state across a 0-sentinel blip '
        '(already-fixed baseline, kept alongside the other 4 for full '
        'ProviderContainer coverage per AC-2)', () async {
      SharedPreferences.setMockInitialValues({
        ProfileScopedPreferenceKeys.hebrewTermsScript(realProfileId): false,
      });

      final (container, profileNotifier) = _makeContainer(
        startId: realProfileId,
      );
      addTearDown(container.dispose);

      expect(
        await _readSettled(() => container.read(useHebrewTermsProvider)),
        isFalse,
      );

      profileNotifier.set(0);
      expect(
        await _readSettled(() => container.read(useHebrewTermsProvider)),
        isFalse,
        reason:
            'Sentinel-0 blip must NOT rebind onto profile 0\'s default '
            '(true) — the guard must preserve the last real value',
      );

      profileNotifier.set(realProfileId);
      expect(
        await _readSettled(() => container.read(useHebrewTermsProvider)),
        isFalse,
      );
    });
  });
}
