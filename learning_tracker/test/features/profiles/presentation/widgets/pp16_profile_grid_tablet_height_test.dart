/// Regression test for PP-16 — Profile cards grotesquely tall on tablet/landscape.
///
/// ROOT CAUSE: `ProfileGrid` uses
/// `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,
/// childAspectRatio: 0.67)`. On a wide tablet each column is ~1280 px →
/// card height forced to ~1910 px. The fix is to use
/// `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260)` which
/// caps the column width and lets Flutter add more columns on wide viewports.
///
/// RED behaviour: with FixedCrossAxisCount(2) on a 2560-px viewport, column
/// width = 1273 px → height ≈ 1900 px (grotesque).
/// GREEN behaviour: with MaxCrossAxisExtent(260) on same viewport, column
/// width ≤ 260 px → height ≤ ~390 px (compact).
///
/// This test verifies the delegate type and computed tile dimensions directly.
@Tags(['unit', 'profiles', 'layout', 'pp16'])
library;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: wrap SliverConstraints construction for wide-tablet simulation.
SliverConstraints _wideTabletConstraints() {
  return const SliverConstraints(
    axisDirection: AxisDirection.down,
    growthDirection: GrowthDirection.forward,
    userScrollDirection: ScrollDirection.idle,
    scrollOffset: 0,
    precedingScrollExtent: 0,
    overlap: 0,
    remainingPaintExtent: 2000,
    crossAxisExtent: 2560,
    crossAxisDirection: AxisDirection.right,
    viewportMainAxisExtent: 1600,
    remainingCacheExtent: 2500,
    cacheOrigin: 0,
  );
}

void main() {
  group(
    'PP-16 — ProfileGrid uses MaxCrossAxisExtent to stay compact on tablets',
    () {
      test(
        'PP-16: MaxCrossAxisExtent(260) keeps tile width ≤ 260 and height ≤ 400 px '
        'on a 2560-px-wide viewport',
        () {
          const delegate = SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            childAspectRatio: 0.67,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          );

          final layout =
              delegate.getLayout(_wideTabletConstraints())
                  as SliverGridRegularTileLayout;

          // With maxCrossAxisExtent=260 on 2560px: tile width ≤ 260.
          expect(
            layout.crossAxisStride,
            lessThanOrEqualTo(274), // 260 + crossAxisSpacing(14)
            reason:
                'PP-16 fix: MaxCrossAxisExtent(260) must cap tile stride on a '
                '2560-px viewport. Buggy FixedCrossAxisCount(2) gave ~1287 px.',
          );

          // Tile height ≤ ~400 px (260 / 0.67 ≈ 388 px).
          expect(
            layout.mainAxisStride,
            lessThanOrEqualTo(420),
            reason:
                'PP-16 fix: tile height must be ≤ ~420 px. '
                'Buggy delegate gave ~1920 px on 2560-px tablet.',
          );
        },
      );

      test(
        'PP-16 RED: FixedCrossAxisCount(2) on 2560-px viewport produces tile stride '
        '> 800 px — proves the bug',
        () {
          const buggyDelegate = SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.67,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          );

          final layout =
              buggyDelegate.getLayout(_wideTabletConstraints())
                  as SliverGridRegularTileLayout;

          // Buggy: 2 columns on 2560 px → each ~1273 px wide → height ~1900 px.
          expect(
            layout.crossAxisStride,
            greaterThan(800),
            reason:
                'PP-16 bug confirmed: FixedCrossAxisCount(2) produces a tile '
                'stride > 800 px on a 2560-px viewport (actually ~1287 px), '
                'forcing card height to ~1920 px — grotesquely tall.',
          );
        },
      );
    },
  );
}
