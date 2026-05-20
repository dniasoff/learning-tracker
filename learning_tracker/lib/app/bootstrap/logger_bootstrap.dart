import 'package:learning_tracker/core/logging/logger.dart';

/// Initialises the singleton [AppLogger] / Talker instance.
///
/// After calling this, use [AppLogger.instance] (for the static helper) or
/// `AppLogger.init()` directly in callers that need the underlying Talker
/// for wiring observers (e.g. [TalkerRiverpodObserver] in main.dart).
void bootstrapLogger() {
  AppLogger.init();
}
