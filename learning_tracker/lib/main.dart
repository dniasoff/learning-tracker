import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/locale_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/theme_provider.dart';
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
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } on FirebaseException catch (_) {
        // Already initialized (e.g. hot restart) — use existing app.
      } catch (_) {
        // Firebase init failed (no network, no Play Services, etc.)
        // App continues in local-first mode — sync features unavailable.
      }

      // GoogleSignIn.initialize() is NOT called here.
      // google_sign_in v7 requires initialize() before authenticate(),
      // but calling it at startup with NO try/catch crashed offline devices.
      // It's now called lazily in AuthRepositoryImpl.signInWithGoogle()
      // right before the first authentication attempt.

      final talker = AppLogger.init();
      AppLogger.setupFlutterErrorHandlers();
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

class LearningTrackerApp extends ConsumerWidget {
  const LearningTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return SyncLifecycleObserver(
      child: MaterialApp.router(
        title: 'Torah Learning Tracker',
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter.config(),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
