import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/sync/presentation/widgets/sync_lifecycle_observer.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      final talker = AppLogger.init();
      AppLogger.setupFlutterErrorHandlers();

      talker.info('App starting');

      runApp(
        ProviderScope(
          observers: [
            TalkerRiverpodObserver(
              talker: talker,
              settings: const TalkerRiverpodLoggerSettings(
                printProviderDisposed: true,
              ),
            ),
          ],
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
