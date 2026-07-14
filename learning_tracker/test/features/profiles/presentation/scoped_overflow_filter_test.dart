// Unit tests for [isKnownSmallOverflow] (AUD-t-profiles-06).
//
// Lives here (not test/helpers/) because `make audit`'s
// tool/check_test_helpers_duplicate_functions.dart (AUD-t-cross-12) treats
// every file's top-level `void main()` as a "public top-level function" and
// flags a SECOND `*_test.dart` file directly under test/helpers/ as a
// collision with the existing golden_font_loader_test.dart — a real,
// pre-existing tooling gap, not something this finding's scope covers.
//
// RED → GREEN cycle:
//   RED:  test/helpers/scoped_overflow_filter.dart does not exist yet — this
//         file fails to compile/resolve.
//   GREEN: the helper exists and correctly discriminates the KNOWN, tracked
//          "residual small profile-grid" overflow (a few pixels) from an
//          UNRELATED, larger overflow that must still fail a test.
@Tags(['unit', 'profiles', 'overflow_filter'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/scoped_overflow_filter.dart';

/// Builds a synthetic [FlutterErrorDetails] mimicking the exact exception
/// Flutter's rendering library reports for a RenderFlex overflow (see
/// `debug_overflow_indicator.dart`'s `_reportOverflow`), without needing to
/// actually pump a widget tree.
FlutterErrorDetails _syntheticOverflow(
  double pixels, {
  String edge = 'bottom',
}) {
  final formatted = pixels > 10.0
      ? pixels.toStringAsFixed(0)
      : pixels.toStringAsFixed(1);
  return FlutterErrorDetails(
    exception: FlutterError(
      'A RenderFlex overflowed by $formatted pixels on the $edge.',
    ),
    library: 'rendering library',
  );
}

void main() {
  group('isKnownSmallOverflow', () {
    test(
      'a 3.6px overflow (the known profile-grid overflow magnitude) matches',
      () {
        expect(isKnownSmallOverflow(_syntheticOverflow(3.6)), isTrue);
      },
    );

    test('a 0px-adjacent (e.g. 0.9px) overflow matches', () {
      expect(isKnownSmallOverflow(_syntheticOverflow(0.9)), isTrue);
    });

    test('a large (500px) overflow from an UNRELATED widget does NOT match — '
        'AUD-t-profiles-06: the old blanket `.contains("overflowed")` check '
        'would have swallowed this too', () {
      expect(isKnownSmallOverflow(_syntheticOverflow(500)), isFalse);
    });

    test('an overflow exactly at the default threshold boundary matches', () {
      expect(
        isKnownSmallOverflow(_syntheticOverflow(15), maxPixels: 15),
        isTrue,
      );
    });

    test('an overflow just above the threshold does NOT match', () {
      // 16 (not 15.1): Flutter's own overflow-message formatter rounds any
      // value > 10px to a whole number (`_formatPixels` in
      // debug_overflow_indicator.dart), so a 15.1px overflow is reported as
      // "15 pixels" — indistinguishable from exactly 15. Use a value whose
      // rounded, reported form is unambiguously above the threshold.
      expect(
        isKnownSmallOverflow(_syntheticOverflow(16), maxPixels: 15),
        isFalse,
      );
    });

    test('a non-overflow FlutterError does NOT match', () {
      final details = FlutterErrorDetails(
        exception: FlutterError('Some unrelated rendering error.'),
        library: 'rendering library',
      );
      expect(isKnownSmallOverflow(details), isFalse);
    });

    test('a non-FlutterError exception does NOT match', () {
      final details = FlutterErrorDetails(
        exception: Exception('not a FlutterError at all'),
        library: 'rendering library',
      );
      expect(isKnownSmallOverflow(details), isFalse);
    });
  });
}
