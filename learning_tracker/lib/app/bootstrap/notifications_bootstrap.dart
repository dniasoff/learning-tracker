import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';

/// Initialises the notification system from the provider [container].
///
/// Non-fatal — notification failures must never prevent app startup.
/// Uses the provider-owned [NotificationGateway] instance so the plugin
/// initialized here is the same one used for scheduling later.
Future<void> bootstrapNotifications({
  required ProviderContainer container,
  required AppLogger log,
}) async {
  try {
    final router = container.read(routerProvider);
    final notificationService = container.read(notificationServiceProvider);
    final notificationInitializer = NotificationInitializer(
      service: notificationService,
      router: router,
    );
    await notificationInitializer.initialize();
    // Kick off sync effects so scheduled notifications reflect current
    // preferences immediately on launch — not only when the user opens the
    // notifications screen.
    container.read(notificationSettingsCloudSyncEffectProvider);
    container.read(reminderSyncEffectProvider);
    container.read(streakAlertSyncEffectProvider);
  } catch (e, stack) {
    log.error(
      event: 'notification_init_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}
