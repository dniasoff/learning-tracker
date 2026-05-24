// WS2.surface — Empty-login surface.
//
// Shown when a user has zero profiles and has previously skipped profile
// creation (DEC-6: "skip → empty login").
//
// Minimal surface per the entity-model remediation plan:
//   - "Add a profile" CTA (reuses SkippedOnboardingCtaBanner)
//   - Device settings entry
//   - Stub tutor entry point ("I'm a tutor") — WS3 will wire the full flow
//   - Device notification toggle stub — WS5 will wire the real toggle

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart';

@RoutePage()
class EmptyLoginScreen extends ConsumerWidget {
  const EmptyLoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Tracker'),
        actions: [
          // Device settings entry
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => unawaited(context.router.push(const SettingsRoute())),
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
                  label: const Text("I'm a tutor"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.brandBlueDeep,
                    side: const BorderSide(color: AppTheme.brandBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    // WS3 will replace this with navigation to the tutor
                    // invitation-acceptance flow (ManageGrantsRoute /
                    // AcceptInviteRoute). For now, show a message.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tutor access coming soon. Ask the parent to share '
                          'an invite link with you.',
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Device notification toggle stub — WS5 will provide the real
                // device-level OS toggle (layer 1).
                _NotificationToggleStub(theme: theme),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stub device-level notification toggle.
///
/// WS5 will replace this with the real two-layer notification control
/// (device OS toggle + per-profile reminder schedules).
class _NotificationToggleStub extends StatefulWidget {
  const _NotificationToggleStub({required this.theme});

  final ThemeData theme;

  @override
  State<_NotificationToggleStub> createState() =>
      _NotificationToggleStubState();
}

class _NotificationToggleStubState extends State<_NotificationToggleStub> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('empty_login_notification_toggle'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: const Text('Device notifications'),
        subtitle: const Text('Allow app to send reminders'),
        value: _notificationsEnabled,
        onChanged: (v) => setState(() => _notificationsEnabled = v),
        activeThumbColor: AppTheme.brandBlue,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
