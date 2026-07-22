// Shared L1 widget-test pump rig.
//
// [TQ-3] "Widget tests pump through a shared `pumpApp` helper (ProviderScope
// overrides + localization delegates), and key screens include a
// `Locale('he')` (RTL) variant." — before this helper, each onboarding L1
// test file hand-rolled its own ~20-line
// `ProviderScope > MaterialApp(locale, 4 l10n delegates, supportedLocales)`
// block (see AUD-t-onboarding-02). This mirrors `overflow_harness.dart`'s
// `_wrap` — the one place in the repo that already did this correctly — so
// there is now a single place to update when a new l10n delegate or
// supported-locales source is introduced.
//
// The profiles feature hand-rolled the identical block a further 13 times
// across 4 files (AUD-t-profiles-02), which migrated onto this helper too
// and added the second provider-wiring mode documented below. The
// gamification feature hand-rolled it 8 more times across 6 files
// (AUD-t-gamification-06), which migrated onto this helper as well. A
// second profiles batch — 15 more files, 35 sites — hand-rolled the same
// block independently (AUD-t-profiles-03); those migrated onto this helper
// too, and `tool/check_tq3_pump_app_migration.dart`'s ratchet baseline was
// lowered accordingly.
//
// The tutoring feature's accept/decline-invite L1 + overflow tests
// hand-rolled the block another 4 times across 4 files (AUD-t-tutoring-03).
// Two of those sites (the "driven" success/error states in the overflow
// tests) also needed a per-frame `MaterialApp.builder` to inject a
// `TextScaler` override while looping the device/text-scale matrix — a need
// this helper did not previously support — so [builder] and
// [debugShowCheckedModeBanner] were added below (both optional, both
// preserving every pre-existing call site's behavior via their defaults).
//
// R2 (golden matrix, brightness axis): [theme] was added so golden-test
// harnesses can pump the real `AppTheme.themeFor(brightness: …)` and
// exercise both light and dark renderings through this same shared rig,
// instead of a parallel hand-rolled `MaterialApp`. `null` (the default)
// preserves every pre-existing call site's behavior — `MaterialApp` falls
// back to its own default `ThemeData.light()` exactly as before.
//
// Usage:
// ```dart
//   await tester.pumpWidget(
//     pumpApp(
//       child: const MyScreen(),
//       overrides: [myProvider.overrideWithValue(fake)],
//       locale: const Locale('he'),
//     ),
//   );
// ```
//
// Two provider-wiring modes are supported:
//   - the common case: pass [overrides] (and optionally [retry]) and
//     [pumpApp] creates a fresh `ProviderScope` for you.
//   - the shared-container case (tests that need to `container.read(...)`
//     the SAME container the widget tree uses, e.g. across a pump/re-pump
//     remount): pass an existing [container] and [pumpApp] wraps it in
//     `UncontrolledProviderScope` instead. [overrides]/[retry] are ignored
//     when [container] is supplied — the container already carries its own
//     overrides.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is part of Riverpod's public API but is only re-exported from
// flutter_riverpod's `misc.dart` entrypoint (not the main
// `flutter_riverpod.dart` barrel) — see riverpod.dev's package layout.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Wraps [child] in the standard L1 pump rig: a [ProviderScope] (or, when
/// [container] is supplied, an [UncontrolledProviderScope] around that
/// container) and a [MaterialApp] wired with the real l10n delegates +
/// supported locales (so real screens/widgets render text instead of
/// throwing or showing raw keys) and [locale].
///
/// [child] becomes `MaterialApp.home` directly — callers that need a
/// [Scaffold], `StackRouterScope`, or other ancestor build it themselves and
/// pass the result in, exactly as the pre-extraction call sites did.
Widget pumpApp({
  required Widget child,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  // Matches ProviderContainer's `Retry` typedef (Duration? Function(int
  // retryCount, Object error)) — spelled out because that typedef isn't
  // re-exported from any flutter_riverpod public entrypoint.
  Duration? Function(int retryCount, Object error)? retry,
  ProviderContainer? container,
  // Forwarded straight to `MaterialApp.builder` — lets callers inject
  // ancestor state (e.g. a `MediaQuery` carrying a `TextScaler` override for
  // an overflow-matrix sweep) around `home` on every rebuild. `null` (the
  // default) matches every pre-existing call site's behavior.
  TransitionBuilder? builder,
  // Forwarded straight to `MaterialApp.debugShowCheckedModeBanner`. Defaults
  // to `true`, matching `MaterialApp`'s own default and every pre-existing
  // `pumpApp` call site's behavior.
  bool debugShowCheckedModeBanner = true,
  // Forwarded straight to `MaterialApp.theme`. `null` (the default) matches
  // every pre-existing `pumpApp` call site's behavior (MaterialApp's own
  // default light theme). Golden-matrix tests pass
  // `AppTheme.themeFor(brightness: brightness)` to sweep light + dark.
  ThemeData? theme,
}) {
  final app = MaterialApp(
    locale: locale,
    debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    theme: theme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: builder,
    home: child,
  );

  if (container != null) {
    return UncontrolledProviderScope(container: container, child: app);
  }

  return ProviderScope(retry: retry, overrides: overrides, child: app);
}
