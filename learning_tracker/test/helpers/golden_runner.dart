/// Golden test runner with automatic locale + brightness variants
/// (DNI-377 / 27.1; brightness axis added for R2 — golden matrix).
///
/// `goldenTest(name, builder: …)` registers FOUR tests — one per
/// `(locale, brightness)` pair — from a single call. Each variant pumps the
/// widget under the corresponding `Locale`/`Brightness` and matches against
/// `test/golden/goldens/<name>.<lang>.<brightness>.png`.
///
/// Why two locales? UI bugs that only manifest in RTL Hebrew layouts (or
/// only in English) cost the team a release window in E18; locking both
/// renderings into goldens makes them regression-visible (NFR13).
///
/// Why two brightnesses? The `theme/royal-blue-brightness-aware-palette`
/// migration made every screen brightness-aware (light + dark themes share
/// one `AppTheme._build` and the app follows `ThemeMode.system` in
/// production) — a token that resolves correctly in light but regresses in
/// dark (or vice versa) previously had zero pixel coverage. `builder`
/// receives the `Brightness` so callers can pick the matching `ThemeData`
/// (typically `AppTheme.themeFor(brightness: brightness)`).
///
/// Skip the actual `matchesGoldenFile` assertion by passing
/// `skipGolden: true` — useful when wiring up new tests on a CI runner
/// that has not yet had the goldens baselined.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The supported locale variants. English drives the LTR rendering;
/// Hebrew drives the RTL rendering.
const List<Locale> _localeVariants = [Locale('en'), Locale('he')];

/// The supported brightness variants. Light and dark share one theme
/// builder (`AppTheme._build`), so any token that diverges between them
/// (or fails to) is a genuine, catchable pixel difference.
const List<Brightness> _brightnessVariants = [
  Brightness.light,
  Brightness.dark,
];

/// One `(name, locale, brightness)` triple that [goldenTest] has
/// registered a `testWidgets` entry for.
///
/// Story-acceptance suites assert against [registeredGoldenTests] instead
/// of a local hardcoded copy of a shape/locale list, so the assertion
/// tracks what this runner actually registers rather than a disconnected
/// duplicate (AUD-t-story-acceptance-16).
class GoldenTestRegistration {
  const GoldenTestRegistration({
    required this.name,
    required this.locale,
    required this.brightness,
  });

  /// The golden test's base name, before the ` [locale/brightness]` suffix.
  final String name;

  /// The locale this registration was pumped with.
  final Locale locale;

  /// The brightness this registration was pumped with.
  final Brightness brightness;
}

/// Every `(name, locale, brightness)` triple [goldenTest] has registered,
/// in registration order.
///
/// `package:test`/`flutter_test` build the full declaration tree
/// (`group`/`test`/`testWidgets` calls) synchronously while `main()` runs,
/// before any test body executes — so by the time any `test()` body reads
/// this list, every `goldenTest()` call anywhere in the file (regardless
/// of its position relative to the reader) has already appended its
/// entries.
final List<GoldenTestRegistration> registeredGoldenTests = [];

/// Builder signature: receives the locale + brightness being exercised and
/// returns the widget to render. Tests use the locale to swap content
/// (Hebrew terms vs English glosses) and the brightness to pick the
/// matching theme when needed.
typedef GoldenBuilder = Widget Function(Locale locale, Brightness brightness);

/// Register a golden test for [name] across English/Hebrew locales and
/// light/dark brightness.
///
/// Each variant produces an independent test entry visible to
/// `flutter test` so a failure in one rendering does not mask the others.
/// The golden file naming convention is
/// `test/golden/goldens/<name>.<lang>.<brightness>.png`.
void goldenTest(
  String name, {
  required GoldenBuilder builder,
  Size surfaceSize = const Size(360, 640),
  bool skipGolden = false,
}) {
  for (final brightness in _brightnessVariants) {
    for (final locale in _localeVariants) {
      registeredGoldenTests.add(
        GoldenTestRegistration(
          name: name,
          locale: locale,
          brightness: brightness,
        ),
      );
      testWidgets('$name [${locale.languageCode}/${brightness.name}]', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(surfaceSize);
        try {
          await tester.pumpWidget(
            _GoldenHarness(locale: locale, child: builder(locale, brightness)),
          );
          await tester.pumpAndSettle();

          if (skipGolden) return;
          await expectLater(
            find.byType(_GoldenHarness),
            matchesGoldenFile(
              'goldens/$name.${locale.languageCode}.${brightness.name}.png',
            ),
          );
        } finally {
          await tester.binding.setSurfaceSize(null);
        }
      });
    }
  }
}

/// Minimal `WidgetsApp`-style harness that pins the requested [Locale]
/// and forces the matching `TextDirection` (RTL for Hebrew, LTR for
/// English). We deliberately do NOT use `MaterialApp` here to keep the
/// surface area minimal — tests that need a full Material scaffold can
/// supply one inside [child].
class _GoldenHarness extends StatelessWidget {
  const _GoldenHarness({required this.locale, required this.child});

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isRtl = locale.languageCode == 'he';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Localizations(
        locale: locale,
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: MediaQuery(data: const MediaQueryData(), child: child),
      ),
    );
  }
}
