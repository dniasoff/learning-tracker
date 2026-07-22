import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
// AUD-settings-09: route cross-feature references through the account/
// profiles barrels (Rule 2) instead of 6 deep imports into their domain
// models and presentation providers.
import 'package:learning_tracker/features/account/account.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/account_actions_sheet.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Surface for [UserProfileHeaderCard]: matches [SettingsScreen] card vs
/// [ParentSettingsScreen] `_WhitePanel`.
enum UserProfileHeaderSurface {
  /// White card with light border and shadow (settings list).
  settings,

  /// White card with soft shadow, no border (parent mode list).
  parent,
}

/// The role context shown in the identity card badge.
///
/// [selfLearner] = own profile (shows SELF-LEARNER badge + account email).
/// [parent]      = elevated parent viewing a child profile (shows PARENT badge,
///                 hides account email).
/// [tutor]       = tutor viewing a talmid's context (shows TUTOR badge, hides
///                 account email).
enum UserProfileContextRole { selfLearner, parent, tutor }

/// Profile header (avatar, name, email, badges) used on Settings and on
/// [ParentSettingsScreen] for the active child.
class UserProfileHeaderCard extends ConsumerWidget {
  const UserProfileHeaderCard({
    super.key,
    required this.user,
    this.activeProfile,
    this.surface = UserProfileHeaderSurface.settings,
    this.contextRole = UserProfileContextRole.selfLearner,
  });

  final AppUser? user;
  final ProfileModel? activeProfile;
  final UserProfileHeaderSurface surface;
  final UserProfileContextRole contextRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // `this.` disambiguates from the local `user` declared below (Dart
    // forbids a local initializer referencing its own not-yet-declared
    // name), and capturing into a local lets flow analysis promote the
    // null check for the rest of this method (AUD-settings-10: this widget
    // used to be a ConsumerStatefulWidget solely to re-derive this from
    // `widget.user` in initState/didUpdateWidget).
    final user = this.user;

    if (user == null) {
      final authState = ref.watch(authStateProvider);
      // Show the "not signed in" placeholder only when there is no active
      // session. For signed-in users the placeholder text is misleading.
      if (!authState.isSignedIn) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 48),
              const SizedBox(width: 16),
              Text(l10n.notSignedIn),
            ],
          ),
        );
      }
      // A signed-in cloud-born user with user==null is a transient loading
      // state (Firebase user not yet resolved). Return an empty widget to
      // avoid showing a misleading "Not signed in" label.
      if (!authState.isLocalBorn) {
        return const SizedBox.shrink();
      }
      return _wrapSurface(
        surface,
        _LocalBornProfileRow(
          surface: surface,
          theme: theme,
          authUser: authState.currentUser!,
        ),
        onTap: surface == UserProfileHeaderSurface.settings
            ? () => showAccountActionsSheet(context, ref)
            : null,
      );
    }

    final authState = ref.watch(authStateProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);
    // `this.` disambiguates the field from the local `activeProfile` below
    // (same self-reference rule as `user` above).
    final activeProfile =
        this.activeProfile ?? _watchActiveProfileFromList(ref, activeProfileId);

    final displayName =
        activeProfile?.displayName ??
        user.displayName ??
        user.email?.split('@').first ??
        l10n.userFallbackDisplayName;
    final profileInitial = _profileInitial(displayName);

    // Role-context badge: label + colour vary by who is viewing.
    final (badgeLabel, badgeColor, badgeTextColor) = switch (contextRole) {
      UserProfileContextRole.parent => (
        l10n.parentContextBadge,
        context.colors.settingsProfileBadgeParentBg,
        context.colors.settingsProfileBadgeParentText,
      ),
      UserProfileContextRole.tutor => (
        l10n.tutorContextBadge,
        context.colors.settingsProfileBadgeTutorBg,
        context.colors.accentBurntOrange,
      ),
      UserProfileContextRole.selfLearner => (
        l10n.selfLearnerBadge,
        theme.colorScheme.primary.withValues(alpha: 0.12),
        theme.colorScheme.primary,
      ),
    };
    // Hide the account email in parent/tutor context — it belongs to the
    // tutor/parent's own account, not the child being viewed. Also suppress
    // the synthetic internal address that credential-less offline accounts
    // carry (…@offline.local must never be shown to users).
    final showEmail =
        contextRole == UserProfileContextRole.selfLearner &&
        user.email != null &&
        !user.email!.endsWith('@offline.local');

    return _wrapSurface(
      surface,
      onTap: () => showAccountActionsSheet(context, ref),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.settingsProfileAvatarRing,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Text(
                  profileInitial,
                  maxLines: 1,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showEmail)
                    Text(
                      user.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.inkMidGrey,
                        fontSize: 16,
                      ),
                    ),
                  if (authState.isLocalBorn) ...[
                    const SizedBox(height: 4),
                    const _NoBackupInlineText(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _wrapSurface(
  UserProfileHeaderSurface style,
  Widget child, {
  VoidCallback? onTap,
}) {
  switch (style) {
    case UserProfileHeaderSurface.settings:
      return _SettingsProfileSurface(onTap: onTap, child: child);
    case UserProfileHeaderSurface.parent:
      return _ParentProfileSurface(onTap: onTap, child: child);
  }
}

class _SettingsProfileSurface extends StatelessWidget {
  const _SettingsProfileSurface({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // R*: tapping the profile NAME/header opens the canonical profile
    // switcher/manager sheet (switch / add / edit / delete). This restores the
    // tap-to-switch affordance that WS1.consolidate had removed.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.surfaceE9),
        boxShadow: [
          BoxShadow(
            color: context.colors.settingsProfileCardShadow,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: onTap == null
          ? child
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: child,
              ),
            ),
    );
  }
}

class _ParentProfileSurface extends StatelessWidget {
  const _ParentProfileSurface({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.settingsProfileParentCardShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: onTap == null
            ? child
            : Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, child: child),
              ),
      ),
    );
  }
}

class _LocalBornProfileRow extends ConsumerWidget {
  const _LocalBornProfileRow({
    required this.surface,
    required this.theme,
    required this.authUser,
  });

  final UserProfileHeaderSurface surface;
  final ThemeData theme;
  final AuthUser authUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final activeProfile = _watchActiveProfileFromList(ref, activeProfileId);

    final displayName =
        activeProfile?.displayName ??
        (authUser.displayName.isNotEmpty
            ? authUser.displayName
            : authUser.email.split('@').first);
    final profileInitial = _profileInitial(displayName);

    final inner = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: surface == UserProfileHeaderSurface.parent ? 14 : 16,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  profileInitial,
                  maxLines: 1,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                  ),
                ),
                // Credential-less offline accounts carry a synthetic internal
                // email (…@offline.local) that must never be shown; suppress it
                // (the _NoBackupInlineText row below already signals offline).
                if (!authUser.email.endsWith('@offline.local'))
                  Text(
                    authUser.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                const SizedBox(height: 4),
                const _NoBackupInlineText(),
              ],
            ),
          ),
        ],
      ),
    );

    return inner;
  }
}

class _NoBackupInlineText extends StatelessWidget {
  const _NoBackupInlineText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off,
          size: 12,
          color: context.colors.settingsProfileNoBackupAccent,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.noBackup,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.colors.settingsProfileNoBackupAccent,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Resolves the [ProfileModel] matching [activeProfileId] out of the live
/// profile-list stream.
///
/// AUD-settings-10: this lookup used to be copy-pasted between
/// [UserProfileHeaderCard]'s and [_LocalBornProfileRow]'s `build` methods.
/// Shared here and read via [ProviderListenable.select] (PF-1) so callers
/// rebuild only when the *resolved profile* changes, not on every unrelated
/// mutation to the full profile list.
ProfileModel? _watchActiveProfileFromList(WidgetRef ref, int activeProfileId) {
  return ref.watch(
    profileListStreamProvider.select(
      (asyncValue) => asyncValue.asData?.value
          .where((p) => p.id == activeProfileId)
          .firstOrNull,
    ),
  );
}

String _profileInitial(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty) return 'U';
  return normalized.substring(0, 1).toUpperCase();
}
