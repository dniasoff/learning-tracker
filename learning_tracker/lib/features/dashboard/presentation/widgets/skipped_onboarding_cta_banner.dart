// W6.3 — "Skip for now" / "Join to tutor" empty-state CTA banner.
//
// Shown on the dashboard when the user skipped track setup during onboarding
// (OnboardingIntent.skipForNow or OnboardingIntent.joiningToTutor).
//
// CTA buttons:
//  - "Set up a learning track"   → TrackManagementHub (startAdding: true)
//  - "Accept a tutor invite"     → placeholder until W6.9 invite-acceptance screen

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'skipped_onboarding_cta_banner.g.dart';

/// Keys written by onboarding_screen when the user skips track setup.
const kOnboardingSkipped = 'onboarding_skipped';
const kOnboardingJoinedToTutor = 'onboarding_joined_to_tutor';

// ── Riverpod provider ───────────────────────────────────────────────────────

/// Returns `(skipped: bool, joinedToTutor: bool)` from SharedPreferences.
///
/// When [skipped] is true the dashboard shows the CTA banner.
/// [joinedToTutor] adjusts the primary CTA copy.
@riverpod
Future<({bool skipped, bool joinedToTutor})> onboardingSkipState(
  Ref ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  final skipped = prefs.getBool(kOnboardingSkipped) ?? false;
  final joinedToTutor = prefs.getBool(kOnboardingJoinedToTutor) ?? false;
  return (skipped: skipped, joinedToTutor: joinedToTutor);
}

/// Clears the skip-state flags so the banner is no longer shown.
Future<void> clearOnboardingSkipState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kOnboardingSkipped);
  await prefs.remove(kOnboardingJoinedToTutor);
}

// ── Widget ──────────────────────────────────────────────────────────────────

/// CTA banner shown when the user skipped track setup during onboarding.
///
/// Place this above the existing [EmptyDashboard] widget (or as the primary
/// content when there are no tracks and [onboardingSkipStateProvider] returns
/// `skipped: true`).
class SkippedOnboardingCtaBanner extends ConsumerWidget {
  const SkippedOnboardingCtaBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(onboardingSkipStateProvider);
    return stateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (state) {
        if (!state.skipped) return const SizedBox.shrink();
        return _CtaBannerBody(joinedToTutor: state.joinedToTutor, ref: ref);
      },
    );
  }
}

class _CtaBannerBody extends StatelessWidget {
  const _CtaBannerBody({required this.joinedToTutor, required this.ref});

  final bool joinedToTutor;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFFE4E7EF),
              child: Icon(
                Icons.waving_hand_rounded,
                size: 36,
                color: AppTheme.brandBlueDeep,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              joinedToTutor ? 'Welcome, tutor!' : "You're all set!",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.brandInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              joinedToTutor
                  ? 'Ask the parent to share an invite link with you, '
                        'then tap below to accept it.'
                  : 'Set up your first learning track when you are ready, '
                        'or accept a tutor invite if someone shared one with you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.brandInkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            if (!joinedToTutor) ...[
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Set up a learning track'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  unawaited(
                    context.router.push(
                      TrackManagementHubRoute(startAdding: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.link_rounded),
              label: const Text('Accept a tutor invite'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.brandBlueDeep,
                side: const BorderSide(color: AppTheme.brandBlue),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _handleAcceptInvite(context),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await clearOnboardingSkipState();
                ref.invalidate(onboardingSkipStateProvider);
              },
              child: const Text(
                'Dismiss',
                style: TextStyle(color: AppTheme.brandInkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAcceptInvite(BuildContext context) {
    // W6.9 deep-link handler is the canonical entry. Here we provide a
    // clipboard-paste fallback: prompt the user to paste their invite link.
    showDialog<void>(
      context: context,
      builder: (ctx) => _PasteInviteLinkDialog(),
    );
  }
}

/// Simple dialog for pasting an invite link (fallback for W6.9 deep-links).
class _PasteInviteLinkDialog extends StatefulWidget {
  @override
  State<_PasteInviteLinkDialog> createState() => _PasteInviteLinkDialogState();
}

class _PasteInviteLinkDialogState extends State<_PasteInviteLinkDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill from clipboard if available.
    unawaited(_prefillFromClipboard());
  }

  Future<void> _prefillFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim() ?? '';
      if (text.contains('invite') || text.startsWith('https://')) {
        if (mounted) _controller.text = text;
      }
    } catch (_) {
      // Clipboard unavailable — ignore.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Accept tutor invite'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Paste the invite link the parent shared with you.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // W6.9: full deep-link flow handled by the incoming URI handler.
            // For now, close the dialog — the token will be processed once
            // W6.9's AcceptInviteScreen is wired into the router.
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invite link received. Processing...'),
              ),
            );
          },
          child: const Text('Accept'),
        ),
      ],
    );
  }
}
