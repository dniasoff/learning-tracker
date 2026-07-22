import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Blur + lock overlay applied around a milestone card when the learner
/// has not yet unlocked the achievement. [lightBlur] uses a softer blur
/// for "coming soon" milestones.
class LockedAchievementShell extends StatelessWidget {
  const LockedAchievementShell({
    super.key,
    required this.child,
    required this.l10n,
    required this.thresholdPoints,
    required this.lightBlur,
  });

  final Widget child;
  final AppLocalizations l10n;
  final int thresholdPoints;
  final bool lightBlur;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = NumberFormat.decimalPattern(locale);
    final pointsLabel = fmt.format(thresholdPoints);
    final hint = l10n.achievementsLockedBlurHint(pointsLabel);
    final sigma = lightBlur ? 3.0 : 6.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          ),
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: lightBlur ? 0.08 : 0.14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 32,
                        color: lightBlur
                            ? context.colors.gamifInkSlateDark
                            : context.colors.gamifInkCharcoal,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.colors.gamifLockedShellInkDeepest,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
