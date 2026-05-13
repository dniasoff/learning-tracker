import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/locale_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/auth/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/auth/presentation/providers/magic_link_providers.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_lock_overlay.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_date_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/transliteration_variant_provider.dart';
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
      talker.info('App starting — local-first mode');

      // Story 19.2b / 19.6: Decompress the bundled seed DB to a writable
      // location BEFORE creating any providers that might query content.
      // SeedManager handles first-launch extraction, version-driven
      // upgrades, .bak rollback, and corruption recovery.
      String resolvedContentDbPath;
      final docsDir = await getApplicationDocumentsDirectory();
      try {
        final seedManager = SeedManager(
          dbDirectory: docsDir.path,
          talker: talker,
        );
        resolvedContentDbPath = await seedManager.ensureContentDb();
        talker.info('Content DB ready at $resolvedContentDbPath');
      } catch (e, stack) {
        talker.error('SeedManager initialization failed', e, stack);
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
            talker.info(
              'Active account resolved: ${account.email} '
              '(${account.tier}, db=${account.dbFileName})',
            );
          }
        } else {
          talker.info('No active account — fresh install or all removed');
        }
        await registry.close();
      } catch (e, stack) {
        talker.error(
          'Session resolution failed (non-fatal, using default DB)',
          e,
          stack,
        );
      }

      // Single prefs read so Hebrew date preference is in sync on first build
      // of [useHebrewDateProvider] (deadline / goal date pickers).
      final appPrefs = await SharedPreferences.getInstance();
      syncHebrewCalendarPreferenceFromPrefs(appPrefs);
      syncHebrewTermsScriptPreferenceFromPrefs(appPrefs);
      syncTransliterationVariantPreferenceFromPrefs(appPrefs);

      final container = ProviderContainer(
        overrides: [
          contentDbPathProvider.overrideWithValue(resolvedContentDbPath),
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
        talker.error('Notification init failed (non-fatal)', e, stack);
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
    final locale = ref.watch(appLocaleProvider);
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
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        routerConfig: _routerConfig,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            SacredTimeLockOverlay(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
