import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/locale_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/theme_provider.dart';
import 'package:learning_tracker/features/sync/presentation/widgets/sync_lifecycle_observer.dart';
import 'package:learning_tracker/firebase_options.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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

      final container = ProviderContainer(
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
      try {
        final router = container.read(routerProvider);
        final notificationInitializer = NotificationInitializer(
          service: NotificationService(),
          router: router,
        );
        await notificationInitializer.initialize();
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
