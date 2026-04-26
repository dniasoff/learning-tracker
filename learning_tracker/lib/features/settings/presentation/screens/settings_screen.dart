import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/services/pin_service.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/language_provider.dart';
import 'package:learning_tracker/features/settings/presentation/screens/lifetime_marking_screen.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';

// TODO(DNI-105): Replace with dynamic version from package_info_plus
// once the dependency is added to pubspec.yaml.
const String _appVersion = '1.2.4';

@RoutePage()
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final theme = Theme.of(context);

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;
    final isChildProfile = activeProfile?.mode == 'child';
    final isAdultProfile = activeProfile?.mode == 'adult';
    final hasPasswordProvider = user != null &&
        user.providerData.any((info) => info.providerId == 'password');

    return Scaffold(
      body: SafeArea(
        top: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pushRoute(const ProfilePickerRoute()),
              child: _UserProfileSection(
                user: user,
                activeProfile: activeProfile,
              ),
            ),
            const SizedBox(height: 24),
            if (!isChildProfile) ...[
              const _SectionHeader(title: 'TRACKS'),
              const SizedBox(height: 10),
              _SurfaceCard(
                child: _SettingsTile(
                  icon: Icons.route_rounded,
                  iconColor: AppTheme.brandBlueBright,
                  iconBackground: AppTheme.brandBlueSoft,
                  title: 'Manage tracks',
                  subtitle: 'Create and edit your learning tracks',
                  onTap: () => context.pushRoute(TrackManagementHubRoute()),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const _SectionHeader(title: 'LEARNING'),
            const SizedBox(height: 10),
            _SurfaceCard(
              child: Column(
                children: [
                  _HebrewDateTile(theme: theme),
                  if (!isChildProfile) ...[
                    _tileDivider(theme),
                    _SettingsTile(
                      icon: Icons.menu_book_rounded,
                      iconColor: AppTheme.brandGoldDeep,
                      iconBackground: AppTheme.brandGoldSoft,
                      title: 'Add what you\'ve learned',
                      subtitle: 'Log custom Mitzvot or Torah studies',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LifetimeMarkingScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SurfaceCard(
              child: _SettingsTile(
                icon: Icons.notifications_active_outlined,
                iconColor: AppTheme.brandCoralDeep,
                iconBackground: theme.colorScheme.errorContainer,
                title: 'Notification Settings',
                subtitle: 'Push, email, and study sound alerts',
                onTap: () => context.pushRoute(const NotificationsRoute()),
              ),
            ),
            const SizedBox(height: 12),
            const _SurfaceCard(child: _LanguageTile()),
            if (!isChildProfile) ...[
              const SizedBox(height: 16),
              const BackupSyncSection(),
            ],
            const SizedBox(height: 24),
            _ParentalControlsSection(
              user: user,
              isChildProfile: isChildProfile,
            ),
            if (!isChildProfile || hasPasswordProvider) ...[
              const _SectionHeader(title: 'ACCOUNT'),
              const SizedBox(height: 10),
              if (hasPasswordProvider)
                Column(
                  children: [
                    _SurfaceCard(
                      child: _SettingsTile(
                        icon: Icons.vpn_key_outlined,
                        iconColor: AppTheme.brandInkMuted,
                        iconBackground: theme.colorScheme.secondaryContainer,
                        title: 'Change Password',
                        onTap: () =>
                            _showChangePasswordFlow(context, ref, user),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              if (!isChildProfile)
                _SurfaceCard(
                  child: _SettingsTile(
                    icon: Icons.logout_rounded,
                    iconColor: theme.colorScheme.error,
                    iconBackground: theme.colorScheme.errorContainer,
                    title: 'Sign Out',
                    titleColor: theme.colorScheme.error,
                    trailing: const SizedBox.shrink(),
                    onTap: () => showSignOutConfirmation(context, ref),
                  ),
                ),
              if (!isChildProfile && isAdultProfile && user != null) ...[
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: _SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    iconColor: theme.colorScheme.error,
                    iconBackground: theme.colorScheme.errorContainer,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove this account and cloud data',
                    titleColor: theme.colorScheme.error,
                    trailing: const SizedBox.shrink(),
                    onTap: () => showDeleteAccountFlow(context, ref, user),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                'v$_appVersion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                'Handcrafted for your Torah journey',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.change_history_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.forum_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Calendar preference: tab-style [SegmentedButton] (Gregorian vs Hebrew).
class _HebrewDateTile extends ConsumerWidget {
  const _HebrewDateTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useHebrew = ref.watch(useHebrewDateProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.brandBlueSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar Preference',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 19,
                        color: const Color(0xFF1D2432),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Goals, deadlines, and date pickers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF929BAA),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Gregorian'),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Hebrew'),
              ),
            ],
            selected: {useHebrew},
            onSelectionChanged: (selected) {
              if (selected.isEmpty) return;
              ref
                  .read(useHebrewDateProvider.notifier)
                  .setUseHebrewDate(selected.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppTheme.brandBlueBright,
              selectedForegroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD7DEEA)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: const Color(0xFF8E97A6),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9ECF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121D2939),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      minLeadingWidth: 0,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 16.5),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 19,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF929BAA),
                fontSize: 15,
              ),
            ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
      onTap: onTap,
    );
  }
}

Widget _tileDivider(ThemeData theme) =>
    Divider(height: 1, indent: 62, endIndent: 14, color: theme.dividerColor);

/// Displays user profile info with avatar, name, email, and badge.
class _UserProfileSection extends ConsumerStatefulWidget {
  const _UserProfileSection({required this.user, required this.activeProfile});

  final User? user;
  final ProfileModel? activeProfile;

  @override
  ConsumerState<_UserProfileSection> createState() =>
      _UserProfileSectionState();
}

class _UserProfileSectionState extends ConsumerState<_UserProfileSection> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  void didUpdateWidget(covariant _UserProfileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _user = widget.user;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final user = _user;

    // Local-born fallback: when no Firebase user, render from the
    // auth-state user (populated by LocalAuthService sign-in/sign-up).
    if (user == null) {
      final authState = ref.watch(authStateProvider);
      if (!authState.isSignedIn || !authState.isLocalBorn) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 48),
              SizedBox(width: 16),
              Text('Not signed in'),
            ],
          ),
        );
      }
      return _LocalBornProfileRow(
        theme: theme,
        authUser: authState.currentUser!,
      );
    }

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
        'User';
    final profileInitial = _profileInitial(displayName);

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SELF-LEARNER',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user.email != null)
                    Text(
                      user.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8E97A6),
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
      ),
    );
  }
}

/// Profile row for local-born accounts. Mirrors the layout of the
/// Firebase-user row but reads from [AuthUser] (no Firebase user
/// exists for local-born accounts) and hides the edit-name button
/// since that path goes through Firebase.
class _LocalBornProfileRow extends ConsumerWidget {
  const _LocalBornProfileRow({required this.theme, required this.authUser});

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

    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
      ),
    );
  }
}

/// Parental controls section — only rendered when the signed-in user is in
/// child mode. Surfaces tiles to enter parent mode and manage the parent PIN.
///
/// The PIN is stored locally via [PinService] (bcrypt hash in secure storage)
/// and never synced to Firestore.
class _ParentalControlsSection extends ConsumerStatefulWidget {
  const _ParentalControlsSection({
    required this.user,
    required this.isChildProfile,
  });

  final User? user;
  final bool isChildProfile;

  @override
  ConsumerState<_ParentalControlsSection> createState() =>
      _ParentalControlsSectionState();
}

class _ParentalControlsSectionState
    extends ConsumerState<_ParentalControlsSection> {
  bool _hasPin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pinService = ref.read(pinServiceProvider);
    final profileId = ref.read(selectedProfileIdProvider);
    final hasPin = profileId == null
        ? false
        : await pinService.hasProfilePin(profileId);
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !widget.isChildProfile) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(title: 'PARENTAL CONTROLS'),
        const SizedBox(height: 10),
        _SurfaceCard(
          child: _SettingsTile(
            icon: Icons.admin_panel_settings_outlined,
            iconColor: AppTheme.brandCoralDeep,
            iconBackground: const Color(0xFFF8E3E7),
            title: 'Parent Mode',
            subtitle: 'Switch to admin (PIN-guarded)',
            trailing: Icon(
              _hasPin ? Icons.lock : Icons.lock_open,
              color: theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            onTap: () async {
              ref.read(routerProvider).parentPinGuard.lock();
              await context.pushRoute(const ParentSettingsRoute());
              if (mounted) await _load();
            },
          ),
        ),
        const SizedBox(height: 12),
        _SurfaceCard(
          child: _SettingsTile(
            icon: Icons.pin_outlined,
            iconColor: AppTheme.brandInkMuted,
            iconBackground: AppTheme.brandCreamSoft,
            title: 'Parent PIN',
            subtitle: 'Change your security PIN',
            onTap: () async {
              final route = _hasPin
                  ? const PinChangeRoute()
                  : const PinSetupRoute();
              final result = (await context.pushRoute<bool>(route)) ?? false;
              if (result && mounted) await _load();
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

Future<void> _showChangePasswordFlow(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully.')),
    );
  }
}

class _LanguageTile extends ConsumerWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    final label = supportedLanguages[current] ?? current;

    return _SettingsTile(
      icon: Icons.language_rounded,
      iconColor: AppTheme.brandInkMuted,
      iconBackground: AppTheme.brandCreamSoft,
      title: 'Language',
      subtitle: label,
      onTap: () => _showLanguagePicker(context, ref, current),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Choose Language',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Preferred language for content',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final entry in supportedLanguages.entries)
                ListTile(
                  title: Text(entry.value),
                  trailing: current == entry.key
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(languageProvider.notifier).setLanguage(entry.key);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
          'No Backup',
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
