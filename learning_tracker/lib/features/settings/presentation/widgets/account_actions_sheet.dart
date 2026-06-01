import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The single home for ACCOUNT (login) management — switch / add account, change
/// password, sign out, delete account.
///
/// Opened by tapping the profile header card in Settings. Learner-PROFILE
/// management (add / edit / remove learners) deliberately lives ONLY in the
/// PROFILE section of Settings, never here — the top header is account-only.
///
/// [pageRef] / [pageContext] are the long-lived caller's ref + context so the
/// action flows (which run after this sheet is popped) operate on a context that
/// outlives the modal sheet.
Future<void> showAccountActionsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AccountActionsSheet(pageContext: context, pageRef: ref),
  );
}

class _AccountActionsSheet extends ConsumerWidget {
  const _AccountActionsSheet({
    required this.pageContext,
    required this.pageRef,
  });

  /// Caller's context — outlives the sheet, used for post-pop action flows.
  final BuildContext pageContext;

  /// Caller's ref — outlives the sheet, used for post-pop action flows.
  final WidgetRef pageRef;

  @override
  Widget build(BuildContext sheetContext, WidgetRef ref) {
    final theme = Theme.of(sheetContext);
    final l10n = AppLocalizations.of(sheetContext)!;

    final user = ref.watch(authRepositoryProvider).currentUser;
    final authState = ref.watch(authStateProvider);
    final accountEmail = user?.email ?? '';

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;
    final isChildProfile = activeProfile?.profileMode == ProfileMode.child;

    final parentAuthedProfileId = ref.watch(
      parentPinAuthenticatedProfileIdProvider,
    );
    final inParentMode =
        parentAuthedProfileId != null &&
        parentAuthedProfileId == activeProfileId;

    final hasPasswordProvider =
        user != null && user.providers.contains('password');
    // Delete is for non-child authenticated users (cloud or local-born). A
    // tutor-only adult has no own profile row, so isChildProfile is false here.
    final showDelete =
        !isChildProfile && (user != null || authState.isLocalBorn);
    final showSignOut = !isChildProfile;
    final showAddAccount = !isChildProfile || inParentMode;

    void closeThen(Future<void> Function() action) {
      Navigator.of(sheetContext).pop();
      // Run the flow on the caller's context/ref after the sheet has popped.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageContext.mounted) unawaited(action());
      });
    }

    // Use Material (not a bare DecoratedBox) so the ListTiles below have a
    // Material ancestor with no intervening coloured box — otherwise their ink
    // splashes are hidden and Flutter asserts "ink splashes may be invisible".
    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Text(
                  l10n.sectionAccount,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              // Switch account — pick or add another login on this device.
              ListTile(
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
                subtitle: accountEmail.isEmpty
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
                onTap: () => closeThen(() async {
                  // Use the ROOT router (not pageContext.pushRoute). AccountPicker
                  // is a root-level route; pageContext lives inside the Settings
                  // tab whose nested StackRouter cannot navigate to root routes —
                  // pushing via the tab router silently no-ops.
                  await pageRef
                      .read(routerProvider)
                      .push(const AccountPickerRoute());
                }),
              ),
              if (showAddAccount)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.brandBlueSoft,
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppTheme.brandBlueBright,
                    ),
                  ),
                  title: Text(
                    l10n.switcherSheetAddAccount,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.addAnotherAccountSubtitle,
                    style: const TextStyle(
                      color: AppTheme.brandInkMuted,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => closeThen(() async {
                    // Root router — Signup is a root-level route (see Switch
                    // account note above); the tab's nested router can't push it.
                    await pageRef.read(routerProvider).push(SignupRoute());
                  }),
                ),
              if (hasPasswordProvider)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: const Icon(
                      Icons.vpn_key_outlined,
                      color: AppTheme.brandInkMuted,
                    ),
                  ),
                  title: Text(
                    l10n.changePassword,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => closeThen(
                    () => _changePasswordFlow(pageContext, pageRef),
                  ),
                ),
              if (showSignOut || showDelete) const Divider(height: 16),
              if (showSignOut)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.errorContainer,
                    child: Icon(
                      Icons.logout_rounded,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  title: Text(
                    l10n.signOut,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  onTap: () => closeThen(
                    () => showSignOutConfirmation(pageContext, pageRef),
                  ),
                ),
              if (showDelete)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.errorContainer,
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  title: Text(
                    l10n.deleteAccountTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  subtitle: Text(
                    authState.isLocalBorn
                        ? l10n.deleteLocalAccountSubtitle
                        : l10n.deleteAccountSubtitle,
                    style: const TextStyle(
                      color: AppTheme.brandInkMuted,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => closeThen(() async {
                    if (authState.isLocalBorn) {
                      await showDeleteLocalAccountFlow(pageContext, pageRef);
                    } else if (user != null) {
                      await showDeleteAccountFlow(pageContext, pageRef, user);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePasswordFlow(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final service = ref.read(accountManagementServiceProvider);

    final reauthenticated = await showReauthenticateDialog(
      context: context,
      email: user.email ?? '',
      service: service,
    );
    if (reauthenticated != true || !context.mounted) return;

    final changed = await showChangePasswordDialog(
      context: context,
      service: service,
    );
    if ((changed ?? false) && context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordChangedSuccessfully)));
    }
  }
}
