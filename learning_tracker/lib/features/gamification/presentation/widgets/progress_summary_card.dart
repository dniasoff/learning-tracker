import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
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

  static const Color _kBrandBlue = AppTheme.brandBlue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBrandBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330038A8),
            blurRadius: 16,
            offset: Offset(0, 8),
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
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.achievementsRewardsFraction(unlocked, total),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  // Direction-agnostic gap: a leading ASCII space collapsed at
                  // the RTL boundary, rendering "0 / 0פרסים" with no space.
                  const SizedBox(width: 6),
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
