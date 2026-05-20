import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/bootstrap/bootstrap.dart';
import 'package:learning_tracker/app/learning_tracker_app.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/logging/logger.dart';

// W7.14: held in a top-level variable so the runZonedGuarded error handler
// (which runs outside the async body) can forward to Crashlytics.
CrashlyticsService _crashlytics = const NullCrashlyticsService();

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final (:container, :crashlytics) = await bootstrap();
      // Publish to module-level so the zone error handler can use it.
      _crashlytics = crashlytics;
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LearningTrackerApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      // W7.14 — route unhandled zone errors to both Crashlytics (fatal) and
      // the Talker structured log (in-app diagnostics).
      _crashlytics.recordError(error, stack, fatal: true);
      AppLogger.instance.handle(error, stack);
    },
  );
}
