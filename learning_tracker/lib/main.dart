import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/bootstrap/account_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/analytics_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/crashlytics_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/firebase_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/notifications_bootstrap.dart';
import 'package:learning_tracker/app/bootstrap/seed_bootstrap.dart';
import 'package:learning_tracker/app/learning_tracker_app.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      var crashlytics = await bootstrapFirebase();
      final talker = AppLogger.init();
      final log = AppLogger(talker);
      final analytics = bootstrapAnalytics(log);
      crashlytics = bootstrapCrashlyticsHandlers(
        crashlytics: crashlytics,
        analytics: analytics,
      );

      log.info(event: 'app_starting_local_first');

      final docsDir = await getApplicationDocumentsDirectory();
      final contentDbPath = await bootstrapSeedDb(
        dbDirectory: docsDir.path,
        log: log,
      );
      await bootstrapAccount(databasesPath: docsDir.path, log: log);

      unawaited(analytics.logAppLaunch());

      final container = ProviderContainer(
        overrides: [
          contentDbPathProvider.overrideWithValue(contentDbPath),
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

      container.listen<int?>(selectedProfileIdProvider, (_, id) {
        crashlytics.setUserIdentifier(id);
      }, fireImmediately: true);

      await bootstrapNotifications(container: container, log: log);

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
