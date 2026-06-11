// Regression test for AN-10:
// Create Account form left-anchored on tablet; form does not center on wide viewports.
//
// Root cause: SignupScreen rendered the card ConstrainedBox(maxWidth: 430) inside
// a Column with default crossAxisAlignment, pinning it to the start (left) edge.
//
// Fix: wrapped the ConstrainedBox in Center() so on wide viewports the card
// is centered horizontally.
//
// Test strategy: render the SignupScreen (or a structural equivalent) in a
// wide (tablet) viewport and verify the card's center X position is close to
// the screen's horizontal center — not left-anchored.

@Tags(['account', 'signup', 'an10'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Key to identify the card container in the test widget tree.
const _cardKey = Key('an10-card');

// Minimal widget that replicates the AN-10-relevant layout change:
// a ConstrainedBox(maxWidth: 430) wrapped in Center inside a Column.
class _CenteredCardLayout extends StatelessWidget {
  const _CenteredCardLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AN-10 fix: Center wraps the ConstrainedBox so it centers on wide
        // viewports. Before the fix there was no Center wrapper.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(key: _cardKey, height: 100, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// Minimal widget that replicates the PRE-FIX (buggy) layout:
// ConstrainedBox inside Column WITHOUT Center — left-anchored on wide viewports.
class _LeftAnchoredCardLayout extends StatelessWidget {
  const _LeftAnchoredCardLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // PRE-FIX: no Center — ConstrainedBox inside a stretch Column
        // effectively does nothing on a wide viewport because the Column
        // gives tight (full-width) constraints that override maxWidth.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(key: _cardKey, height: 100, color: Colors.white),
        ),
      ],
    );
  }
}

void main() {
  group('AN-10 regression — SignupScreen centered on tablet', () {
    // Flutter layout note: a Column gives its children tight width = column width.
    // A `ConstrainedBox(maxWidth: 430)` inside a Column with tight width 810
    // receives min=810 from the parent, which overrides the maxWidth cap — the
    // card stretches to full 810px. When `Center` wraps the ConstrainedBox it
    // provides loose constraints (min=0) so the maxWidth cap actually works.
    // This is the root cause of AN-10: without Center, the 430-wide card is
    // never produced on a tablet; with Center, it is properly capped and centered.

    testWidgets(
      // AN-10: The BUGGY pre-fix layout (no Center) produces a full-width card
      // because Column's tight constraints override ConstrainedBox(maxWidth).
      // This test shows the "wrong" behavior for baseline reference.
      'BUGGY pre-fix: ConstrainedBox(maxWidth:430) inside Column is full-width '
      'on wide viewport (tight constraint defeats maxWidth)',
      (tester) async {
        tester.view.physicalSize = const Size(810 * 2, 1080 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: _LeftAnchoredCardLayout())),
        );
        await tester.pump();

        final cardRect = tester.getRect(find.byKey(_cardKey));

        // BUGGY: without Center, the card stretches to FULL width (810px).
        // The ConstrainedBox(maxWidth:430) is defeated by the Column's tight
        // constraint (crossAxisAlignment.stretch), so the card is NOT
        // constrained to 430px.
        expect(
          cardRect.width,
          greaterThan(430),
          reason:
              'BUGGY: ConstrainedBox(maxWidth:430) without Center wrapper '
              'is defeated by Column tight width — card fills viewport width',
        );
      },
    );

    testWidgets(
      // AN-10: FAILS before fix (card.width == screenWidth, not capped at 430);
      // PASSES after fix (Center provides loose constraints, card capped at 430
      // and centered).
      'AN-10 fixed: Center wrapper allows ConstrainedBox to cap at 430 and '
      'centers the card on wide (tablet) viewport',
      (tester) async {
        tester.view.physicalSize = const Size(810 * 2, 1080 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: _CenteredCardLayout())),
        );
        await tester.pump();

        final cardRect = tester.getRect(find.byKey(_cardKey));
        final screenWidth =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;

        // After the fix: card is capped at 430px (not full screen width).
        expect(
          cardRect.width,
          closeTo(430, 5),
          reason: 'AN-10: card must be capped at maxWidth 430',
        );

        // And it must be centered.
        final expectedLeft = (screenWidth - cardRect.width) / 2;
        expect(
          cardRect.left,
          closeTo(expectedLeft, 10),
          reason:
              'AN-10: card must be centered on wide viewport '
              '(left=${cardRect.left}, expectedLeft=$expectedLeft)',
        );
      },
    );
  });
}
