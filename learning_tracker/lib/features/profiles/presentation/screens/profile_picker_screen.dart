import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/widgets/no_backup_badge.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/my_children_section.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
// Only pendingTutorInvitesProvider is needed here; incomingTutorGrantsProvider
// is intentionally taken from manage_tutors_providers (a same-named provider
// also exists in tutor_grant_providers) to avoid an ambiguous import.
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';

export 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart'
    show AddProfileModePickCard;

@RoutePage()
class ProfilePickerScreen extends ConsumerStatefulWidget {
  const ProfilePickerScreen({super.key});

  @override
  ConsumerState<ProfilePickerScreen> createState() =>
      _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends ConsumerState<ProfilePickerScreen> {
  bool _isSelectingProfile = false;

  @override
  Widget build(BuildContext context) {
    // Use future provider instead of stream provider to avoid the
    // InheritedElement '_dependents.isEmpty' assertion that fires when
    // a stream-triggered rebuild races with dialog/overlay dismissal.
    final profilesAsync = ref.watch(profileListProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: profilesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => AppErrorView(
              error: e,
              stackTrace: s,
              onRetry: () => ref.refresh(profileListProvider),
            ),
            data: (profiles) => _buildBody(context, profiles),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ProfileModel> profiles) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Section headers ("YOUR PROFILES" / "TALMID PROFILES") only appear when
    // the current user is a rebbe with at least one active tutored grant.
    // Otherwise the picker shows a single flat list with no headers — the
    // user's own child + adult profiles are co-mingled inside the grid.
    final grantsAsync = ref.watch(incomingTutorGrantsProvider);
    final tutoredCount =
        grantsAsync.asData?.value.where((g) => g.grantState.isActive).length ??
        0;
    final isSegmented = tutoredCount > 0;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // DNI-342 / UX-DR20: persistent "no backup" badge for local-born
            // accounts (hidden for cloudBorn / signed-out via the widget's
            // internal tier gate).
            const Align(alignment: Alignment.center, child: NoBackupBadge()),
            const SizedBox(height: 6),
            Text(
              l10n.profilePickerTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppTheme.brandBlueDeep,
                letterSpacing: -0.8,
                height: 1.03,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.profilePickerSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.brandInkMuted,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            // Pending tutor invitations addressed to this account's email.
            // Surfacing them here means a freshly signed-in tutor accepts in
            // app (no emailed deep link) and is not dead-ended into creating a
            // learner profile they don't want.
            _buildPendingInvites(context),
            // Own profiles — adults + children co-mingled.
            OwnProfilesSection(
              profiles: profiles,
              showHeader: isSegmented,
              isSelectingProfile: _isSelectingProfile,
              onProfileTap: (id) => unawaited(_selectProfile(id)),
              onProfileLongPress: (profile, count) =>
                  unawaited(_showManageSheet(profile, count)),
              onAddProfile: (_) => unawaited(_showAddDialog(profiles.length)),
            ),
            // Talmidim — only renders when the user has ≥1 active tutor grant.
            const TutoredChildrenSection(),
            // Skip to Settings — always available so an adult who only wants to
            // manage tutoring / account / device settings is never forced to
            // create a learner profile to reach Settings. Especially needed for
            // tutor-only accounts with no own profile/track.
            _buildSkipToSettings(context),
            // Account exit — shown when the user has no own learner profiles
            // (tutor-only account) so they can sign out without needing to
            // create a profile or enter a talmid's context first.
            if (profiles.isEmpty) _buildSignOutSection(context),
          ],
        ),
      ),
    );
  }

  // ── Pending tutor invitations ────────────────────────────────────────────

  Widget _buildPendingInvites(BuildContext context) {
    final pendingAsync = ref.watch(pendingTutorInvitesProvider);
    final pending = pendingAsync.asData?.value ?? const <TutorGrant>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final grant in pending) ...[
          _PendingInviteCard(
            grant: grant,
            onAccept: () => unawaited(_acceptPendingInvite(grant)),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Future<void> _acceptPendingInvite(TutorGrant grant) async {
    // Reuse the existing accept flow (handles confirmation + Tutor PIN setup).
    await context.router.push(AcceptInviteRoute(token: grant.grantId));
    if (!mounted) return;
    // Refresh so the accepted child surfaces and the invite drops off.
    ref.invalidate(pendingTutorInvitesProvider);
    ref.invalidate(incomingTutorGrantsProvider);
  }

  // ── Select Profile ─────────────────────────────────────────────────────────

  Future<void> _selectProfile(int profileId) async {
    if (_isSelectingProfile) return;
    _isSelectingProfile = true;

    try {
      ref.read(selectedProfileIdProvider.notifier).select(profileId);

      if (!mounted) return;
      await context.router.replaceAll([const AppShellRoute()]);
    } finally {
      // If navigation didn't happen (or failed), allow another tap attempt.
      if (mounted) {
        setState(() {
          _isSelectingProfile = false;
        });
      }
    }
  }

  // ── Add Profile ───────────────────────────────────────────────────────────

  Future<void> _showAddDialog(int profileCount) async {
    if (!mounted) return;
    await showAddProfileDialog(context, ref);
  }

  // ── Manage (Long-press) ───────────────────────────────────────────────────

  Future<void> _showManageSheet(ProfileModel profile, int profileCount) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.renameAction),
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  l10n.delete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                // AUD-profiles-04: Delete is always reachable here, matching
                // manage_learners_screen.dart's PopupMenuItem (no enable
                // gate). deleteProfileFlow shows its own localized
                // last-profile confirmation (deleteProfileLastTitle/Body/
                // Confirm) instead of this screen hard-blocking the tile —
                // the canonical flow already supports allowLast deletes.
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    // AUD-profiles-04: delegate to the canonical editProfileFlow/
    // deleteProfileFlow (profile_edit_delete_actions.dart) instead of private
    // duplicates — matching manage_learners_screen.dart. This eliminates the
    // hardcoded-English last-profile delete copy (a Hebrew-locale user with
    // exactly one profile previously saw raw English) and the missing
    // `mounted` guard after the delete's `await`.
    if (action == 'rename') {
      await editProfileFlow(context, ref, profile);
    } else if (action == 'delete' && mounted) {
      await deleteProfileFlow(context, ref, profile);
    }
  }

  // ── Skip to Settings ──────────────────────────────────────────────────────

  /// A "Skip to Settings" affordance so the user can always reach the app
  /// Settings without first selecting (or creating) a learner profile. Routes
  /// to [SettingsRoute] (a child of the app shell, which the ProfileGuard lets
  /// through even when no own profile exists).
  Widget _buildSkipToSettings(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: TextButton.icon(
        icon: const Icon(Icons.settings_rounded, size: 20),
        label: Text(l10n.profilePickerSkipToSettings),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.brandBlueDeep,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => unawaited(context.router.push(const SettingsRoute())),
      ),
    );
  }

  // ── Account exit for tutor-only users ────────────────────────────────────

  Widget _buildSignOutSection(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    // No sign-out tile for unauthenticated / anonymous sessions.
    if (!authState.isCloudBorn && !authState.isLocalBorn) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
          label: Text(
            AppLocalizations.of(context)!.signOut,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => showSignOutConfirmation(context, ref),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Card shown on the profile picker when a pending tutor invitation is
/// addressed to this account. Tapping Accept hands off to the existing
/// accept-invite flow (which also handles Tutor PIN setup).
class _PendingInviteCard extends StatelessWidget {
  const _PendingInviteCard({required this.grant, required this.onAccept});

  final TutorGrant grant;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Surface parent name (or fallback) and child name (or fallback) so a
    // user with multiple pending invites can tell them apart.
    final parentLabel = grant.parentName ?? l10n.tutorFallbackParent;
    final childLabel = grant.childDisplayLabel;
    final bodyText = l10n.acceptInviteBodyFromParentForChild(
      parentLabel,
      childLabel,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.brandBlueBright.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.brandBlueSoft,
                child: Icon(Icons.school_rounded, color: AppTheme.brandBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.acceptInviteHeading,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brandBlueDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bodyText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.brandInkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandBlue,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(l10n.acceptInviteAccept),
          ),
        ],
      ),
    );
  }
}
