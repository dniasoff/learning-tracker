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
  final LearnerProfileEntity? activeProfile;
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
    final authState = ref.watch(authStateProvider);

    if (user == null) {
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
      // Local-born accounts have no Firebase AppUser, but AuthState still
      // carries their account identity. Keep the account header visible for
      // that supported signed-in state; cloud-born sessions with a transiently
      // unavailable Firebase user remain empty until it resolves.
      if (!authState.isLocalBorn || authState.currentUser == null) {
        return const SizedBox.shrink();
      }
    }

    final activeProfileId = ref.watch(activeProfileIdProvider);
    // `this.` disambiguates the field from the local `activeProfile` below
    // (same self-reference rule as `user` above).
    final activeProfile =
        this.activeProfile ?? _watchActiveProfileFromList(ref, activeProfileId);
    final localAuthUser = user == null ? authState.currentUser : null;

    final displayName =
        activeProfile?.displayName ??
        user?.displayName ??
        localAuthUser?.displayName ??
        user?.email?.split('@').first ??
        localAuthUser?.email.split('@').first ??
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
        (user?.email ?? localAuthUser?.email) != null &&
        !(user?.email ?? localAuthUser?.email)!.endsWith('@offline.local');

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
                // AUD dark-mode sweep: was a hardcoded Colors.white — a
                // "cutout" ring meant to blend with the surrounding card
                // (brandCreamCard), which is white in light but darkens in
                // dark mode. A fixed white ring instead created a bright
                // halo around the avatar in dark mode. brandCreamCard keeps
                // the ring pixel-identical to the old literal in light and
                // blends with the (now-dark) card in dark mode.
                border: Border.all(
                  color: context.colors.brandCreamCard,
                  width: 2,
                ),
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
                      (user?.email ?? localAuthUser!.email),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.inkMidGrey,
                        fontSize: 16,
                      ),
                    ),
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
        color: context.colors.brandCreamCard,
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
        color: context.colors.brandCreamCard,
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

/// Resolves the [LearnerProfileEntity] matching [activeProfileId] out of the
/// live profile-list stream.
///
/// AUD-settings-10: this lookup used to be copy-pasted between
/// [UserProfileHeaderCard]'s and a since-removed local-born profile row's
/// `build` methods. Shared here and read via [ProviderListenable.select]
/// (PF-1) so callers rebuild only when the *resolved profile* changes, not
/// on every unrelated mutation to the full profile list.
LearnerProfileEntity? _watchActiveProfileFromList(
  WidgetRef ref,
  String? activeProfileId,
) {
  return ref.watch(
    profileListStreamProvider.select(
      (asyncValue) => asyncValue.asData?.value
          .where((p) => p.profileId == activeProfileId)
          .firstOrNull,
    ),
  );
}

String _profileInitial(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty) return 'U';
  return normalized.substring(0, 1).toUpperCase();
}
