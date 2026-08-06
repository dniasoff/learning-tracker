import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Initialises the notification system from the provider [container].
///
/// Non-fatal — notification failures must never prevent app startup.
/// Uses the provider-owned [NotificationGateway] instance so the plugin
/// initialized here is the same one used for scheduling later.
///
/// (WS5.per-profile) Wires the [ProfileSwitchCallback] into the initializer
/// so that tapping a per-profile notification switches the active profile
/// before navigating to the Scheduler.
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
      // WS5.per-profile: tap handler switches into the tapped profile before
      // opening the Scheduler so the user lands in the right profile.
      //
      // P2-2: resolves the tapped profile's Firestore ULID before
      // selecting. `select` used to be called bare here, which cleared
      // `activeProfileDocIdProvider` to null on every notification tap —
      // blanking every profile-scoped Firestore provider (`ProfileSwitchCallback`
      // stays `void Function(int)`, so this closure runs fire-and-forget;
      // that is fine here — unlike a route guard's `resolver.next()`,
      // nothing downstream is synchronously waiting on this selection).
      onSwitchProfile: (profileId) async {
        final model = await container
            .read(profileRepositoryProvider)
            .getProfileById(profileId);
        container
            .read(selectedProfileIdProvider.notifier)
            .select(profileId, ulid: model?.ulid);
      },
    );
    await notificationInitializer.initialize();
    // Kick off sync effects so scheduled notifications reflect current
    // preferences immediately on launch — not only when the user opens the
    // notifications screen.
    container.read(notificationSettingsCloudSyncEffectProvider);
    container.read(reminderSyncEffectProvider);
    container.read(streakAlertSyncEffectProvider);
    // WS5.per-profile (DEC-28): schedule reminders for ALL profiles, not just
    // the currently-active one, so inactive profiles' reminders fire on schedule.
    container.read(allProfilesReminderBootstrapProvider);
  } catch (e, stack) {
    log.error(
      event: 'notification_init_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}
