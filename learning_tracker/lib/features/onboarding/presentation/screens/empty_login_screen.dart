// WS2.surface — Empty-login surface.
//
// Shown when a user has zero profiles and has previously skipped profile
// creation (DEC-6: "skip → empty login").
//
// Minimal surface per the entity-model remediation plan:
//   - "Add a profile" CTA (reuses SkippedOnboardingCtaBanner)
//   - Device settings entry
//   - Stub tutor entry point ("I'm a tutor") — WS3 wired the full flow
//   - Device notification toggle (layer 1, WS5.two-layers)

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class EmptyLoginScreen extends ConsumerWidget {
  const EmptyLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learningTracker),
        actions: [
          // R1o-H2: account-switch affordance. A 0-profile account previously
          // had no way back to the user's other accounts from this surface.
          // Reuse the canonical multi-account switch surface (AccountPicker),
          // count-gated so it only appears when another account exists.
          FutureBuilder<List<DeviceAccount>>(
            future: ref.read(deviceRegistryProvider).getAllAccounts(),
            builder: (context, snapshot) {
              final accountCount = snapshot.data?.length ?? 0;
              if (accountCount < 2) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.switch_account_outlined),
                tooltip: l10n.switchAccount,
                onPressed: () =>
                    unawaited(context.router.push(const AccountPickerRoute())),
              );
            },
          ),
          // Device settings entry
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () =>
                unawaited(context.router.push(const SettingsRoute())),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.2),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary CTA: reuse the existing skipped-onboarding banner
                // (it surfaces "Set up a learning track" + "Accept a tutor invite").
                const SkippedOnboardingCtaBanner(),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Tutor entry point stub — WS3 will wire the full invitation flow.
                OutlinedButton.icon(
                  key: const Key('empty_login_tutor_entry'),
                  icon: const Icon(Icons.school_outlined),
                  label: Text(l10n.emptyLoginTutorEntry),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brandBlueDeep,
                    side: const BorderSide(color: AppTheme.brandBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    // S6: route to the picker — TALMID PROFILES section shows
                    // active grants. Profile creation remains optional from there.
                    unawaited(
                      context.router.replaceAll([const ProfilePickerRoute()]),
                    );
                  },
                ),

                // Device-level OS notification permission is requested up front
                // in the first-run intro flow (see AppIntroScreen) and can be
                // managed afterwards under Settings → Notification Settings, so
                // no device-notification toggle is surfaced on this landing.
              ],
            ),
          ),
        ),
      ),
    );
  }
}
