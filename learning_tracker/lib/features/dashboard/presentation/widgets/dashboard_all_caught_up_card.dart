import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Stats card when today due, overdue, and chazara counts are all zero.
class DashboardAllCaughtUpCard extends StatelessWidget {
  const DashboardAllCaughtUpCard({
    super.key,
    required this.doneDisplay,
    required this.cumulativeLifetime,
  });

  final String doneDisplay;
  final double cumulativeLifetime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E52D4),
                      Color(0xFF1639A8),
                      Color(0xFF0E266F),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -14,
              child: Icon(
                Icons.menu_book_rounded,
                size: 172,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 34,
                        color: Color(0xFF1639A8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.dashboardAllCaughtUpTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.dashboardAllCaughtUpSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dashboardLifetimeProgress,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        doneDisplay,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          context.router.navigate(const ProgressRoute()),
                      borderRadius: BorderRadius.circular(999),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedProgressBar(
                          value: cumulativeLifetime,
                          color: kAllCaughtUpProgressFill,
                          backgroundColor: const Color(
                            0xFF0A1F4D,
                          ).withValues(alpha: 0.55),
                          height: 12,
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                        ),
                      ),
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
