import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/magic_link_providers.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/presentation/widgets/sync_lifecycle_observer.dart';
import 'package:learning_tracker/firebase_options.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Firebase BEFORE providers — but non-fatal if it fails.
      // Firebase providers (firebaseAuthProvider, firebaseFirestoreProvider)
      // need Firebase.initializeApp() to have completed.
      //
      // Story 27.14 (DNI-390): Analytics service is created early (using
      // AppLogger) so it can be shared with CrashlyticsService for the
      // `crash_reported` event, and overridden into the provider container.
      // AppLogger is initialized below; create a lazy-init holder so the
      // analytics instance can be created after AppLogger.init().

      CrashlyticsService crashlytics = const NullCrashlyticsService();
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        // Story 24.4: Wire Crashlytics immediately after Firebase init,
        // before any other init that can throw.
        final fbCrashlytics = FirebaseCrashlytics.instance;
        await fbCrashlytics.setCrashlyticsCollectionEnabled(true);
        crashlytics = FirebaseCrashlyticsService(fbCrashlytics);
      } on FirebaseException catch (_) {
        // Already initialized (e.g. hot restart) — use existing app.
        // Crashlytics may already be wired; re-wrap the singleton.
        crashlytics = FirebaseCrashlyticsService(FirebaseCrashlytics.instance);
      } catch (_) {
        // Firebase init failed (no network, no Play Services, etc.)
        // App continues in local-first mode — sync features unavailable.
        // Crashlytics stays as NullCrashlyticsService to avoid re-crashing.
      }

      // Story 24.4: Override Flutter and Dart error hooks to report to
      // Crashlytics as the primary handler. Talker remains a secondary
      // handler for in-app diagnostics (ring-buffer / "Send Logs" feature).
      FlutterError.onError = (FlutterErrorDetails details) {
        crashlytics.recordFlutterFatalError(details);
        AppLogger.instance.handle(details.exception, details.stack);
      };
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        crashlytics.recordError(error, stack, fatal: true);
        AppLogger.instance.handle(error, stack);
        return true;
      };

      // GoogleSignIn.initialize() is NOT called here.
      // google_sign_in v7 requires initialize() before authenticate(),
      // but calling it at startup with NO try/catch crashed offline devices.
      // It's now called lazily in AuthRepositoryImpl.signInWithGoogle()
      // right before the first authentication attempt.

      final talker = AppLogger.init();
      final log = AppLogger(talker);

      // Story 27.14 (DNI-390): create the analytics service now that AppLogger
      // is available. The same instance is wired into CrashlyticsService and
      // overridden into the provider container so all layers share one service.
      final AnalyticsService analytics = LoggingAnalyticsService(log);

      // Re-wrap CrashlyticsService with analytics once AppLogger is ready.
      // If Firebase init succeeded, upgrade to report analytics events on
      // recordError (crash_reported event, Story 27.14).
      if (crashlytics is FirebaseCrashlyticsService) {
        crashlytics = AnalyticsWrappedCrashlyticsService(
          FirebaseCrashlytics.instance,
          analytics: analytics,
        );
      }

      log.info(event: 'app_starting_local_first');

      // Story 19.2b / 19.6: Decompress the bundled seed DB to a writable
      // location BEFORE creating any providers that might query content.
      // SeedManager handles first-launch extraction, version-driven
      // upgrades, .bak rollback, and corruption recovery.
      String resolvedContentDbPath;
      final docsDir = await getApplicationDocumentsDirectory();
      try {
        final seedManager = SeedManager(dbDirectory: docsDir.path, logger: log);
        resolvedContentDbPath = await seedManager.ensureContentDb();
        log.info(
          event: 'content_db_ready',
          fields: {'path': resolvedContentDbPath},
        );
      } catch (e, stack) {
        log.error(
          event: 'seed_manager_init_failed',
          exception: e,
          stackTrace: stack,
        );
        rethrow;
      }

      // Epic 21: Resolve the active account's DB file name BEFORE
      // building the provider tree. The userDatabaseProvider reads
      // `activeDbFileName` synchronously, so it must be set here.
      try {
        final prefs = await SharedPreferences.getInstance();
        await PendingLocalSignupStore.cleanupStaleOnStartup(
          prefs: prefs,
          databasesPath: docsDir.path,
        );
        final registry = DeviceRegistryDatabase(
          driftDatabase(name: 'device_registry'),
        );
        final sessionService = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );
        final accountId = await sessionService.resolveActiveAccountId();
        if (accountId != null) {
          final account = await registry.findById(accountId);
          if (account != null) {
            activeDbFileName = account.dbFileName;
            log.info(
              event: 'active_account_resolved',
              fields: {
                // email is in PiiRedactor.sensitiveKeys → redacted automatically
                'email': account.email,
                'tier': account.tier,
                'db': account.dbFileName,
              },
            );
          }
        } else {
          log.info(event: 'active_account_none');
        }
        await registry.close();
      } catch (e, stack) {
        log.error(
          event: 'active_account_resolution_failed',
          exception: e,
          stackTrace: stack,
        );
      }

      // Per-profile preferences are now loaded lazily by the
      // `core/preferences/` Riverpod providers on first watch — no preload
      // is required because `MaterialApp.locale` and the Hebrew-terms
      // toggle both default to safe values until SharedPreferences resolves.

      // Story 27.14 (DNI-390): fire app_launch analytics event.
      unawaited(analytics.logAppLaunch());

      final container = ProviderContainer(
        overrides: [
          contentDbPathProvider.overrideWithValue(resolvedContentDbPath),
          // Story 27.14 (DNI-390): inject the same analytics instance created
          // above so all providers share one service (same AppLogger backing).
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
        observers: [
          TalkerRiverpodObserver(
            talker: talker,
            settings: const TalkerRiverpodLoggerSettings(
              printProviderDisposed: true,
            ),
          ),
        ],
      );

      // Story 24.4: Forward profileId to Crashlytics whenever a profile is
      // selected or cleared. Only the numeric ID is sent — no email or PII.
      // Single observer — no scattered setUserIdentifier call sites (Story 27.14).
      container.listen<int?>(selectedProfileIdProvider, (_, id) {
        crashlytics.setUserIdentifier(id);
      }, fireImmediately: true);

      // Initialize notification system (non-fatal).
      // IMPORTANT: use the provider-owned NotificationService instance so the
      // plugin initialized here is the same one used for scheduling later.
      try {
        final router = container.read(routerProvider);
        final notificationService = container.read(notificationServiceProvider);
        final notificationInitializer = NotificationInitializer(
          service: notificationService,
          router: router,
        );
        await notificationInitializer.initialize();
        // Kick off the sync effects so scheduled notifications reflect current
        // preferences immediately on launch — not only when the user opens the
        // notifications screen.
        container.read(notificationSettingsCloudSyncEffectProvider);
        container.read(reminderSyncEffectProvider);
        container.read(streakAlertSyncEffectProvider);
      } catch (e, stack) {
        log.error(
          event: 'notification_init_failed',
          exception: e,
          stackTrace: stack,
        );
      }

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LearningTrackerApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      AppLogger.instance.handle(error, stack);
    },
  );
}

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
    final appRouter = ref.read(routerProvider);
    _routerConfig = appRouter.config();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(magicLinkInitializationProvider);
    // Story 27.14 (DNI-390): activate streak milestone analytics observer.
    ref.watch(streakMilestoneAnalyticsObserverProvider);
    final isChildMode =
        ref.watch(selectedProfileProvider).asData?.value?.mode == 'child';

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
