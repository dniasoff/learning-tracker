import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/root_scaffold_messenger.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/offline_top_banner.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Computes the rendered height of a context banner / the persistent
/// switcher bar at the given [textScaler].
///
/// AUD-app-01: [ChildViewBanner], [TutorModeIndicatorBar], and
/// [ProfileSwitcherBar] no longer hardcode a literal `height:` — each sizes
/// to content, floored at [kMinInteractiveDimension] (48dp) so its Exit/tap
/// affordance always meets the Material minimum touch-target size, and grown
/// further when [textScaler] would otherwise make the label taller than
/// 48dp (large accessibility text scales). The [PreferredSize] reserved by
/// [AppShellScreen]'s `appBarBuilder` uses this SAME formula so the space it
/// reserves always matches the actual rendered height — never clipping text.
double _contextBarHeight(TextScaler textScaler, {required double fontSizeSp}) {
  // 1.3x is a conservative line-height multiplier that comfortably covers
  // ascenders/descenders/diacritics across scripts, including Hebrew nikkud.
  final textDrivenHeight = textScaler.scale(fontSizeSp) * 1.3;
  final floor = textDrivenHeight > kMinInteractiveDimension
      ? textDrivenHeight
      : kMinInteractiveDimension;
  // +1dp safety margin: the real font's measured line-box (GoogleFonts +
  // platform text layout) can land a sub-pixel above this formula's estimate
  // even when it comfortably fits the ConstrainedBox floor inside the bar
  // itself — this guards the PreferredSize reservation against that rounding
  // slop so it never reserves exactly the boundary and clips by a pixel.
  return floor + 1.0;
}

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

  // Convert-on-reconnect prompt (offline-account back-up nudge): shown at most
  // once per shell session, when a signed-in local-born account is confirmed
  // online. Routes into the existing Upgrade-to-Cloud flow.
  bool _upgradePromptShown = false;

  // AUD-profiles-21: guards the BUG D1 auto-select/self-heal effect
  // (`autoSelectedProfileIdProvider.ensureSelected()`) so it fires once per
  // signed-in session rather than on every rebuild. Reset on sign-out so a
  // later sign-in re-triggers it — mirrors `_didJumpToSettings` below.
  bool _autoSelectRan = false;

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
        // SECURITY (run-10 follow-up, same class as the P0 fixed in
        // profile_switcher_sheet.dart): also drop any parent-mode elevation.
        // `PinScope.parent(profileId)` is keyed on the bare LOCAL numeric
        // profile id with no account/uid component, so an account switch whose
        // new local profile reuses a numeric id that was elevated under the
        // PREVIOUS account would hit PinGuard's cached scope and skip the
        // prompt. Same-device id collisions are unlikely (ids auto-increment),
        // but a sync/restore or multi-device flow can reintroduce them — and a
        // uid change is exactly the point at which no prior elevation should
        // survive regardless. Cheap, and it fails closed.
        ref.read(routerProvider).pinGuard.lock();
      }
    });

    // T-40: the "heal a profile's missing remote Firestore document on
    // activation" trigger used to live here (`ref.listen(selectedProfileIdProvider,
    // …)`) — dead on every cold-start path, because `ProfileGuard` (a route
    // guard on `AppShellRoute` itself) has already resolved selection
    // before this widget — and a listener mounted inside it — can ever
    // build. Moved to `SelectedProfileId.select()`
    // (`profile_providers.dart`) itself: the one seam every activation path
    // in the app already funnels through, so it fires on cold start too,
    // not only an in-app switch. See that method's own doc comment and
    // `docs/planning/firestore-cutover-log.md`'s `T-40` entries (P2-13/
    // P2-14) for the full post-mortem.

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

    // BUG D1: on a force-stop + cold-start with a still-valid session, the
    // interactive sign-in flow (the only caller of selectedProfileId.select)
    // is skipped, leaving the in-memory selection null → activeProfileId 0 →
    // FK failures on profile_id-scoped writes (track creation's
    // stage_definitions insert). Scheduling this effect re-selects the
    // account's first profile (self-healing a zero-profile account if
    // needed) whenever auth becomes signed-in, including at initial mount if
    // it is already signed-in.
    //
    // AUD-profiles-21 (SM-2 — provider `build` must be pure):
    // `autoSelectedProfileId`'s `build()` is now a pure read; the self-heal
    // side effect lives in its explicit `ensureSelected()` method, which
    // mutates `selectedProfileIdProvider` — a provider write Riverpod
    // forbids while any widget is mid-build. So, like `_didJumpToSettings`
    // and `_upgradePromptShown` below, it is scheduled via
    // `addPostFrameCallback` rather than called synchronously from here or
    // from `initState` (SM-2 also rules out kicking a provider off from
    // `initState`). `_autoSelectRan` makes this a once-per-signed-in-session
    // effect; it resets on sign-out so a later sign-in re-triggers it.
    final isSignedIn = ref.watch(authStateProvider.select((s) => s.isSignedIn));
    if (isSignedIn && !_autoSelectRan) {
      _autoSelectRan = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref.read(autoSelectedProfileIdProvider.notifier).ensureSelected(),
        );
      });
    } else if (!isSignedIn) {
      _autoSelectRan = false;
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

    // Convert-on-reconnect: a signed-in, credential-less local-born account
    // that is now confirmed online (data-only — not the optimistic default) is
    // nudged once to back up via Upgrade to Cloud. Shown as a dismissible
    // MaterialBanner so it doesn't disturb the appBar PreferredSize math.
    final authState = ref.watch(authStateProvider);
    final onlineConfirmed = connectivity.maybeWhen(
      data: (online) => online,
      orElse: () => false,
    );
    if (authState.isSignedIn &&
        authState.isLocalBorn &&
        onlineConfirmed &&
        !_upgradePromptShown) {
      _upgradePromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        // Use the ROOT messenger (keyed on MaterialApp.router): the shell build
        // context sits above AutoTabsScaffold, so ScaffoldMessenger.of(context)
        // resolves to an ancestor messenger with no visible host and the banner
        // silently no-ops.
        final messenger = rootScaffoldMessengerKey.currentState;
        if (messenger == null) return;
        messenger.showMaterialBanner(
          MaterialBanner(
            content: Text(l10n.upgradePromptOnlineBody),
            leading: const Icon(Icons.cloud_upload_outlined),
            actions: [
              TextButton(
                onPressed: messenger.hideCurrentMaterialBanner,
                child: Text(l10n.upgradePromptDismiss),
              ),
              FilledButton(
                onPressed: () {
                  messenger.hideCurrentMaterialBanner();
                  context.router.push(const UpgradeToCloudRoute());
                },
                child: Text(l10n.upgradePromptBackup),
              ),
            ],
          ),
        );
      });
    }

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
          final textScaler = MediaQuery.textScalerOf(innerContext);
          final bannerHeight = offlineBannerVisible ? 32.0 : 0.0;
          // AUD-app-01: content-driven, textScaler-aware height (see
          // _contextBarHeight) — no longer a literal magic-number `height:`.
          final tutorHeight = hasActiveTutoredProfiles
              ? _contextBarHeight(textScaler, fontSizeSp: 11)
              : 0.0;
          // WS4.banner: child-view bar height — only when no tutor bar.
          final childViewHeight = isViewingChildProfile
              ? _contextBarHeight(textScaler, fontSizeSp: 11)
              : 0.0;
          // §5 persistent switcher (feedback_profile_switcher_top): the
          // profile/role switcher must be present at the TOP of EVERY context.
          // The tutor and parent-child contexts have their own tappable bars
          // (both open the switcher); the DEFAULT own-profile context — shown
          // when neither of those bars is — previously had NO switcher at all.
          // This slim, always-present identity bar is that switcher entry.
          final showSwitcherBar =
              !hasActiveTutoredProfiles && !isViewingChildProfile;
          final switcherHeight = showSwitcherBar
              ? _contextBarHeight(textScaler, fontSizeSp: 14)
              : 0.0;
          return PreferredSize(
            preferredSize: Size.fromHeight(
              topInset +
                  bannerHeight +
                  tutorHeight +
                  childViewHeight +
                  switcherHeight,
            ),
            // Bug 7: force the LIGHT theme around the shell's top bars. Under
            // `ThemeMode.system` on a dark-mode device the ambient theme is dark,
            // which flipped the switcher bar to a dark-navy, low-contrast strip
            // while the rest of the (light-only) app stayed light. Pinning the
            // light theme keeps the bar readable on every tab.
            child: Theme(
              data: AppTheme.lightTheme(),
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
                    if (hasActiveTutoredProfiles) const TutorModeIndicatorBar(),
                    // WS4.banner (DEC-25): "Viewing [child]" banner for the
                    // parent/child-mode path. Only shown when a child profile is
                    // active and no tutor bar is already displayed.
                    // Now tappable → profile switcher (Fix 1).
                    // Default context (own profile, not tutor, not parent-mode):
                    // the always-present profile/role switcher bar.
                    if (showSwitcherBar) const ProfileSwitcherBar(),
                    if (isViewingChildProfile && viewingChildName != null)
                      ChildViewBanner(
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
                          innerContext.router.replaceAll([
                            const AppShellRoute(),
                          ]);
                        },
                      ),
                  ],
                ),
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
            decoration: BoxDecoration(
              // brandCreamCard (not Colors.white): run-9 audit — this bar
              // was hardcoded white while its siblings (navBarShadow,
              // navSelectedBlue, navUnselectedText) were already migrated to
              // brightness-aware tokens, leaving a stubbornly light bar under
              // every dark screen (5554, 5562, 5564).
              color: context.colors.brandCreamCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.navBarShadow,
                  blurRadius: 18,
                  offset: const Offset(0, -4),
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
    final foreground = selected
        ? Colors.white
        : context.colors.navUnselectedText;
    final fontWeight = selected ? FontWeight.w700 : FontWeight.w600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? context.colors.navSelectedBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: context.colors.navItemSelectedShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
// (Dashboard / Learn / Progress / Settings — AND every pushed sub-route),
// opening the profile + mode switcher. The tutor and parent-child contexts have
// their own tappable bars (TutorModeIndicatorBar / ChildViewBanner, both →
// showProfileSwitcherSheet); this bar covers the default own-profile context,
// which previously had no switcher entry at all. Shows the active profile name +
// role badge + an unfold affordance, and opens the canonical switcher sheet on
// tap.
//
// Public so the global [PersistentSwitcherScaffold] (mounted in the
// MaterialApp.router builder slot) can render the SAME bar above pushed
// sub-routes, where the shell's own appBar no longer applies. Single source of
// truth for the role-switcher bar across tab views and sub-routes.
class ProfileSwitcherBar extends ConsumerWidget {
  const ProfileSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;
    // Bug 7 (re-fix): the bar previously painted a 6%-alpha translucent
    // background and relied on the ambient (forced-light) surface showing
    // through. On pushed sub-routes the route below — or, under a dark device
    // theme, the system surface — bled through the near-transparent strip,
    // leaving the dark `primary` ink on a near-black background (measured
    // 1.29:1 on Track Detail). Paint a fully OPAQUE background and pin the
    // foreground to a fixed high-contrast ink so the bar is readable on EVERY
    // route, independent of whatever renders behind it.
    //   bg  = primary @6% composited over white  → opaque pale blue
    //   fg  = brandBlueDeep (0xFF002A80) on pale blue ≈ 11:1 (AA/AAA)
    final barBackground =
        context.colors.switcherBarBackground; // opaque pale blue
    final barBorder = context.colors.switcherBarBorder;
    final barForeground = context.colors.brandBlueDeep;
    final barInk = context.colors.brandInk;

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
      } else if (authUser.email.contains('@') &&
          !authUser.email.endsWith('@offline.local')) {
        accountName = authUser.email.split('@').first;
      }
    }
    // TUT-05: in a TUTOR session the active profile is the talmid's synthetic
    // local MIRROR, which lives outside the signed-in account's own profile set
    // — so it is NEVER in `profileListStreamProvider` (own profiles only) and
    // the `activeProfile` lookup above resolves to null, leaking the TUTOR's own
    // account name into the header. Resolve the name through `activeProfileProvider`
    // instead (it loads by id via the repository, so it finds the mirror) so the
    // header shows whose data the tutor is managing — the talmid — keeping the
    // TUTOR badge below. Non-tutored sessions keep the own-profile resolution.
    final isTutoredContext =
        ref.watch(activeTutoredProfileSelectionProvider) != null;
    final tutoredProfileName = isTutoredContext
        ? ref.watch(activeProfileProvider).asData?.value?.displayName
        : null;
    final displayName =
        tutoredProfileName ??
        activeProfile?.displayName ??
        accountName ??
        l10n.userFallbackDisplayName;
    final trimmed = displayName.trim();

    // Bug A: the role badge must distinguish the profile MODE — a child learner
    // must NOT read identically to an adult. Per product Rule 3 the role label
    // is the Learner/Adult/Tutor switcher: derive it from the active profile's
    // mode, and surface TUTOR when a tutored-child selection is active (the
    // signed-in adult is sitting in a talmid's context). Falls back to the adult
    // badge while the profile stream is still resolving (account-only identity).
    //
    // AN-3 fix: when the parent has elevated via PIN for this child profile,
    // the badge must show PARENT MODE rather than CHILD MODE — the parent is
    // managing the child, not acting as the child. This propagates the correct
    // context onto every pushed parent-management sub-route rendered by
    // PersistentSwitcherScaffold (ManageTutors, ParentSettings, etc.).
    final parentAuthedId = ref.watch(parentPinAuthenticatedProfileIdProvider);
    final isParentElevated =
        parentAuthedId != null && parentAuthedId == activeProfileId;
    final String roleBadge;
    if (isTutoredContext) {
      roleBadge = l10n.tutorContextBadge;
    } else if (activeProfile?.profileMode == ProfileMode.child &&
        isParentElevated) {
      roleBadge = l10n.profileBadgeParentMode;
    } else if (activeProfile?.profileMode == ProfileMode.child) {
      roleBadge = l10n.profileBadgeChildMode;
    } else {
      roleBadge = l10n.profileBadgeAdultMode;
    }
    final initial = trimmed.isEmpty
        ? 'U'
        : trimmed.substring(0, 1).toUpperCase();

    // Tap-target overlap fix: the switcher bar is 44 px tall and spans the
    // full screen width. On pushed sub-routes (via PersistentSwitcherScaffold)
    // the sub-route's AppBar back-arrow sits immediately below this bar on the
    // LEFT edge of the screen. A full-width InkWell therefore covers the same
    // horizontal zone as the leading back-arrow, so near-miss taps intended for
    // the back button accidentally fire the switcher instead.
    //
    // Fix: keep the full-width decorative Container (background + border), but
    // restrict the InkWell's hit region so it starts after the standard leading
    // zone (kMinInteractiveDimension = 48 dp). The dead zone on the left is
    // never accidentally tappable as the switcher; the chip itself (avatar, name,
    // badge, unfold icon) remains fully tappable because it sits to the right.
    //
    // Note: kMinInteractiveDimension (48 dp) equals the Material minimum touch
    // target and matches the width of a standard AppBar leading IconButton, so
    // this inset is enough to clear the back arrow on any standard sub-route.
    return Material(
      type: MaterialType.transparency,
      // The background renders full-width so the bar still fills the header
      // visually. Only the InkWell (and therefore the tap-target) is inset
      // from the start edge.
      //
      // AUD-app-01: no literal `height:` on this box — the chip below is
      // floored at kMinInteractiveDimension via ConstrainedBox, so this box
      // (which carries only a decoration, hence DecoratedBox not Container —
      // use_decorated_box) sizes to that content instead of a fixed 44dp that
      // could clip scaled text.
      child: DecoratedBox(
        key: const Key('appShellProfileSwitcherBarBackground'),
        decoration: BoxDecoration(
          color: barBackground,
          border: Border(bottom: BorderSide(color: barBorder)),
        ),
        child: Row(
          children: [
            // Dead zone: covers the leading-button width so taps over the
            // back-arrow area (left kMinInteractiveDimension px) are NOT
            // captured by the switcher InkWell.
            const SizedBox(width: kMinInteractiveDimension),
            // The actual tappable chip — all content to the right of the
            // leading zone. The InkWell shrinks to the chip's intrinsic width
            // via the Expanded wrapper, keeping the hit-target off the left
            // leading edge.
            Expanded(
              child: InkWell(
                key: const Key('appShellProfileSwitcherBar'),
                // The switcher sheet is a modal bottom sheet, which needs a
                // Navigator ancestor of the context it's opened from. On the
                // four shell tabs this bar renders inside AutoTabsScaffold's
                // appBar — below the router's Navigator — so the local
                // `context` works. But the SAME bar is also rendered by
                // PersistentSwitcherScaffold in the MaterialApp.router builder
                // slot, which sits ABOVE the router's Navigator; there the
                // local `context` has no Navigator ancestor and
                // showModalBottomSheet would throw (swallowed → tap does
                // nothing). Routing through the root navigator's context —
                // which always sits at the router's Navigator — makes the tap
                // open the sheet identically on tabs AND every pushed
                // sub-route. Fall back to the local context if the key isn't
                // mounted.
                onTap: () => showProfileSwitcherSheet(
                  navigatorKey.currentContext ?? context,
                ),
                // AUD-app-01: floors the whole chip's tappable height at
                // kMinInteractiveDimension (48dp) — independent of a fixed
                // bar `height:` — so the switcher's tap target always meets
                // the Material minimum, and grows further at large
                // accessibility text scales instead of clipping the name.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: kMinInteractiveDimension,
                  ),
                  child: Padding(
                    // 14 dp right padding matches the original symmetric(14)
                    // inset; no extra left padding needed here since the dead-
                    // zone SizedBox already clears the leading area.
                    padding: const EdgeInsetsDirectional.only(end: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: barForeground.withValues(alpha: 0.14),
                          ),
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: barForeground,
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
                              color: barInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            roleBadge,
                            style: TextStyle(
                              color: barForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 20,
                          color: barForeground,
                        ),
                      ],
                    ),
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
//
// AUD-app-01: public (was `_ChildViewBanner`) so it can be exercised directly
// by widget tests — the same reason [TutorModeIndicatorBar] and
// [ProfileSwitcherBar] are already public.
class ChildViewBanner extends ConsumerWidget {
  const ChildViewBanner({
    required this.childName,
    required this.profiles,
    required this.onExit,
    super.key,
  });

  final String childName;
  final List<ProfileModel> profiles;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      // AUD-app-01: no literal `height:` — the Exit control below is floored
      // at kMinInteractiveDimension via ConstrainedBox, so this Container
      // (no explicit height) sizes to that content instead of a fixed 28dp
      // that could clip scaled text or undersize the Exit tap target.
      color: context.colors.childViewAccent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.child_care_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => showProfileSwitcherSheet(context),
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
          ),
          // Explicit, labelled "Exit parent mode" button — returns the parent
          // to their own (adult) profile via [onExit].
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const Key('childViewBannerExit'),
              onTap: onExit,
              borderRadius: BorderRadius.circular(4),
              // AUD-app-01: floors the Exit control's tappable area at
              // kMinInteractiveDimension (48dp), independent of the compact
              // visual chip inside it — geometrically guarantees the tap
              // target a stressed/motor-impaired user needs, regardless of
              // text scale.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kMinInteractiveDimension,
                  minHeight: kMinInteractiveDimension,
                ),
                child: Center(
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
            ),
          ),
        ],
      ),
    );
  }
}

// W6.15 / T3.readonly-state: Tutor mode indicator bar.
//
// A narrow banner shown below the offline-sync strip when the user has entered
// a tutored profile context. Shows the talmid's name and a one-tap Exit button.
// Tapping Exit clears the active tutored context and navigates back to the
// AppShell (which resolves to the tutor's own profile).
//
// TUT-04: public so the global [PersistentSwitcherScaffold] can render the SAME
// amber tutor bar above pushed sub-routes (e.g. Manage Tracks), where the
// shell's own appBar no longer applies — keeping the "Tutor mode" banner present
// for the whole tutor session, not just on the four tab views.
class TutorModeIndicatorBar extends ConsumerWidget {
  const TutorModeIndicatorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Bug 11: name the talmid being managed in the banner itself — not just a
    // bare "Tutor mode". The active profile in a tutored session resolves to the
    // talmid's synthetic mirror, so its displayName is the child's name. While
    // the mirror is still resolving (name null/empty), fall back to the bare
    // "Tutor mode" label so the banner is never blank.
    final talmidName = ref
        .watch(activeProfileProvider)
        .asData
        ?.value
        ?.displayName
        .trim();
    final label = (talmidName != null && talmidName.isNotEmpty)
        ? l10n.tutorModeIndicatorNamed(talmidName)
        : l10n.tutorModeIndicator;
    return Container(
      // AUD-app-01: no literal `height:` — the Exit control below is floored
      // at kMinInteractiveDimension via ConstrainedBox, so this Container
      // (no explicit height) sizes to that content instead of a fixed 24dp
      // that could clip scaled text or undersize the Exit tap target.
      color: context.colors.tutorModeAccent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => showProfileSwitcherSheet(context),
              child: Text(
                label,
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
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const Key('tutorModeIndicatorBarExit'),
              onTap: () {
                ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
                context.router.replaceAll([const AppShellRoute()]);
              },
              borderRadius: BorderRadius.circular(4),
              // AUD-app-01: floors the Exit control's tappable area at
              // kMinInteractiveDimension (48dp), independent of the compact
              // visual chip inside it — geometrically guarantees the tap
              // target a stressed/motor-impaired user needs, regardless of
              // text scale.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kMinInteractiveDimension,
                  minHeight: kMinInteractiveDimension,
                ),
                child: Center(
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
            ),
          ),
        ],
      ),
    );
  }
}
