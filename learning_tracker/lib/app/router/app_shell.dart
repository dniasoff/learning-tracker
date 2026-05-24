import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/offline_top_banner.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// W6.15: Tutor mode colour accent — a warm amber that contrasts with the
// app's primary blue to signal "you are in a different access context".
const _tutorAccentColor = Color(0xFFD97706); // Amber-600

@RoutePage()
class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // W6.15: Detect if the current user is actively tutoring any profile.
    // We use the incoming grants list as a lightweight signal — if any active
    // grants exist for the current user as tutor, we show the indicator.
    // A fuller implementation (post data-layer) will track the selected session.
    final grantsAsync = ref.watch(incomingTutorGrantsProvider);
    final hasActiveTutoredProfiles =
        grantsAsync.asData?.value.any((g) => g.grantState is ActiveGrant) ??
        false;

    // Determine offline-banner visibility here so the appBar's PreferredSize
    // can size itself to the actual rendered content (banner + tutor bar +
    // status-bar inset). Without this, the PreferredSize is fixed regardless
    // of state — content either overflows behind the system status bar
    // (when offline) or leaves an empty gap (when online).
    final isCloudBorn = ref.watch(authStateProvider).isCloudBorn;
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOnline = connectivity.maybeWhen(
      data: (online) => online,
      orElse: () => true,
    );
    final offlineBannerVisible = isCloudBorn && !isOnline;

    return SacredTimeLockOverlay(
      child: AutoTabsScaffold(
        routes: const [
          DashboardRoute(),
          LearningRoute(),
          ProgressRoute(),
          SettingsRoute(),
        ],
        // Epic 20.8: top offline banner — cloud-born only, tier-gated
        // inside the widget so local-born users never see it.
        // W6.15: When the user has active tutor grants, we show a subtle
        // tutor-mode indicator alongside the offline banner.
        appBarBuilder: (innerContext, tabsRouter) {
          final topInset = MediaQuery.of(innerContext).padding.top;
          final bannerHeight = offlineBannerVisible ? 32.0 : 0.0;
          final tutorHeight = hasActiveTutoredProfiles ? 24.0 : 0.0;
          return PreferredSize(
            preferredSize: Size.fromHeight(
              topInset + bannerHeight + tutorHeight,
            ),
            child: Padding(
              // Push our custom appBar content below the system status bar.
              // Unlike Material's AppBar, raw PreferredSize doesn't inset
              // automatically, so we add the inset ourselves.
              padding: EdgeInsets.only(top: topInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OfflineTopBanner(visible: offlineBannerVisible),
                  // WS1.consolidate: tutor bar is a context indicator only —
                  // the switch affordance is removed; use the bottom-nav avatar
                  // switcher to change profiles.
                  if (hasActiveTutoredProfiles)
                    const _TutorModeIndicatorBar(),
                ],
              ),
            ),
          );
        },
        bottomNavigationBuilder: (context, tabsRouter) {
          final l10n = AppLocalizations.of(context)!;
          final items = [
            (icon: Icons.space_dashboard_rounded, label: l10n.tabBarDashboard),
            (icon: Icons.menu_book_rounded, label: l10n.tabBarLearn),
            (icon: Icons.auto_graph_rounded, label: l10n.tabBarProgress),
            (icon: Icons.settings_rounded, label: l10n.tabBarSettings),
          ];
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x140038A8),
                  blurRadius: 18,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      Expanded(
                        child: _ShellNavItem(
                          icon: items[index].icon,
                          label: items[index].label,
                          selected: tabsRouter.activeIndex == index,
                          onTap: () => tabsRouter.setActiveIndex(index),
                        ),
                      ),
                    // DEC-11 / DEC-30: Always-on profile/account switcher avatar.
                    // Count-gated inside the widget — only shows when ≥2 profiles
                    // OR ≥2 accounts are available to switch between.
                    const _ProfileSwitcherButton(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : const Color(0xFF708090);
    final fontWeight = selected ? FontWeight.w700 : FontWeight.w600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0038A8) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x330038A8),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 9,
                letterSpacing: 0.4,
                fontWeight: fontWeight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// W6.15: Tutor mode indicator bar.
//
// A narrow banner shown below the offline-sync strip when the user has
// active tutor grants. It is a context indicator only — the switch
// affordance was removed in WS1.consolidate. Use the bottom-nav avatar
// switcher (DEC-11) to change profiles.
class _TutorModeIndicatorBar extends StatelessWidget {
  const _TutorModeIndicatorBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 24,
      color: _tutorAccentColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            l10n.tutorModeIndicator,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DEC-11 / DEC-30: Always-on profile/account switcher ──────────────────────
//
// An avatar button embedded in the bottom nav bar. Count-gated (DEC-30):
// hidden entirely when the current login has exactly 1 profile AND only
// 1 account is registered on the device.
//
// Tapping opens a bottom sheet that lists:
//   - Profiles on the current login (if ≥2 profiles)
//   - Signed-in accounts from the device registry (if ≥2 accounts)
//   - "Add account" entry

class _ProfileSwitcherButton extends ConsumerWidget {
  const _ProfileSwitcherButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListStreamProvider);
    final profiles = profilesAsync.asData?.value ?? [];
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final activeProfile = profiles.where((p) => p.id == activeProfileId).firstOrNull;

    // We need the registry account count. Use a FutureBuilder-style approach
    // by watching the registry directly via a provider.
    return _ProfileSwitcherButtonInner(
      profiles: profiles,
      activeProfile: activeProfile,
    );
  }
}

class _ProfileSwitcherButtonInner extends ConsumerStatefulWidget {
  const _ProfileSwitcherButtonInner({
    required this.profiles,
    required this.activeProfile,
  });

  final List<ProfileModel> profiles;
  final ProfileModel? activeProfile;

  @override
  ConsumerState<_ProfileSwitcherButtonInner> createState() =>
      _ProfileSwitcherButtonInnerState();
}

class _ProfileSwitcherButtonInnerState
    extends ConsumerState<_ProfileSwitcherButtonInner> {
  List<DeviceAccount>? _accounts;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final registry = ref.read(deviceRegistryProvider);
    final accounts = await registry.getAllAccounts();
    if (mounted) {
      setState(() => _accounts = accounts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts ?? [];
    final profileCount = widget.profiles.length;
    final accountCount = accounts.length;

    // DEC-30: count-gate — show nothing for a solo single-profile/single-account user.
    final hasSomethingToSwitch = profileCount >= 2 || accountCount >= 2;
    if (!hasSomethingToSwitch) return const SizedBox.shrink();

    final activeProfile = widget.activeProfile;
    final initial = activeProfile != null && activeProfile.displayName.isNotEmpty
        ? activeProfile.displayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: () => _openSwitcher(context, accounts),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.brandBlueSoft,
            border: Border.all(
              color: AppTheme.brandBlueBright.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: AppTheme.brandBlueDeep,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  void _openSwitcher(BuildContext context, List<DeviceAccount> accounts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SwitcherSheet(
        profiles: widget.profiles,
        accounts: accounts,
        activeProfileId: ref.read(activeProfileIdProvider),
        onProfileSelected: (id) => _switchProfile(id),
        onAccountSelected: (account) => _switchAccount(account),
        onAddAccount: () => unawaited(ctx.router.push(SignupRoute())),
      ),
    );
  }

  void _switchProfile(int profileId) {
    Navigator.of(context).pop(); // close sheet
    ref.read(selectedProfileIdProvider.notifier).select(profileId);
    // Navigate back to shell to trigger profile reload — no sign-out.
    unawaited(context.router.replaceAll([const AppShellRoute()]));
  }

  Future<void> _switchAccount(DeviceAccount account) async {
    Navigator.of(context).pop(); // close sheet

    // Swap the Drift DB to the target account (DEC-34: no signOut()).
    ref.read(accountDbFileNameProvider.notifier).setFileName(account.dbFileName);
    ref.invalidate(userDatabaseProvider);

    final dao = ref.read(userDatabaseProvider).userProfileDao;

    // Look up the first profile in the target account's DB.
    final profiles = await dao.getAllUserProfiles();
    if (profiles.isEmpty || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final session = SessionPersistenceService(
      prefs: prefs,
      registry: ref.read(deviceRegistryProvider),
    );
    await session.setActiveAccount(account.accountId);
    await prefs.setBool(kOnboardingComplete, true);

    // Set auth state from the first profile in this account's DB.
    final profile = profiles.first;
    if (profile.tier == 'cloudBorn') {
      ref.read(authStateProvider.notifier).setCloudBornSession(profile: profile);
    } else {
      ref.read(authStateProvider.notifier).setLocalBornSession(profile: profile);
    }

    if (mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }

    // Reload accounts list after switch.
    await _loadAccounts();
  }
}

// ─── Switcher bottom sheet ──────────────────────────────────────────────────

class _SwitcherSheet extends StatelessWidget {
  const _SwitcherSheet({
    required this.profiles,
    required this.accounts,
    required this.activeProfileId,
    required this.onProfileSelected,
    required this.onAccountSelected,
    required this.onAddAccount,
  });

  final List<ProfileModel> profiles;
  final List<DeviceAccount> accounts;
  final int activeProfileId;
  final void Function(int profileId) onProfileSelected;
  final void Function(DeviceAccount account) onAccountSelected;
  final VoidCallback onAddAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showProfiles = profiles.length >= 2;
    final showAccounts = accounts.length >= 2;

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
              // Drag handle
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

              // Profiles section (count-gate: ≥2 profiles)
              if (showProfiles) ...[
                Text(
                  'Profiles',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                for (final profile in profiles)
                  _SwitcherProfileTile(
                    profile: profile,
                    isActive: profile.id == activeProfileId,
                    onTap: () => onProfileSelected(profile.id),
                  ),
                const SizedBox(height: 12),
              ],

              // Accounts section (count-gate: ≥2 accounts)
              if (showAccounts) ...[
                Text(
                  'Accounts',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                for (final account in accounts)
                  _SwitcherAccountTile(
                    account: account,
                    onTap: () => onAccountSelected(account),
                  ),
                const SizedBox(height: 12),
              ],

              // Add account (always shown)
              ListTile(
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
                title: const Text(
                  'Add account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brandBlueDeep,
                  ),
                ),
                onTap: onAddAccount,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitcherProfileTile extends StatelessWidget {
  const _SwitcherProfileTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  final ProfileModel profile;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : '?';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive
            ? AppTheme.brandBlueBright.withValues(alpha: 0.15)
            : AppTheme.brandBlueSoft,
        child: Text(
          initial,
          style: TextStyle(
            color: isActive ? AppTheme.brandBlueBright : AppTheme.brandBlueDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        profile.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        profile.profileMode.name,
        style: const TextStyle(color: AppTheme.brandInkMuted, fontSize: 12),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle_rounded, color: AppTheme.brandBlueBright)
          : null,
      onTap: isActive ? null : onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _SwitcherAccountTile extends StatelessWidget {
  const _SwitcherAccountTile({
    required this.account,
    required this.onTap,
  });

  final DeviceAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = account.displayName.isNotEmpty
        ? account.displayName[0].toUpperCase()
        : account.email[0].toUpperCase();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.brandBlueSoft,
        child: Text(
          initial,
          style: const TextStyle(
            color: AppTheme.brandBlueDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        account.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        account.email,
        style: const TextStyle(color: AppTheme.brandInkMuted, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.brandInkMuted,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
