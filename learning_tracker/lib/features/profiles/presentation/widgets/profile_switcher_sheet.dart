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
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// AN-2: Whether the active profile is a child with a configured Parent PIN —
/// the guard condition that gates all escalating actions in the switcher sheet.
///
/// Exposed as an overridable [FutureProvider] so tests can inject a known
/// result without touching [FlutterSecureStorage].
final switcherSheetPinGuardRequiredProvider = FutureProvider<bool>((ref) async {
  final profiles =
      ref.watch(profileListStreamProvider).asData?.value ?? <ProfileModel>[];
  final activeId = ref.watch(activeProfileIdProvider);
  final active = profiles.where((p) => p.id == activeId).firstOrNull;
  if (active == null || active.profileMode != ProfileMode.child) return false;
  final pinService = ref.read(pinServiceProvider);
  return pinService.hasProfilePin(activeId);
});

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
///
/// AN-2: Escalating actions (switch to adult profile, edit, delete, switch
/// account, add profile) are gated behind a Parent PIN challenge when the
/// active profile is a child and a PIN is configured.
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
    // AN-2: read whether the active profile is a child with a PIN set.
    // Falls back to false (no guard) while loading or on error.
    final pinGuardRequired =
        ref.watch(switcherSheetPinGuardRequiredProvider).asData?.value ?? false;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Bound the sheet height, then scroll the WHOLE body inside that bound.
      // In an `isScrollControlled` sheet the parent imposes no height limit, so
      // a mainAxisSize.min Column reported its full natural height and the
      // former Flexible(SingleChildScrollView) collapsed — the profiles list
      // and the fixed Account / Add-profile / Skip-to-Settings tiles overflowed
      // on short screens / many profiles / large text. Clamping to 85% of the
      // screen and putting all content in a single SingleChildScrollView makes
      // every row (incl. the bottom tiles) reachable by scrolling, with no
      // overflow across device sizes / text scales.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                    subtitle:
                        accountEmail == null ||
                            accountEmail.endsWith('@offline.local')
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
                    // AN-2: switching account is an escalating action from child context.
                    onTap: () => _guardEscalating(
                      context,
                      ref,
                      pinGuardRequired: pinGuardRequired,
                      activeProfileId: activeProfileId,
                      subtitle: l10n.pinDialogSubtitleSwitchProfile,
                      action: () {
                        Navigator.of(context).pop();
                        unawaited(
                          context.pushRoute(const AccountPickerRoute()),
                        );
                      },
                    ),
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
                // The profiles list lays out at its natural height; the whole
                // sheet scrolls as one unit inside the bounded SingleChildScroll-
                // View above, so no inner same-axis scroll view is needed here.
                for (final profile in profiles)
                  _SwitcherProfileTile(
                    profile: profile,
                    isActive: profile.id == activeProfileId,
                    // AN-2: switching to an adult profile from a child context
                    // is an escalating action — require Parent PIN.
                    onTap: () => _guardEscalating(
                      context,
                      ref,
                      pinGuardRequired: pinGuardRequired,
                      activeProfileId: activeProfileId,
                      subtitle: l10n.pinDialogSubtitleSwitchProfile,
                      action: () => _switchProfile(context, ref, profile.id),
                    ),
                    onEdit: () => _guardEscalating(
                      context,
                      ref,
                      pinGuardRequired: pinGuardRequired,
                      activeProfileId: activeProfileId,
                      subtitle: l10n.pinDialogSubtitleEditProfile,
                      action: () =>
                          unawaited(editProfileFlow(context, ref, profile)),
                    ),
                    onDelete: () => _guardEscalating(
                      context,
                      ref,
                      pinGuardRequired: pinGuardRequired,
                      activeProfileId: activeProfileId,
                      subtitle: l10n.pinDialogSubtitleDeleteProfile,
                      action: () =>
                          unawaited(deleteProfileFlow(context, ref, profile)),
                    ),
                  ),
                // Talmid profiles — self-gating: renders only when the current
                // user has ≥1 active or pending tutor grant.
                const TutoredChildrenSection(),
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
                    // AN-2: adding a profile is an escalating action from child context.
                    onTap: () => _guardEscalating(
                      context,
                      ref,
                      pinGuardRequired: pinGuardRequired,
                      activeProfileId: activeProfileId,
                      subtitle: l10n.pinDialogSubtitleSwitchProfile,
                      action: () async {
                        // D4 root cause: popping the sheet FIRST unmounted both
                        // `context` and `ref`, so showAddProfileDialog's
                        // `context.mounted` guard bailed out before createProfile —
                        // Add Profile silently created nothing. Keep the sheet
                        // mounted while the dialog runs (it sits behind the modal
                        // dialog barrier), then close it afterwards.
                        await showAddProfileDialog(context, ref);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                // FIX#8: "Skip to Settings" — mirrors the affordance on the full
                // ProfilePickerScreen. A user with no own profile (or who simply
                // wants Settings) can reach it directly from the mid-session
                // switcher sheet. Pop the sheet first, then route to SettingsRoute
                // (a shell child the ProfileGuard lets through even with no own
                // profile), via the root navigator so it works regardless of which
                // surface opened the sheet.
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    key: const Key('switcherSheetSkipToSettings'),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.brandBlueSoft,
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: AppTheme.brandBlueDeep,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      l10n.profilePickerSkipToSettings,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.brandBlueDeep,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.inkMidGrey,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(context.pushRoute(const SettingsRoute()));
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
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

  /// AN-2: Gate escalating actions behind a Parent PIN challenge when the
  /// active profile is a child with a configured PIN.
  ///
  /// [pinGuardRequired] is derived from [switcherSheetPinGuardRequiredProvider]
  /// (overridable in tests); [subtitle] is the action-specific l10n string
  /// shown below the PIN keypad (switch / edit / delete); [action] is only
  /// executed after a successful PIN verification (or immediately when no guard
  /// is needed).
  void _guardEscalating(
    BuildContext context,
    WidgetRef ref, {
    required bool pinGuardRequired,
    required int activeProfileId,
    required String subtitle,
    required VoidCallback action,
  }) {
    if (!pinGuardRequired) {
      action();
      return;
    }
    // Show Parent PIN verification; only proceed on success.
    unawaited(
      showParentPinVerificationDialog(
        context,
        profileId: activeProfileId,
        pinService: ref.read(pinServiceProvider),
        subtitle: subtitle,
      ).then((verified) {
        if (verified && context.mounted) action();
      }),
    );
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
