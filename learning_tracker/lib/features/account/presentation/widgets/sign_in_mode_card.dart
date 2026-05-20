import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The connectivity/account-type hint card shown above the sign-in form.
///
/// Displays one of four states based on the detected sign-in mode:
/// - [SignInModeHint.cloud]        — online, cloud account or no match yet
/// - [SignInModeHint.cloudOffline] — cloud-born account but device is offline
/// - [SignInModeHint.local]        — device-only or offline + unknown account
/// - [SignInModeHint.unknown]      — renders nothing (SizedBox.shrink)
class SignInModeCard extends StatelessWidget {
  const SignInModeCard({super.key, required this.mode, required this.l10n});

  final SignInModeHint mode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (mode) {
      case SignInModeHint.cloud:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.brandBlueBright.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.brandBlueBright.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_done_rounded, color: AppTheme.brandBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.authModeCloud,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case SignInModeHint.cloudOffline:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.brandCoralSoft.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.brandCoralDeep.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.brandCoralDeep,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.authModeCloudOffline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case SignInModeHint.local:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.brandCoralSoft.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandCoralDeep.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.brandCoralDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.authModeLocalTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.brandCoralSoft.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandCoralDeep.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.dangerous_rounded,
                    color: AppTheme.brandCoralDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.authModeLocalBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case SignInModeHint.unknown:
        return const SizedBox.shrink();
    }
  }
}

/// Registry lookup result for the debounced email field. Connectivity is
/// applied separately so header cards track online/offline.
enum RegistryMatchKind { none, localBorn, cloudBorn, notOnDevice }

/// Hint that drives which [SignInModeCard] variant is shown.
enum SignInModeHint { cloud, cloudOffline, local, unknown }
