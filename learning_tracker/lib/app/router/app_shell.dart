import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/offline_top_banner.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';

// W6.15: Tutor mode colour accent — a warm amber that contrasts with the
// app's primary blue to signal "you are in a different access context".
const _tutorAccentColor = Color(0xFFD97706); // Amber-600

// WS4.banner: Child-view banner colour — a teal/emerald green that is distinct
// from both the tutor amber and the primary blue, signalling "you are inside a
// child's profile, not your own".
const _childViewAccentColor = Color(0xFF047857); // Emerald-700

@RoutePage()
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  // Tracks whether we have already jumped to the Settings tab for a
  // profile-less user.  Reset when profiles become non-empty so that a user
  // who later adds a profile starts back on Dashboard.
  bool _didJumpToSettings = false;

  @override
  Widget build(BuildContext context) {
    // When the Firebase uid changes (account switch or sign-out), clear any
    // active tutored selection so the keepAlive state doesn't leak into the
    // next account's session. The listen is mounted in AppShell so widget
    // tests that don't render the shell never materialise FirebaseAuth.
    ref.listen(authStateProvider.select((s) => s.currentUser?.firebaseUid), (
      previous,
      next,
    ) {
      if (previous != next) {
        ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
      }
    });

    // R3o-C2 / R2o-H2: drive the tutor indicator from the ACTIVE tutored
    // selection (the tutor has actually entered a talmid's context after the
    // PIN gate), NOT from mere grant existence. A parent who merely *holds*
    // tutor grants but is using their own/child profile is not "in tutor mode".
    final activeTutoredSelection = ref.watch(
      activeTutoredProfileSelectionProvider,
    );
    final hasActiveTutoredProfiles = activeTutoredSelection != null;

    // R3-fix: keep incomingTutorGrantsProvider subscribed for the duration of a
    // tutored session so its revocation-reconciliation (wipe + auto-exit) runs
    // whenever the CF result lands — not only when a grants-watching screen is
    // mounted. Without this watch, a tutor deep in Dashboard/Learn/Content would
    // never detect a parent's mid-session revocation until navigating back to a
    // grants screen. The value is intentionally ignored; the subscription is what
    // matters. Gated on an active session so non-tutor sessions pay no cost.
    if (hasActiveTutoredProfiles) {
      ref.watch(incomingTutorGrantsProvider);
    }

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profilesAsync = ref.watch(profileListStreamProvider);
    final profiles = profilesAsync.asData?.value ?? <ProfileModel>[];
    final activeProfile = profiles
        .where((p) => p.id == activeProfileId)
        .firstOrNull;

    // No own profiles and not in a tutored session → the shell jumps to the
    // Settings tab once (scheduled in appBarBuilder below) so the user (e.g. a
    // tutor-only adult) can manage their account / add a profile instead of
    // being stuck on an empty Dashboard. The jump MUST be scheduled from inside
    // AutoTabsScaffold's builder — it hands us a valid `tabsRouter`; calling
    // AutoTabsRouter.of() with this State's own context throws, because the
    // State sits ABOVE the tabs router, not below it.
    final hasNoOwnProfiles =
        profilesAsync.hasValue && profiles.isEmpty && !hasActiveTutoredProfiles;
    if (!hasNoOwnProfiles) {
      _didJumpToSettings = false; // reset so next no-profile state jumps again
    }

    // Parent mode is an ELEVATION, not a side-effect of selecting a child.
    // The "Parent mode — viewing [child]" banner shows ONLY when the parent
    // PIN has actually been entered this session for the currently-active
    // child profile. Merely selecting a child drops you into that child's
    // learning view with no banner and no PIN; managing the child requires
    // entering parent mode (PIN once), which sets the elevation flag below.
    final parentAuthedProfileId = ref.watch(
      parentPinAuthenticatedProfileIdProvider,
    );
    final parentModeActive =
        parentAuthedProfileId != null &&
        parentAuthedProfileId == activeProfileId &&
        activeProfile?.profileMode == ProfileMode.child;
    // Tutor mode has its own indicator bar; only one context banner shows.
    final isViewingChildProfile = !hasActiveTutoredProfiles && parentModeActive;
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
          // Profile-less users land on the Settings tab (see hasNoOwnProfiles
          // above). Scheduled here because AutoTabsScaffold hands us a valid
          // tabsRouter; doing it from this State's own context would throw.
          if (hasNoOwnProfiles && !_didJumpToSettings) {
            _didJumpToSettings = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (tabsRouter.activeIndex != 3) tabsRouter.setActiveIndex(3);
            });
          }
          final topInset = MediaQuery.of(innerContext).padding.top;
          final bannerHeight = offlineBannerVisible ? 32.0 : 0.0;
          final tutorHeight = hasActiveTutoredProfiles ? 24.0 : 0.0;
          // WS4.banner: child-view bar height — only when no tutor bar.
          final childViewHeight = isViewingChildProfile ? 28.0 : 0.0;
          // §5 persistent switcher (feedback_profile_switcher_top): the
          // profile/role switcher must be present at the TOP of EVERY context.
          // The tutor and parent-child contexts have their own tappable bars
          // (both open the switcher); the DEFAULT own-profile context — shown
          // when neither of those bars is — previously had NO switcher at all.
          // This slim, always-present identity bar is that switcher entry.
          final showSwitcherBar =
              !hasActiveTutoredProfiles && !isViewingChildProfile;
          final switcherHeight = showSwitcherBar ? 44.0 : 0.0;
          return PreferredSize(
            preferredSize: Size.fromHeight(
              topInset +
                  bannerHeight +
                  tutorHeight +
                  childViewHeight +
                  switcherHeight,
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
                  // Tutor mode bar — tappable to open profile switcher.
                  if (hasActiveTutoredProfiles) const _TutorModeIndicatorBar(),
                  // WS4.banner (DEC-25): "Viewing [child]" banner for the
                  // parent/child-mode path. Only shown when a child profile is
                  // active and no tutor bar is already displayed.
                  // Now tappable → profile switcher (Fix 1).
                  // Default context (own profile, not tutor, not parent-mode):
                  // the always-present profile/role switcher bar.
                  if (showSwitcherBar) const _ProfileSwitcherBar(),
                  if (isViewingChildProfile && viewingChildName != null)
                    _ChildViewBanner(
                      childName: viewingChildName,
                      profiles: profiles,
                      onExit: () {
                        // Exiting parent mode drops the elevation only — the
                        // CHILD profile stays active and we land back in the
                        // child's learning view. Locking the PIN guard clears
                        // the parent-auth flag (via onSessionLocked), so the
                        // banner disappears and the next parent-gated action
                        // re-prompts. We do NOT switch to the adult profile;
                        // the adult's own profile is reached via the switcher.
                        ref.read(routerProvider).pinGuard.lock();
                        innerContext.router.replaceAll([const AppShellRoute()]);
                      },
                    ),
                ],
              ),
            ),
          );
        },
        bottomNavigationBuilder: (context, tabsRouter) {
          // Parent mode (own child, PIN-elevated) navigates via the
          // ParentSettingsScreen rows, so it has no bottom nav. The TUTOR
          // talmid view, by contrast, is the full parent-equivalent app and
          // needs the standard tabs (Dashboard/Learn/Progress/Settings) to
          // move between the talmid's surfaces.
          if (parentModeActive) {
            return const SizedBox.shrink();
          }
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

// §5 persistent switcher (feedback_profile_switcher_top): the always-present
// profile/role switcher bar shown in the DEFAULT own-profile context.
//
// Product rule: a tappable role label must sit at the TOP of EVERY context
// (Dashboard / Learn / Progress / Settings), opening the profile + mode
// switcher. The tutor and parent-child contexts have their own tappable bars
// (_TutorModeIndicatorBar / _ChildViewBanner, both → showProfileSwitcherSheet);
// this bar covers the default own-profile context, which previously had no
// switcher entry at all. Shows the active profile name + role badge + an
// unfold affordance, and opens the canonical switcher sheet on tap.
class _ProfileSwitcherBar extends ConsumerWidget {
  const _ProfileSwitcherBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;

    final activeProfileId = ref.watch(activeProfileIdProvider);
    final profiles =
        ref.watch(profileListStreamProvider).asData?.value ??
        const <ProfileModel>[];
    final activeProfile = profiles
        .where((p) => p.id == activeProfileId)
        .firstOrNull;
    // Same fallback chain as UserProfileHeaderCard: prefer the active profile's
    // name, then the signed-in account's display name / email handle, then a
    // generic label. A self-learner whose identity lives on the account (no
    // separate profile row, or before the profile stream resolves) still shows
    // their real name — not the generic "User" fallback.
    final authUser = ref.watch(authStateProvider).currentUser;
    String? accountName;
    if (authUser != null) {
      if (authUser.displayName.trim().isNotEmpty) {
        accountName = authUser.displayName.trim();
      } else if (authUser.email.contains('@')) {
        accountName = authUser.email.split('@').first;
      }
    }
    final displayName =
        activeProfile?.displayName ??
        accountName ??
        l10n.userFallbackDisplayName;
    final trimmed = displayName.trim();
    final initial = trimmed.isEmpty
        ? 'U'
        : trimmed.substring(0, 1).toUpperCase();

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const Key('appShellProfileSwitcherBar'),
        onTap: () => showProfileSwitcherSheet(context),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            border: Border(
              bottom: BorderSide(color: primary.withValues(alpha: 0.10)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.14),
                ),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.selfLearnerBadge,
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.unfold_more_rounded, size: 20, color: primary),
            ],
          ),
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
    return GestureDetector(
      onTap: () => showProfileSwitcherSheet(context),
      child: Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
      ), // Container
    ); // GestureDetector
  }
}

// W6.15 / T3.readonly-state: Tutor mode indicator bar.
//
// A narrow banner shown below the offline-sync strip when the user has entered
// a tutored profile context. Shows the talmid's name and a one-tap Exit button.
// Tapping Exit clears the active tutored context and navigates back to the
// AppShell (which resolves to the tutor's own profile).
class _TutorModeIndicatorBar extends ConsumerWidget {
  const _TutorModeIndicatorBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => showProfileSwitcherSheet(context),
      child: Container(
        height: 24,
        color: _tutorAccentColor,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.school_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.tutorModeIndicator,
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
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  ref
                      .read(activeTutoredProfileSelectionProvider.notifier)
                      .exit();
                  context.router.replaceAll([const AppShellRoute()]);
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                        l10n.tutorModeExit,
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
      ),
    );
  }
}
