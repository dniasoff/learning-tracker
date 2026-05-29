import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Opens the canonical profile switcher/manager bottom sheet.
///
/// This is the single home for switch / add / edit / delete of profiles on the
/// current account. Triggered by tapping the profile NAME/header (Settings) —
/// see [UserProfileHeaderCard].
Future<void> showProfileSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const ProfileSwitcherSheet(),
  );
}

/// Profile switcher/manager bottom sheet.
///
/// Lists every profile on the current account with a child/adult label, marks
/// the active one, and lets the user switch (tap a row), edit (pencil), or
/// delete (trash) any profile, plus add a new profile. Switching INTO a child
/// profile is how a parent enters parent-mode for that child.
class ProfileSwitcherSheet extends ConsumerWidget {
  const ProfileSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final profilesAsync = ref.watch(profileListStreamProvider);
    final profiles = profilesAsync.asData?.value ?? <ProfileModel>[];
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final accountEmail = ref.watch(authStateProvider).currentUser?.email;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── ACCOUNT (login) switching ─────────────────────────────────
              // The login account is distinct from the learner profile: this
              // row switches WHICH login is active (e.g. between two Google
              // accounts on the device); the Profiles list below switches the
              // active learner within the current account.
              Text(
                l10n.sectionAccount,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.brandBlueSoft,
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: AppTheme.brandBlueDeep,
                    ),
                  ),
                  title: Text(
                    l10n.switchAccount,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: accountEmail == null
                      ? null
                      : Text(
                          accountEmail,
                          style: const TextStyle(
                            color: AppTheme.brandInkMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkMidGrey,
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(context.pushRoute(const AccountPickerRoute()));
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const Divider(height: 24),
              Text(
                l10n.switcherSheetProfiles,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final profile in profiles)
                        _SwitcherProfileTile(
                          profile: profile,
                          isActive: profile.id == activeProfileId,
                          onTap: () => _switchProfile(context, ref, profile.id),
                          onEdit: () =>
                              unawaited(editProfileFlow(context, ref, profile)),
                          onDelete: () => unawaited(
                            deleteProfileFlow(context, ref, profile),
                          ),
                        ),
                      // Talmid profiles — self-gating: renders only when the
                      // current user has ≥1 active or pending tutor grant.
                      const TutoredChildrenSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.brandOutline,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppTheme.brandBlueDeep,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.addProfile,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.brandBlueDeep,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(showAddProfileDialog(context, ref));
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Switches the active profile using the canonical mechanism: close the
  /// sheet, select the profile id, then reload the shell. Selecting a child
  /// drops straight into that child's LEARNING view — parent mode is a
  /// separate PIN-gated elevation, so we clear any existing elevation here to
  /// guarantee the freshly-selected profile starts unelevated (no banner).
  void _switchProfile(BuildContext context, WidgetRef ref, int profileId) {
    Navigator.of(context).pop();
    // R4-H1: exit any active tutored session before replacing the route.
    // No UID change occurs on profile switch, so AppShell's auth-uid listener
    // does not fire — we must call exit() explicitly here to detach listeners.
    ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    // Drop any parent-mode elevation so the freshly-selected profile starts
    // in plain learning view (no banner). The PIN guard's per-(scope,profile)
    // cache re-prompts on the new profile automatically since the scope id
    // changes; we only need to clear the reactive flag the banner watches.
    ref.read(parentPinAuthenticatedProfileIdProvider.notifier).clear();
    ref.read(selectedProfileIdProvider.notifier).select(profileId);
    unawaited(context.router.replaceAll([const AppShellRoute()]));
  }
}

class _SwitcherProfileTile extends StatelessWidget {
  const _SwitcherProfileTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ProfileModel profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : '?';
    final typeLabel = profile.profileMode == ProfileMode.child
        ? l10n.profileTypeChild
        : l10n.profileTypeAdult;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? AppTheme.brandBlueBright.withValues(alpha: 0.15)
              : AppTheme.brandBlueSoft,
          child: Text(
            initial,
            style: TextStyle(
              color: isActive
                  ? AppTheme.brandBlueBright
                  : AppTheme.brandBlueDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          profile.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          typeLabel,
          style: const TextStyle(color: AppTheme.brandInkMuted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 4),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.brandBlueBright,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppTheme.brandInkMuted,
              tooltip: l10n.profilesEditLabel,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppTheme.brandCoralDeep,
              tooltip: l10n.profilesDeleteLabel,
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: isActive ? null : onTap,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
