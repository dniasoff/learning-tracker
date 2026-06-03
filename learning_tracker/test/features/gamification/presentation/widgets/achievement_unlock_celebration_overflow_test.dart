// Overflow guard — AchievementUnlockCelebration card (P1 dialog).
//
// Root cause guarded here: the celebration card was a fixed `Container(width:
// 340)` wrapping a Column (emoji + title + multi-line message + button) with no
// scroll/flex escape valve, so a long milestone/track name at large text scales
// overflowed the Column. The fix caps the card height to the viewport and wraps
// the Column in a SingleChildScrollView.
//
// The card body is now [AchievementUnlockCard], extracted from the private
// dialog so it can be rendered WITHOUT the looping confetti (which would hang
// pumpAndSettle). We pump it across the device/text-scale matrix with an
// intentionally long display name + milestone + track label.

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
const _kLongTrack = 'Daf Yomi — Talmud Bavli, Tractate Bava Basra (Full Cycle)';

/// Renders the extracted card via a [Builder] so we have a real
/// [AppLocalizations] from the harness's MaterialApp.
Widget _card() => Builder(
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: AchievementUnlockCard(
        displayName: _kLongName,
        milestoneTitle: _kLongMilestone,
        trackLabel: _kLongTrack,
        l10n: l10n,
        onContinue: () {},
      ),
    );
  },
);

void main() {
  testWidgets(
    'AchievementUnlockCard (long name/milestone/track) does not overflow across '
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
