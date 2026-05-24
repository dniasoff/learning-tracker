import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    hide authStateProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_portal_bottom_nav.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/backup_sync_section.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Configuration hub shown to a parent when their child profile is active.
///
/// Includes the same profile header as Settings (avatar, name, account email;
/// tap opens profile picker). Surfaces parent-only controls: managing tracks,
/// point configuration, backup/sync, and lifetime learning entries.
@RoutePage()
class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  static const Color _pageBg = Color(0xFFF2F3F7);
  static const Color _managePurple = Color(0xFF7B5FD9);
  static const Color _iconCircleMuted = Color(0xFFE8EBF2);
  static const Color _iconMutedFg = Color(0xFF6B7280);
  static const Color _chevronMuted = Color(0xFFC2C9D3);
  static const Color _dangerIconBg = Color(0xFFFFE8EA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authRepositoryProvider).currentUser;
    final authState = ref.watch(authStateProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final activeProfile = profilesAsync.asData?.value
        .where((p) => p.id == activeProfileId)
        .firstOrNull;
    final showDeleteAccountTile = user != null || authState.isLocalBorn;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _pageBg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppTheme.brandBlueDeep,
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(
          l10n.parentSettingsTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppTheme.brandBlueDeep,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // WS1.consolidate: the GestureDetector that routed to ProfilePicker
                // has been removed — the always-on avatar switcher in the bottom nav
                // is the canonical switch path (DEC-11).
                UserProfileHeaderCard(
                  user: user,
                  activeProfile: activeProfile,
                  surface: UserProfileHeaderSurface.parent,
                ),
                const SizedBox(height: 16),
                _WhitePanel(
                  // WS1.consolidate: "Switch Profile" row removed — the always-on
                  // avatar switcher in the bottom nav is the canonical path (DEC-11).
                  child: Column(
                    children: [
                      _ManageRow(
                        iconBackground: _managePurple,
                        icon: Icons.route_rounded,
                        iconColor: Colors.white,
                        title: l10n.manageTracks,
                        subtitle: l10n.manageTracksForChildSubtitle,
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: _chevronMuted,
                          size: 26,
                        ),
                        onTap: () => context.pushRoute(
                          const ParentTrackManagementRoute(),
                        ),
                      ),
                      _rowDivider(),
                      _ManageRow(
                        iconBackground: _iconCircleMuted,
                        icon: Icons.tune_rounded,
                        iconColor: _iconMutedFg,
                        title: l10n.pointConfiguration,
                        subtitle: l10n.pointConfigurationSubtitle,
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: _chevronMuted,
                          size: 26,
                        ),
                        onTap: () =>
                            context.pushRoute(const PointConfigRoute()),
                      ),
                      _rowDivider(),
                      _ManageRow(
                        iconBackground: const Color(0xFFFFE8CC),
                        icon: Icons.card_giftcard_rounded,
                        iconColor: const Color(0xFFB45309),
                        title: l10n.rewardConfigurationTitle,
                        subtitle: l10n.rewardConfigurationSubtitle,
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: _chevronMuted,
                          size: 26,
                        ),
                        onTap: () =>
                            context.pushRoute(const RewardConfigurationRoute()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _WhitePanel(
                  child: _ManageRow(
                    iconBackground: const Color(0xFFE8D4B8),
                    icon: Icons.menu_book_rounded,
                    iconColor: const Color(0xFF6B4E2E),
                    leadingSquare: true,
                    title: l10n.addWhatYouLearned,
                    subtitle: l10n.addWhatYouLearnedSettingsSubtitle,
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: _chevronMuted,
                      size: 26,
                    ),
                    onTap: () =>
                        context.pushRoute(const LifetimeMarkingRoute()),
                  ),
                ),
                const SizedBox(height: 16),
                const BackupSyncSection(parentSettingsHeroLayout: true),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 4,
                    bottom: 8,
                  ),
                  child: Text(
                    l10n.sectionAccountSafety,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF9AA3B0),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      fontSize: 11,
                    ),
                  ),
                ),
                _WhitePanel(
                  child: _ManageRow(
                    iconBackground: _dangerIconBg,
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.chartRed,
                    title: l10n.signOut,
                    titleColor: AppColors.chartRed,
                    subtitle: null,
                    leadingSquare: true,
                    trailing: const Icon(
                      Icons.logout_outlined,
                      color: AppColors.chartRed,
                      size: 24,
                    ),
                    onTap: () => showSignOutConfirmation(context, ref),
                  ),
                ),
                if (showDeleteAccountTile) ...[
                  const SizedBox(height: 12),
                  _WhitePanel(
                    child: _ManageRow(
                      iconBackground: _dangerIconBg,
                      icon: Icons.delete_forever_rounded,
                      iconColor: const Color(0xFFB00020),
                      title: l10n.deleteAccountTitle,
                      titleColor: const Color(0xFFB00020),
                      subtitle: authState.isLocalBorn
                          ? l10n.deleteLocalAccountSubtitle
                          : l10n.deleteAccountSubtitle,
                      subtitleColor: const Color(0xFFB00020),
                      leadingSquare: true,
                      trailing: const SizedBox.shrink(),
                      onTap: () {
                        if (authState.isLocalBorn) {
                          showDeleteLocalAccountFlow(context, ref);
                        } else if (user != null) {
                          showDeleteAccountFlow(context, ref, user);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          ParentPortalBottomNav(
            selectedIndex: 3,
            onSelect: (index) => unawaited(
              navigateParentPortalTab(context, index, currentTabIndex: 3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      endIndent: 16,
      color: AppColors.surfaceE9,
    );
  }
}

class _WhitePanel extends StatelessWidget {
  const _WhitePanel({required this.child});

  final Widget child;

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
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.iconBackground,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.titleColor,
    this.subtitleColor,
    this.onTap,
    this.leadingSquare = false,
  });

  final Color iconBackground;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final Color? titleColor;
  final Color? subtitleColor;
  final VoidCallback? onTap;
  final bool leadingSquare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: leadingSquare
                      ? BorderRadius.circular(12)
                      : null,
                  shape: leadingSquare ? BoxShape.rectangle : BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor ?? AppTheme.brandInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor ?? AppColors.inkMidGrey,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
