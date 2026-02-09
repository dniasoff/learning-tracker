import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker_flutter/talker_flutter.dart';
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

class LearningTrackerApp extends StatelessWidget {
  const LearningTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mishnayos Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _HomeScreen(),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mishnayos Tracker'),
        actions: [
          if (!kReleaseMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug Logs',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        TalkerScreen(talker: AppLogger.instance),
                  ),
                );
              },
            ),
        ],
      ),
      body: const Center(child: Text('Mishnayos Tracker')),
    );
  }
}
