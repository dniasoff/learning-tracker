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
import 'package:talker/talker.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final talker = AppLogger.init();
      AppLogger.setupFlutterErrorHandlers();
      talker.info('App starting — local-first mode');

      // Create the shared provider container — no network deps here.
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

      // Initialize notification system (timezone data + plugin).
      // Non-fatal — app works fine without notifications.
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

      // Launch app immediately — no network calls, no Firebase dependency.
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LearningTrackerApp(),
        ),
      );

      // Background: Initialize Firebase (non-blocking).
      // Firebase is optional — only needed for sync + account features.
      unawaited(_initFirebaseInBackground(talker));
    },
    (Object error, StackTrace stack) {
      AppLogger.instance.handle(error, stack);
    },
  );
}

/// Initialize Firebase in the background after the app is already running.
///
/// This ensures the app is usable instantly. Firebase activation enables
/// SyncEngine and account features but is not required for core functionality.
Future<void> _initFirebaseInBackground(Talker talker) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    talker.info('Firebase initialized (background)');
  } catch (e) {
    // Firebase init failed — sync features unavailable this session.
    // App continues to work fully in local-first mode.
    talker.warning('Firebase init failed (non-fatal): $e');
  }

  // GoogleSignIn.initialize() deferred — only called when user
  // actively chooses Google sign-in from Settings.
  // Previously called at startup with NO try/catch — crashed offline.
}

class LearningTrackerApp extends ConsumerWidget {
  const LearningTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final locale = ref.watch(appLocaleProvider);

    return SyncLifecycleObserver(
      child: MaterialApp.router(
        title: 'Torah Learning Tracker',
        theme: AppTheme.lightTheme(accentColor),
        darkTheme: AppTheme.darkTheme(accentColor),
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
