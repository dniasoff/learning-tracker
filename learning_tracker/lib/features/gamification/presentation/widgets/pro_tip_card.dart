import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Amber tip card shown below the achievements list with a pro-tip about
/// earning more points.
class ProTipCard extends StatelessWidget {
  const ProTipCard({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.gamifProTipCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gamifProTipBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.gamifProTipShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lightbulb_rounded,
                size: 26,
                color: AppColors.gamifProTipTitleText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.gamifTierBronzeTitle,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${l10n.achievementsProTipTitle} ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.gamifTierBronzeTagFg,
                      ),
                    ),
                    TextSpan(text: l10n.achievementsProTipBody),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
