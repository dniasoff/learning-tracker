import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
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
class UserProfileHeaderCard extends ConsumerStatefulWidget {
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
  ConsumerState<UserProfileHeaderCard> createState() =>
      _UserProfileHeaderCardState();
}

class _UserProfileHeaderCardState extends ConsumerState<UserProfileHeaderCard> {
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  void didUpdateWidget(covariant UserProfileHeaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _user = widget.user;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final user = _user;

    if (user == null) {
      final authState = ref.watch(authStateProvider);
      if (!authState.isSignedIn || !authState.isLocalBorn) {
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
      return _wrapSurface(
        widget.surface,
        _LocalBornProfileRow(
          surface: widget.surface,
          theme: theme,
          authUser: authState.currentUser!,
        ),
        onTap: widget.surface == UserProfileHeaderSurface.settings
            ? () => showAccountActionsSheet(context, ref)
            : null,
      );
    }

    final authState = ref.watch(authStateProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile =
        widget.activeProfile ??
        profilesAsync.asData?.value
            .where((p) => p.id == activeProfileId)
            .firstOrNull;

    final displayName =
        activeProfile?.displayName ??
        user.displayName ??
        user.email?.split('@').first ??
        l10n.userFallbackDisplayName;
    final profileInitial = _profileInitial(displayName);

    // Role-context badge: label + colour vary by who is viewing.
    final (
      badgeLabel,
      badgeColor,
      badgeTextColor,
    ) = switch (widget.contextRole) {
      UserProfileContextRole.parent => (
        l10n.parentContextBadge,
        const Color(0xFFE8F4FD),
        const Color(0xFF1565C0),
      ),
      UserProfileContextRole.tutor => (
        l10n.tutorContextBadge,
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
      ),
      UserProfileContextRole.selfLearner => (
        l10n.selfLearnerBadge,
        theme.colorScheme.primary.withValues(alpha: 0.12),
        theme.colorScheme.primary,
      ),
    };
    // Hide the account email in parent/tutor context — it belongs to the
    // tutor/parent's own account, not the child being viewed.
    final showEmail =
        widget.contextRole == UserProfileContextRole.selfLearner &&
        user.email != null;

    return _wrapSurface(
      widget.surface,
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
                color: const Color(0xFFCFD8EA),
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
                        color: AppColors.inkMidGrey,
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
        border: Border.all(color: AppColors.surfaceE9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121D2939),
            blurRadius: 16,
            offset: Offset(0, 5),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x140038A8),
            blurRadius: 16,
            offset: Offset(0, 6),
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
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;

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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                  ),
                ),
                Text(
                  authUser.email,
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
        const Icon(Icons.cloud_off, size: 12, color: Color(0xFFCE8A41)),
        const SizedBox(width: 4),
        Text(
          AppLocalizations.of(context)!.noBackup,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFFCE8A41),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

String _profileInitial(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty) return 'U';
  return normalized.substring(0, 1).toUpperCase();
}
