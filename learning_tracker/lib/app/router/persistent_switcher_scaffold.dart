import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_shell.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// Global persistent profile/role switcher layer.
///
/// Product rule (feedback_profile_switcher_top): the tappable role label MUST
/// sit at the TOP of EVERY context, opening the profile + mode switcher — not
/// only on the four shell tabs (Dashboard / Learn / Progress / Settings) but on
/// EVERY pushed sub-route (ManageTracks, Notifications, Siyumim, LifetimeMarking,
/// TutorPinGate, AccountPicker, …).
///
/// The shell ([AppShellScreen]) renders the switcher bar itself for its tab
/// views via its `appBarBuilder`. Sub-routes, however, are TOP-LEVEL siblings of
/// the shell on the root navigator (see `AppRouter.routes`) — when pushed they
/// replace the shell entirely and bring their own `Scaffold`/`AppBar`, so the
/// shell's bar disappears.
///
/// This widget is mounted in the `MaterialApp.router` builder slot so it wraps
/// the entire router output. It renders the SAME [ProfileSwitcherBar] as a
/// persistent header above the active route — but ONLY when a pushed sub-route
/// is on top (so it never double-renders over the shell's own bar) and only when
/// the user is authenticated (so unauthenticated routes — intro / sign-in /
/// onboarding — stay clean).
class PersistentSwitcherScaffold extends ConsumerStatefulWidget {
  const PersistentSwitcherScaffold({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PersistentSwitcherScaffold> createState() =>
      _PersistentSwitcherScaffoldState();
}

class _PersistentSwitcherScaffoldState
    extends ConsumerState<PersistentSwitcherScaffold> {
  late final RouterDelegate<Object> _delegate;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the visible top route whenever navigation changes so the
    // header appears/disappears as the user pushes/pops sub-routes.
    _delegate = ref.read(routerProvider).delegate();
    _delegate.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _delegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  /// True when the visible top-most route is the app shell itself (one of the
  /// four tab views), which already renders its own switcher bar. The bar is the
  /// shell's responsibility there; this overlay must NOT add a second one.
  bool _shellIsOnTop() {
    final router = ref.read(routerProvider);
    // `currentPath` is the full path of the active route stack. The shell lives
    // at the root path `/...` with tab children (dashboard/learn/progress/
    // settings); any pushed sub-route has its own top-level path (e.g.
    // `/notifications`, `/settings/tracks`, `/journey`). The shell is on top
    // when the current top route's name is the AppShell route or one of its
    // direct tab children.
    final topName = router.topRoute.name;
    const shellRouteNames = {
      'AppShellRoute',
      'DashboardRoute',
      'LearningRoute',
      'ProgressRoute',
      'SettingsRoute',
    };
    return shellRouteNames.contains(topName);
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      authStateProvider.select((s) => s.currentUser != null),
    );

    // Only overlay the bar on pushed sub-routes, and only once signed in. The
    // shell owns the bar on its tab views; unauthenticated routes show nothing.
    final showHeader = isAuthenticated && !_shellIsOnTop();
    if (!showHeader) return widget.child;

    // TUT-04: when a tutor has entered a talmid's context, the amber "Tutor
    // mode" banner must persist across the WHOLE session — including pushed
    // sub-routes (Manage Tracks, etc.) where the shell's own appBar no longer
    // applies. Render the SAME TutorModeIndicatorBar the shell shows, above the
    // identity switcher bar, so the tutor context is never lost on a sub-screen.
    final isTutoredSession =
        ref.watch(activeTutoredProfileSelectionProvider) != null;

    final mediaQuery = MediaQuery.of(context);
    final topInset = mediaQuery.padding.top;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          // Inset below the system status bar, matching the shell's appBar.
          Container(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.06),
            padding: EdgeInsets.only(top: topInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTutoredSession) const TutorModeIndicatorBar(),
                const ProfileSwitcherBar(),
              ],
            ),
          ),
          // The persistent bar above has already consumed the system status-bar
          // inset. If we hand the child the unmodified MediaQuery, its own
          // Scaffold/AppBar would re-apply `padding.top` and insert a SECOND
          // status-bar gap directly beneath our bar — a ~status-bar-tall band of
          // AppBar-coloured dead space that makes the faint switcher strip blend
          // into the status-bar zone and read as "not visible / overlaid by the
          // sub-screen's AppBar" (the tester's report). Removing the top padding
          // from the child's MediaQuery makes the sub-route's AppBar sit FLUSH
          // beneath the switcher bar, so the bar is unambiguously the topmost
          // visible, tappable element on every pushed sub-route.
          Expanded(
            child: MediaQuery(
              data: mediaQuery.removePadding(removeTop: true),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
