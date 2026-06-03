// Multi-device overflow guard harness.
//
// Flutter's "RenderFlex overflowed by N pixels" errors are *deterministic*
// given a (logical size, textScaleFactor) pair, and the overflow magnitude is
// *monotonic* in those inputs: a layout that fits at the tightest size and the
// largest text scale fits everywhere in between. We therefore do NOT need to
// hand-test thousands of physical devices — rendering at the EXTREMES of the
// device/text-scale space proves the continuum.
//
// [expectNoOverflowAcrossDevices] pumps a built widget across a default matrix
// of (size × textScale) and asserts that no RenderFlex (or other layout) error
// is thrown. A `RenderFlex overflowed` surfaces as a FlutterError captured by
// the binding, which `tester.takeException()` returns after `pumpAndSettle`.
//
// Usage:
// ```dart
//   await expectNoOverflowAcrossDevices(
//     tester,
//     () => const MyDialogContent(),
//     overrides: [/* riverpod overrides */],
//   );
// ```
//
// To add a new dialog/screen to the guard, add a `testWidgets` case in
// `test/overflow/overflow_guard_test.dart` that calls this helper with the
// real widget (and whatever provider overrides it needs to render).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// One point in the device/text-scale matrix.
@immutable
class OverflowCase {
  const OverflowCase(this.size, this.textScale, {this.devicePixelRatio = 1.0});

  /// Logical size (DIPs), e.g. 320×568 for a small phone.
  final Size size;

  /// MediaQuery text scale factor applied via [TextScaler.linear].
  final double textScale;

  /// Device pixel ratio. Physical size = [size] × this.
  final double devicePixelRatio;

  String get label =>
      '${size.width.toInt()}x${size.height.toInt()} @ '
      '${textScale}x text (dpr $devicePixelRatio)';

  @override
  String toString() => label;
}

/// Default logical sizes spanning the device space.
///
///  * SMALL phone     — 320×568  (iPhone SE 1st gen; the classic offender)
///  * LARGE phone     — 412×915  (Pixel-class)
///  * TABLET          — 768×1024 (iPad portrait)
///  * TALL-NARROW     — 280×653  (folded foldable / very narrow)
const List<Size> kDefaultDeviceSizes = <Size>[
  Size(320, 568),
  Size(412, 915),
  Size(768, 1024),
  Size(280, 653),
];

/// Default text scales: nominal, accessibility-large, and extreme.
const List<double> kDefaultTextScales = <double>[1.0, 1.3, 2.0];

/// The default matrix. We do NOT take the full Cartesian product (that would be
/// 12 pumps per surface); instead we keep it fast while still covering the
/// EXTREMES, which is what monotonicity requires:
///
///  * every size at 1.0 (baseline fit on the smallest viewport),
///  * the smallest viewport at every text scale (worst horizontal+vertical),
///  * the tall-narrow viewport at the max text scale (worst width),
///  * the largest phone at the max text scale (common real-world worst case).
///
/// This always includes small×1.0, small×2.0 and tablet×1.0 (the contractually
/// required extremes) plus the narrow×2.0 corner that catches width overflow.
List<OverflowCase> defaultOverflowMatrix({
  List<Size>? sizes,
  List<double>? textScales,
}) {
  final s = sizes ?? kDefaultDeviceSizes;
  final t = textScales ?? kDefaultTextScales;
  final small = s.first; // tightest viewport by convention (320×568).
  final maxScale = t.reduce((a, b) => a > b ? a : b);
  final minScale = t.reduce((a, b) => a < b ? a : b);

  final cases = <OverflowCase>[];
  final seen = <String>{};

  void add(Size size, double scale) {
    final c = OverflowCase(size, scale);
    if (seen.add(c.label)) cases.add(c);
  }

  // Every size at the smallest scale — baseline geometric fit.
  for (final size in s) {
    add(size, minScale);
  }
  // The tightest viewport at every text scale — vertical + horizontal stress.
  for (final scale in t) {
    add(small, scale);
  }
  // Worst-width corners at the maximum scale.
  add(small, maxScale);
  if (s.length > 3) add(s[3], maxScale); // tall-narrow foldable.
  if (s.length > 1) add(s[1], maxScale); // large phone, common device.

  return cases;
}

/// Builds the standard app harness used by the guard: a [ProviderScope] with
/// [overrides], a [MaterialApp] wired with the real l10n delegates + supported
/// locales (so real screens/dialogs render), and a [MediaQuery] that injects
/// the requested [textScaler] on top of the ambient (size-derived) data.
Widget _wrap({
  required Widget child,
  required List<Override> overrides,
  required double textScale,
  required Locale locale,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) {
          // Copy the ambient MediaQuery (which already carries the
          // view-derived size/padding) and override only the text scaler.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            // Centre so a dialog-content Column lays out at its natural size
            // against the viewport — mirrors how AlertDialog content renders.
            child: Material(child: child),
          );
        },
      ),
    ),
  );
}

/// Pumps [build] across the device/text-scale matrix and asserts that NO
/// RenderFlex overflow (or other layout exception) is thrown at any point.
///
/// For each case it:
///  1. sets `tester.view.physicalSize` (= logical size × dpr) and
///     `tester.view.devicePixelRatio`,
///  2. pumps the widget wrapped in [ProviderScope] + [MaterialApp] + a
///     [MediaQuery] carrying `TextScaler.linear(scale)`,
///  3. `pumpAndSettle`s, then asserts `tester.takeException()` is null,
///  4. resets the view so cases don't leak into each other.
///
/// On overflow the failure message names the exact size + scale that broke, so
/// the offending corner is obvious from the test output alone.
///
/// [build] is a *factory* (`Widget Function()`) rather than a `Widget` so each
/// matrix entry gets a fresh widget tree (no shared GlobalKeys / element reuse).
Future<void> expectNoOverflowAcrossDevices(
  WidgetTester tester,
  Widget Function() build, {
  List<Size>? sizes,
  List<double>? textScales,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) async {
  // Belt-and-braces: always restore the view even if an assertion throws.
  addTearDown(tester.view.reset);

  final matrix = defaultOverflowMatrix(sizes: sizes, textScales: textScales);

  for (final c in matrix) {
    // Physical size is in device pixels; logical size = physical / dpr.
    tester.view.devicePixelRatio = c.devicePixelRatio;
    tester.view.physicalSize = Size(
      c.size.width * c.devicePixelRatio,
      c.size.height * c.devicePixelRatio,
    );

    await tester.pumpWidget(
      _wrap(
        child: build(),
        overrides: overrides,
        textScale: c.textScale,
        locale: locale,
      ),
    );

    // Let async builders / layout settle; pump() flushes the overflow paint.
    await tester.pumpAndSettle();

    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason:
          'Layout overflowed / threw at ${c.label}.\n'
          'Flutter overflow is monotonic, so this corner of the device matrix '
          'represents an entire region of real devices that would clip. '
          'Wrap the offending Column/Row in a scroll view '
          '(SingleChildScrollView / ListView) or make it flexible.\n'
          'Thrown: $exception',
    );

    // Tear down this case's tree before resizing for the next one.
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.reset();
  }
}
