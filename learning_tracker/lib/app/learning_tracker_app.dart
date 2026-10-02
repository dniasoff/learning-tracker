import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/persistent_switcher_scaffold.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/root_scaffold_messenger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/magic_link_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/learner_location_prompt.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_back_button_dispatcher.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Root application widget.
///
/// Owns the router config singleton (prevents GlobalKey instability on
/// rebuild), wraps the MaterialApp in [SyncLifecycleObserver], and applies
/// locale + theme settings.
class LearningTrackerApp extends ConsumerStatefulWidget {
  const LearningTrackerApp({super.key});

  @override
  ConsumerState<LearningTrackerApp> createState() => _LearningTrackerAppState();
}

class _LearningTrackerAppState extends ConsumerState<LearningTrackerApp>
    with WidgetsBindingObserver {
  late final RouterConfig<Object> _routerConfig;

  @override
  void initState() {
    super.initState();
    // Keep a single router config instance for the app lifetime.
    // Re-creating appRouter.config() during rebuilds can trigger
    // duplicate GlobalKey / root-router overlay instability.
    // DNI-481: system back is swallowed while a Sacred Time lock is in
    // force (the lock overlay sits above the router's navigator).
    _routerConfig = withSacredTimeBackBlock(
      ref.read(routerProvider).config(),
      isLocked: () =>
          ref.read(currentSacredWindowProvider) != null ||
          ref.read(currentTutoredSacredWindowProvider) != null,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // The UI language follows the DEVICE language (MaterialApp.locale is null,
    // so Flutter re-resolves the device locale automatically). Invalidate the
    // device-locale provider so background notifications — which read it without
    // a BuildContext — also track a runtime device-language change.
    ref.invalidate(currentAppLocaleProvider);
    super.didChangeLocales(locales);
  }

  /// The after-lock location prompt's action (DNI-481 AC-2): the existing
  /// city picker for the prompt's learner, behind the Parent PIN when one
  /// guards the Sacred Time settings. The city picker edits the ACTIVE
  /// learner, so a prompt for another own learner (a sibling with no
  /// location on a multi-learner account) first makes that learner the
  /// active one — the profile switcher's canonical switch (PIN session
  /// locked, shell reloaded) — so the location lands on the right profile.
  Future<void> _openLearnerLocationPicker(LearnerLocationPrompt prompt) async {
    final router = ref.read(routerProvider);
    final navigatorContext = router.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    if (!await guardSacredTimeSettingsAccess(navigatorContext, ref)) return;
    if (!mounted) return;
    if (ref.read(selectedProfileIdProvider) != prompt.profileId) {
      router.pinGuard.lock();
      ref.read(selectedProfileIdProvider.notifier).select(prompt.profileId);
      await router.replaceAll([const AppShellRoute()]);
      if (!mounted) return;
    }
    await router.push(const CityPickerRoute());
  }

  /// The tutor's exit from a tutored session whose talmid is locked: the
  /// same exit as the tutor-mode bar (back to the tutor's own app shell).
  void _exitTutoredSession() {
    ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    unawaited(ref.read(routerProvider).replaceAll([const AppShellRoute()]));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(magicLinkInitializationProvider);
    // Story 27.14 (DNI-390): activate streak milestone analytics observer.
    ref.watch(streakMilestoneAnalyticsObserverProvider);
    final isChildMode =
        ref.watch(selectedProfileProvider).asData?.value?.mode ==
        ProfileMode.child;

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Torah Learning Tracker',
      theme: AppTheme.themeFor(
        brightness: Brightness.light,
        isChildMode: isChildMode,
      ),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: _routerConfig,
      // The UI language follows the DEVICE language: a null locale lets Flutter
      // resolve the device locale against [supportedLocales] (Hebrew device →
      // he + RTL, otherwise English). There is intentionally no in-app language
      // switcher — language is not user-configurable inside the app.
      locale: null,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Persistent profile/role switcher (feedback_profile_switcher_top):
      // the tappable role label must sit at the TOP of EVERY context. The
      // shell renders it for its tab views; this builder-slot layer renders
      // the SAME bar above every PUSHED sub-route, which would otherwise lose
      // it. Mounted here so it wraps the entire router output and survives all
      // route pushes/pops.
      //
      // DNI-481 (AD-36): the Sacred Time lock overlay wraps EVERYTHING the
      // router renders (tabs, pushed routes, dialogs, the switcher bar), and
      // the after-lock location prompt listens beside it.
      builder: (context, child) => LearnerLocationPromptListener(
        onSetLocation: _openLearnerLocationPicker,
        child: SacredTimeLockOverlay(
          // A locked talmid in a tutored session covers only the talmid's
          // screens and keeps the tutor's exit reachable (AD-36).
          child: TutoredLearnerLockOverlay(
            onExit: _exitTutoredSession,
            child: PersistentSwitcherScaffold(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
