import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/sync_runtime/sync_lifecycle_observer.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
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
        // locale: null — Flutter resolves the active locale automatically
        // from WidgetsBinding.window.locale against supportedLocales (DNI-341).
        locale: null,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => child ?? const SizedBox.shrink(),
      ),
    );
  }
}
