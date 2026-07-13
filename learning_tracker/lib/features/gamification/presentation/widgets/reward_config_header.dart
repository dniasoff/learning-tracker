import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const Color _kNavy = AppTheme.brandBlueDeep;

/// App-bar-style header for [RewardConfigurationScreen] with a back button,
/// centred title, and a three-dot menu that opens the "Manage rewards" sheet.
class RewardConfigHeader extends StatelessWidget {
  const RewardConfigHeader({
    super.key,
    required this.topInset,
    required this.title,
    required this.onBack,
    required this.onMenuSelected,
  });

  final double topInset;
  final String title;
  final VoidCallback onBack;
  final void Function(String) onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: topInset + 4,
          start: 4,
          end: 4,
          bottom: 12,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: IconButton(
                padding: EdgeInsets.zero,
                // AX-3 / AUD-gamification-04: icon-only control — without a
                // label TalkBack/VoiceOver announce nothing for this back
                // button. `tooltip` alone is not enough on the current
                // Flutter SDK (it populates SemanticsData.tooltip, not
                // .label), so the Icon also carries `semanticLabel`, which
                // Flutter surfaces as Semantics(label:).
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  semanticLabel: MaterialLocalizations.of(
                    context,
                  ).backButtonTooltip,
                ),
                color: _kNavy,
                onPressed: onBack,
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert_rounded, color: _kNavy),
                onSelected: onMenuSelected,
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'manage',
                    child: Text(
                      AppLocalizations.of(ctx)!.rewardConfigMenuManageRewards,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
