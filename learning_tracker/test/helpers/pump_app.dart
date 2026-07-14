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

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Wraps [child] in the standard L1 pump rig: a [ProviderScope] with
/// [overrides], and a [MaterialApp] wired with the real l10n delegates +
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
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}
