import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/persistent_switcher_scaffold.dart';
import 'package:learning_tracker/app/sync_runtime/sync_lifecycle_observer.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/presentation/providers/magic_link_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
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

class _LearningTrackerAppState extends ConsumerState<LearningTrackerApp> {
  late final RouterConfig<Object> _routerConfig;

  @override
  void initState() {
    super.initState();
    // Keep a single router config instance for the app lifetime.
    // Re-creating appRouter.config() during rebuilds can trigger
    // duplicate GlobalKey / root-router overlay instability.
    _routerConfig = ref.read(routerProvider).config();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(magicLinkInitializationProvider);
    // Story 27.14 (DNI-390): activate streak milestone analytics observer.
    ref.watch(streakMilestoneAnalyticsObserverProvider);
    final isChildMode =
        ref.watch(selectedProfileProvider).asData?.value?.profileMode ==
        ProfileMode.child;
    // IL-6 fix: wire the per-profile app_locale_pN pref into MaterialApp.locale
    // so a profile set to Hebrew ('he') gets the Hebrew UI regardless of the
    // OS device locale.  Previously this was `locale: null` (DNI-341 comment)
    // which meant the device locale always won and the in-app switcher was inert.
    final appLocale = ref.watch(currentAppLocaleProvider);

    return SyncLifecycleObserver(
      child: MaterialApp.router(
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
        locale: appLocale,
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
        builder: (context, child) =>
            PersistentSwitcherScaffold(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
