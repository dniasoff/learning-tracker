/// Golden test runner with automatic locale variants (DNI-377 / 27.1).
///
/// `goldenTest(name, builder: …)` registers TWO tests — one per locale —
/// from a single call. Each variant pumps the widget under the
/// corresponding `Locale` and matches against
/// `test/golden/goldens/<name>.<lang>.png`.
///
/// Why two locales? UI bugs that only manifest in RTL Hebrew layouts (or
/// only in English) cost the team a release window in E18; locking both
/// renderings into goldens makes them regression-visible (NFR13).
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

/// One `(name, locale)` pair that [goldenTest] has registered a
/// `testWidgets` entry for.
///
/// Story-acceptance suites assert against [registeredGoldenTests] instead
/// of a local hardcoded copy of a shape/locale list, so the assertion
/// tracks what this runner actually registers rather than a disconnected
/// duplicate (AUD-t-story-acceptance-16).
class GoldenTestRegistration {
  const GoldenTestRegistration({required this.name, required this.locale});

  /// The golden test's base name, before the ` [locale]` suffix.
  final String name;

  /// The locale this registration was pumped with.
  final Locale locale;
}

/// Every `(name, locale)` pair [goldenTest] has registered, in
/// registration order.
///
/// `package:test`/`flutter_test` build the full declaration tree
/// (`group`/`test`/`testWidgets` calls) synchronously while `main()` runs,
/// before any test body executes — so by the time any `test()` body reads
/// this list, every `goldenTest()` call anywhere in the file (regardless
/// of its position relative to the reader) has already appended its
/// entries.
final List<GoldenTestRegistration> registeredGoldenTests = [];

/// Builder signature: receives the locale being exercised and returns
/// the widget to render. Tests use the locale to swap content (Hebrew
/// terms vs English glosses) when needed.
typedef GoldenBuilder = Widget Function(Locale locale);

/// Register a golden test for [name] across English and Hebrew locales.
///
/// Each variant produces an independent test entry visible to
/// `flutter test` so a failure in one rendering does not mask the other.
/// The golden file naming convention is
/// `test/golden/goldens/<name>.<lang>.png`.
void goldenTest(
  String name, {
  required GoldenBuilder builder,
  Size surfaceSize = const Size(360, 640),
  bool skipGolden = false,
}) {
  for (final locale in _localeVariants) {
    registeredGoldenTests.add(
      GoldenTestRegistration(name: name, locale: locale),
    );
    testWidgets('$name [${locale.languageCode}]', (tester) async {
      await tester.binding.setSurfaceSize(surfaceSize);
      try {
        await tester.pumpWidget(
          _GoldenHarness(locale: locale, child: builder(locale)),
        );
        await tester.pumpAndSettle();

        if (skipGolden) return;
        await expectLater(
          find.byType(_GoldenHarness),
          matchesGoldenFile('goldens/$name.${locale.languageCode}.png'),
        );
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });
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
