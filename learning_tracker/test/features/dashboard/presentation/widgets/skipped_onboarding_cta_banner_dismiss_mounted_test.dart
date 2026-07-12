// AUD-dashboard-02 (SM-4) regression guard for SkippedOnboardingCtaBanner's
// Dismiss handler.
//
// The Dismiss onPressed callback awaits clearOnboardingSkipState() (two
// awaited SharedPreferences.remove() platform-channel calls) and then
// immediately calls ref.invalidate(onboardingSkipStateProvider) with no
// mounted guard in between. If the banner is unmounted while that await is
// still in flight -- e.g. the user taps Dismiss then immediately navigates
// away, a plausible fast-tap-and-swipe sequence -- the resumed continuation
// touches a disposed ConsumerStatefulElement's ref, which throws a
// StateError from ConsumerStatefulElement._assertNotDisposed().
//
// This test gates SharedPreferences.remove() behind a Completer (via a
// custom SharedPreferencesStorePlatform) so it can deterministically unmount
// the banner mid-await and assert the resumed continuation is a clean no-op.
@Tags(['dashboard'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A [SharedPreferencesStorePlatform] whose [remove] suspends on a gate
/// until the test opens it. Lets the test unmount the widget while
/// clearOnboardingSkipState()'s two awaited SharedPreferences.remove() calls
/// are still in flight, mirroring a fast dismiss-then-navigate-away tap.
class _GatedSharedPreferencesStore extends InMemorySharedPreferencesStore {
  _GatedSharedPreferencesStore(super.data) : super.withData();

  final Completer<void> _removeGate = Completer<void>();

  void openGate() {
    if (!_removeGate.isCompleted) _removeGate.complete();
  }

  @override
  Future<bool> remove(String key) async {
    await _removeGate.future;
    return super.remove(key);
  }
}

/// Hosts [SkippedOnboardingCtaBanner] behind a [ValueNotifier]<bool> so the
/// test can unmount just the banner (not the whole ProviderScope) mid-await,
/// mirroring the dashboard navigating away while the dismiss write is still
/// in flight.
Widget _toggleableHost(ValueNotifier<bool> show) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (context, visible, _) => visible
              ? const SkippedOnboardingCtaBanner()
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Dismiss does not throw when the banner is unmounted mid-await '
      '(AUD-dashboard-02)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = _GatedSharedPreferencesStore({
      'flutter.$kOnboardingSkipped': true,
      'flutter.$kOnboardingJoinedToTutor': false,
    });
    SharedPreferencesStorePlatform.instance = store;

    final show = ValueNotifier<bool>(true);
    addTearDown(show.dispose);
    addTearDown(store.openGate);

    await tester.pumpWidget(_toggleableHost(show));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dismissFinder = find.widgetWithText(TextButton, 'Dismiss');
    expect(
      dismissFinder,
      findsOneWidget,
      reason:
          'Banner must be showing its skipped-state body with a '
          'Dismiss button before the tap can be driven.',
    );

    await tester.tap(dismissFinder);
    // Starts the onPressed callback; suspends on the gated remove() call.
    await tester.pump();

    // Unmount the banner while clearOnboardingSkipState() is still pending.
    show.value = false;
    await tester.pump();

    // Resolve the gated remove() calls now that the widget is gone.
    store.openGate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.takeException(),
      isNull,
      reason:
          'Resuming after the banner was unmounted mid-await must not '
          'throw -- a mounted guard must short-circuit before touching '
          'ref.invalidate.',
    );
  });
}
