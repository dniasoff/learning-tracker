// Overflow guard — AchievementUnlockCelebration card (P1 dialog).
//
// Root cause guarded here: the celebration card was a fixed `Container(width:
// 340)` wrapping a Column (emoji + title + multi-line message + button) with no
// scroll/flex escape valve, so a long milestone name at large text scales
// overflowed the Column. The fix caps the card height to the viewport and wraps
// the Column in a SingleChildScrollView.
//
// The card body is now [AchievementUnlockCard], extracted from the private
// dialog so it can be rendered WITHOUT the looping confetti (which would hang
// pumpAndSettle). We pump it across the device/text-scale matrix with an
// intentionally long display name + milestone.
//
// DEC-32/GA-3 removed per-track rewards from the spend economy (every
// RewardMilestone is global now), so the card no longer takes/shows a track
// label — the long-track-name case this test guarded against no longer
// exists as a parameter.

@Tags(['overflow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../helpers/overflow_harness.dart';

// Deliberately long strings — the worst case for the message paragraph that
// previously overflowed.
const _kLongName = 'Avraham Yitzchak Yehoshua Mordechai';
const _kLongMilestone = 'The Grand Master Diamond Achievement of Persistence';

/// Renders the extracted card via a [Builder] so we have a real
/// [AppLocalizations] from the harness's MaterialApp.
Widget _card() => Builder(
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: AchievementUnlockCard(
        displayName: _kLongName,
        milestoneTitle: _kLongMilestone,
        l10n: l10n,
        onContinue: () {},
      ),
    );
  },
);

void main() {
  testWidgets(
    'AchievementUnlockCard (long name/milestone) does not overflow across '
    'the device matrix',
    (tester) async {
      await expectNoOverflowAcrossDevices(tester, _card);
    },
  );

  testWidgets('AchievementUnlockCard does not overflow in Hebrew (RTL)', (
    tester,
  ) async {
    await expectNoOverflowAcrossDevices(
      tester,
      _card,
      locale: const Locale('he'),
    );
  });
}
