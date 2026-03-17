import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/sync/presentation/widgets/sync_lifecycle_observer.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final talker = AppLogger.init();
      AppLogger.setupFlutterErrorHandlers();

      talker.info('App starting');

      // Create the shared provider container so pre-runApp initialization
      // and the widget tree use the same state.
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
      final router = container.read(routerProvider);
      final notificationInitializer = NotificationInitializer(
        service: NotificationService(),
        router: router,
      );
      await notificationInitializer.initialize();

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

    return SyncLifecycleObserver(
      child: MaterialApp.router(
        title: 'Torah Learning Tracker',
        theme: AppTheme.lightTheme,
        routerConfig: appRouter.config(),
      ),
    );
  }
}
