import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/notifications/data/parent_push_receiver.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_initializer.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/catch_up_reminder_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

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
      // AD-24: profileId is already the Firestore ULID (both the payload and
      // `selectedProfileIdProvider.notifier.select` use it directly, no
      // separate int/ulid split). `ProfileSwitchCallback` runs
      // fire-and-forget; that is fine here — unlike a route guard's
      // `resolver.next()`, nothing downstream is synchronously waiting on
      // this selection.
      onSwitchProfile: (profileId) async {
        final profile = await container
            .read(profileRepositoryProvider)
            .getProfileById(profileId);
        // The profile may have been deleted between the notification being
        // scheduled and tapped. No profile to switch to means nothing to
        // select — leave the current selection untouched rather than
        // switching into an id with no data.
        if (profile == null) return;
        container.read(selectedProfileIdProvider.notifier).select(profileId);
      },
      // DNI-515: a tapped tutor-change push is queued for the app shell,
      // which opens the learner's Change history behind its usual guards.
      onParentPushTap: (tap) =>
          container.read(pendingParentPushTapProvider.notifier).set(tap),

      // Story 3.5 (DNI-508, AC-9): a catch-up reminder opens its own
      // profile's Learn tab through the same profile selection (the PIN
      // guards apply on the way in). Never on a tutored session — a tutor
      // is never routed to a child's catch-up card — and never for a
      // profile that is gone.
      onCatchUpTap: (profileId) async {
        if (container.read(activeTutoredProfileSelectionProvider) != null) {
          return false;
        }
        final profile = await container
            .read(profileRepositoryProvider)
            .getProfileById(profileId);
        if (profile == null) return false;
        container.read(selectedProfileIdProvider.notifier).select(profileId);
        return true;
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
    // Story 3.5 (DNI-508): the ONE catch-up reminder scheduler, owner
    // devices only (it gates tutored sessions itself, AC-5); re-runs on
    // resume and on every learnerSettings change.
    container.read(catchUpReminderSyncEffectProvider);
  } catch (e, stack) {
    log.error(
      event: 'notification_init_failed',
      exception: e,
      stackTrace: stack,
    );
  }
}
