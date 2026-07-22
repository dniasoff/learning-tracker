/// Regression test for AUD-gamification-09 (AX-1): TierIconBox's lock badge
/// must mirror under RTL. A plain `Positioned(right:, bottom:)` pins the
/// badge to the visual right, which is the LEADING edge in Hebrew RTL —
/// the badge should instead sit on the TRAILING corner in both directions
/// (see progress_summary_card.dart, which fixed the identical bug with
/// PositionedDirectional).
@Tags(['gamification', 'rtl'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart'
    show RewardTier;
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_icon_box.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_style.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _wrap({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('TierIconBox — lock badge RTL mirroring (AUD-gamification-09)', () {
    testWidgets(
      'RTL (Hebrew): lock badge sits on the trailing (left-in-RTL) corner',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            locale: const Locale('he'),
            child: TierIconBox(
              scheme: TierStyle.forTier(
                AppPalette.light,
                RewardTier.bronze,
                false,
              ),
              unlocked: false,
              comingSoon: true,
              rewardIconIndex: 0,
            ),
          ),
        );
        await tester.pump();

        expect(
          Directionality.of(tester.element(find.byType(TierIconBox))),
          TextDirection.rtl,
        );

        final boxRect = tester.getRect(find.byType(TierIconBox));
        final lockRect = tester.getRect(find.byIcon(Icons.lock_rounded));

        // Trailing edge in RTL is the LEFT edge — the lock badge's centre
        // must be closer to the box's left edge than to its right edge.
        final distanceToLeft = (lockRect.center.dx - boxRect.left).abs();
        final distanceToRight = (lockRect.center.dx - boxRect.right).abs();
        expect(
          distanceToLeft,
          lessThan(distanceToRight),
          reason:
              'lock badge should be pinned to the trailing (left) edge in RTL, '
              'not the visual right',
        );
      },
    );

    testWidgets(
      'LTR (English): lock badge sits on the trailing (right-in-LTR) corner',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            locale: const Locale('en'),
            child: TierIconBox(
              scheme: TierStyle.forTier(
                AppPalette.light,
                RewardTier.bronze,
                false,
              ),
              unlocked: false,
              comingSoon: true,
              rewardIconIndex: 0,
            ),
          ),
        );
        await tester.pump();

        final boxRect = tester.getRect(find.byType(TierIconBox));
        final lockRect = tester.getRect(find.byIcon(Icons.lock_rounded));

        final distanceToLeft = (lockRect.center.dx - boxRect.left).abs();
        final distanceToRight = (lockRect.center.dx - boxRect.right).abs();
        expect(distanceToRight, lessThan(distanceToLeft));
      },
    );
  });
}
