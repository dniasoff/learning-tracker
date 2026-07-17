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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/scrollable_fill_body.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show profileListProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    // Overflow-safe fill: centres on normal screens, scrolls on short ones.
    return ScrollableFillBody(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.surfaceE9,
                child: Icon(
                  Icons.waving_hand_rounded,
                  size: 36,
                  color: AppTheme.brandBlueDeep,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                joinedToTutor
                    ? l10n.tutorWelcomeBannerTitle
                    : l10n.ctaGetStartedTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                joinedToTutor
                    ? l10n.tutorWelcomeBannerBody
                    : l10n.ctaGetStartedBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.brandInkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.ctaAddLearningTrack),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: () async {
                  // D6: a track cannot be saved on a profile-less account — the
                  // active profileId resolves to the sentinel 0, which has no
                  // learner_profiles row, so the track/stage insert FK-fails and
                  // the user only sees "Failed to save track". Guide them to
                  // create a profile FIRST instead of into a guaranteed failure.
                  final profiles = await ref.read(profileListProvider.future);
                  if (!context.mounted) return;
                  if (profiles.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.ctaCreateProfileFirst)),
                    );
                    unawaited(context.router.push(const ManageLearnersRoute()));
                    return;
                  }
                  unawaited(
                    context.router.push(
                      TrackManagementHubRoute(startAdding: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await clearOnboardingSkipState();
                  if (!context.mounted) return;
                  ref.invalidate(onboardingSkipStateProvider);
                },
                child: Text(
                  l10n.commonDismiss,
                  style: const TextStyle(color: AppTheme.brandInkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
