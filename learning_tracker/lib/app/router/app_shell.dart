import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/offline_top_banner.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// W6.15: Tutor mode colour accent — a warm amber that contrasts with the
// app's primary blue to signal "you are in a different access context".
const _tutorAccentColor = Color(0xFFD97706); // Amber-600

// WS4.banner: Child-view banner colour — a teal/emerald green that is distinct
// from both the tutor amber and the primary blue, signalling "you are inside a
// child's profile, not your own".
const _childViewAccentColor = Color(0xFF047857); // Emerald-700

@RoutePage()
class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // R3o-C2 / R2o-H2: drive the tutor indicator from the ACTIVE tutored
    // selection (the tutor has actually entered a talmid's context after the
    // PIN gate), NOT from mere grant existence. A parent who merely *holds*
    // tutor grants but is using their own/child profile is not "in tutor mode".
    final activeTutoredSelection = ref.watch(
      activeTutoredProfileSelectionProvider,
    );
    final hasActiveTutoredProfiles = activeTutoredSelection != null;

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final profiles = profilesAsync.asData?.value ?? <ProfileModel>[];
    final activeProfile = profiles
        .where((p) => p.id == activeProfileId)
        .firstOrNull;

    // R3o-C1: the "Viewing [child]" banner must show ONLY when an ADULT has
    // switched into a CHILD's profile — never for a standalone child using
    // their own profile. The "adult is viewing a child" signal is derived
    // from: the active profile is a child AND this account owns at least one
    // adult profile (a parent+child account). A standalone-child account has
    // no adult profile, so the banner is correctly suppressed there.
    final hasAdultProfile = profiles.any(
      (p) => p.profileMode == ProfileMode.adult,
    );
    final adultIsViewingChild =
        activeProfile?.profileMode == ProfileMode.child && hasAdultProfile;
    // Tutor mode has its own indicator bar; only one context banner shows.
    final isViewingChildProfile =
        !hasActiveTutoredProfiles && adultIsViewingChild;
    final viewingChildName = isViewingChildProfile
        ? (activeProfile?.displayName ?? '')
        : null;

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
          // WS4.banner: child-view bar height — only when no tutor bar.
          final childViewHeight = isViewingChildProfile ? 28.0 : 0.0;
          return PreferredSize(
            preferredSize: Size.fromHeight(
              topInset + bannerHeight + tutorHeight + childViewHeight,
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
                  if (hasActiveTutoredProfiles) const _TutorModeIndicatorBar(),
                  // WS4.banner (DEC-25): "Viewing [child]" banner for the
                  // parent/child-mode path. Only shown when a child profile is
                  // active and no tutor bar is already displayed.
                  if (isViewingChildProfile && viewingChildName != null)
                    _ChildViewBanner(
                      childName: viewingChildName,
                      profiles: profiles,
                      onExit: () {
                        // R3o-M1: Exit must deterministically return to the
                        // ADULT/parent context — never to another child. The
                        // banner only renders when an adult profile exists, so
                        // an adult is always present; select it. If somehow no
                        // adult exists, clear the selection and let the
                        // ProfileGuard route to the picker (open the switcher)
                        // rather than silently re-entering another child.
                        final adultProfile = profiles
                            .where((p) => p.profileMode == ProfileMode.adult)
                            .firstOrNull;
                        if (adultProfile != null) {
                          ref
                              .read(selectedProfileIdProvider.notifier)
                              .select(adultProfile.id);
                        } else {
                          ref.read(selectedProfileIdProvider.notifier).clear();
                        }
                        innerContext.router.replaceAll([const AppShellRoute()]);
                      },
                    ),
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
                    // The bottom-nav avatar switcher was retired: tapping the
                    // profile NAME/header in Settings is now the canonical
                    // profile switcher/manager. Account switching lives under
                    // Settings → ACCOUNT and the empty-login surface.
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

// WS4.banner (DEC-25 / D3): "Viewing [child]" banner.
//
// A slim strip shown below the offline-sync strip (and above any other bar)
// when a parent has an active child profile selected. Provides a one-tap
// exit that switches back to the first available adult profile on this login.
//
// Only shown when:
//   • The active profile is a child (ProfileMode.child), AND
//   • No tutor-mode bar is displayed (tutor mode has its own indicator).
//
// The exit callback switches the selected profile to the first adult profile
// in [profiles] (or the first profile in the list when no adult exists) and
// replaces the route stack with the AppShell, exactly as the switcher does.
class _ChildViewBanner extends ConsumerWidget {
  const _ChildViewBanner({
    required this.childName,
    required this.profiles,
    required this.onExit,
  });

  final String childName;
  final List<ProfileModel> profiles;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 28,
      color: _childViewAccentColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.child_care_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.viewingChildBanner(childName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Explicit, labelled "Exit parent mode" button — returns the parent
          // to their own (adult) profile via [onExit].
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onExit,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.viewingChildBannerExit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
