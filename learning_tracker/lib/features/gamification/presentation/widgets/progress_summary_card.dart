import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Blue summary card at the top of the achievements list showing
/// unlocked vs total milestone counts.
class ProgressSummaryCard extends StatelessWidget {
  const ProgressSummaryCard({
    super.key,
    required this.l10n,
    required this.unlocked,
    required this.total,
  });

  final AppLocalizations l10n;
  final int unlocked;
  final int total;

  // AUD-darkmode: brandBlue is an ACCENT role that intentionally LIGHTENS in
  // dark mode (paired with a dynamically computed onPrimary foreground for
  // buttons), but this hero card paints it as a solid FILL with hardcoded
  // white text -- measured 2.52:1 in dark. gamifProgressSummaryFill is
  // pinned to the exact old brandBlue light literal (0xFF1442B8) in both
  // themes, restoring 8.41:1.
  static Color _kBrandBlue(BuildContext context) =>
      context.colors.gamifProgressSummaryFill;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBrandBlue(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.navItemSelectedShadow,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // PositionedDirectional so the badge sits on the TRAILING corner in
          // both LTR and RTL. With a plain Positioned(right:) it stayed on the
          // visual right — the LEADING edge in Hebrew RTL — and collided with
          // the right-aligned header text "התקדמות שלך".
          PositionedDirectional(
            end: -4,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                // AUD-darkmode: statusErrorCardText is TEXT/icon ink paired
                // with statusErrorCardBg (lightens for legibility against a
                // darkening card), but this small badge paints it as a FILL
                // with a hardcoded white icon -- measured 2.71:1 in dark.
                // gamifProgressSummaryBadgeFill is pinned to the exact old
                // statusErrorCardText light literal (0xFFD51F1B) in both
                // themes, restoring 5.20:1.
                color: context.colors.gamifProgressSummaryBadgeFill,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.achievementsYourProgress,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    l10n.achievementsRewardsFraction(unlocked, total),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    l10n.achievementsRewardsLabelWord,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.achievementsEncouragement,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
