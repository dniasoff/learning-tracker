import 'package:learning_tracker/core/logging/logger.dart';
import 'package:talker/talker.dart';

/// Initialises [AppLogger] and returns the underlying [Talker] instance.
///
/// The [Talker] is needed to wire the [TalkerRiverpodObserver] into the
/// [ProviderContainer] in [account_bootstrap.dart].
Talker bootstrapLogger() {
  return AppLogger.init();
}
