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
import 'package:learning_tracker/features/sacred_time/presentation/providers/legacy_learner_settings_seed_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/learner_location_prompt.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_back_button_dispatcher.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
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
      isLocked: () => ref.read(currentSacredWindowProvider) != null,
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
  /// city picker for the prompt's learner, behind every Parent PIN that
  /// guards it — the device holder's and, for another learner, the
  /// TARGET's own ([guardLearnerLocationPromptAccess]). The city picker
  /// edits the ACTIVE learner, so a prompt for another own learner (a
  /// sibling with no location on a multi-learner account) then makes that
  /// learner the active one — the profile switcher's canonical switch (PIN
  /// session locked, shell reloaded) — and opens the picker straight away.
  Future<void> _openLearnerLocationPicker(LearnerLocationPrompt prompt) {
    final router = ref.read(routerProvider);
    return runLearnerLocationPromptAction(
      prompt,
      selectedProfileId: () => ref.read(selectedProfileIdProvider),
      authorize: (targetProfileId) async {
        final navigatorContext = router.navigatorKey.currentContext;
        if (navigatorContext == null) return false;
        return await guardLearnerLocationPromptAccess(
              navigatorContext,
              ref,
              targetProfileId,
            ) &&
            mounted;
      },
      switchTo: (profileId) async {
        router.pinGuard.lock();
        ref.read(selectedProfileIdProvider.notifier).select(profileId);
        await router.replaceAll([const AppShellRoute()]);
        return mounted;
      },
      openCityPicker: () async {
        if (mounted) await router.push(const CityPickerRoute());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(magicLinkInitializationProvider);
    // Story 27.14 (DNI-390): activate streak milestone analytics observer.
    ref.watch(streakMilestoneAnalyticsObserverProvider);
    // Seeds the learner settings of profiles created before they existed,
    // which otherwise leave the Sacred Time lock stuck fail-closed.
    ref.watch(legacyLearnerSettingsSeedProvider);
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
        // The lock follows the person using the device: in a tutored
        // session it is the tutor's own lock, never the talmid's.
        child: SacredTimeLockOverlay(
          child: PersistentSwitcherScaffold(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
