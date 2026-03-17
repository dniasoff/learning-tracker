import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';

@RoutePage()
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderEnabled = ref.watch(reminderEnabledProvider);
    final reminderTime = ref.watch(reminderTimeProvider);
    final streakAlertEnabled = ref.watch(streakAlertEnabledProvider);
    final streakAlertTime = ref.watch(streakAlertTimeProvider);
    final rewardEnabled = ref.watch(rewardNotificationEnabledProvider);
    final shabbosEnabled = ref.watch(shabbosModeEnabledProvider);
    final shabbosUseLocation = ref.watch(shabbosModeUseLocationProvider);
    final shabbosStartTime = ref.watch(shabbosModeFixedStartTimeProvider);
    final shabbosEndTime = ref.watch(shabbosModeFixedEndTimeProvider);

    // Activate sync effects so scheduling reacts to setting changes.
    ref.watch(reminderSyncEffectProvider);
    ref.watch(streakAlertSyncEffectProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Notifications')),
      body: ListView(
        children: [
          // ── Daily Reminder ──────────────────────────────────────
          SwitchListTile(
            key: const Key('reminder_toggle'),
            title: const Text('Daily Reminder'),
            subtitle: const Text(
              'Get reminded about your daily learning tasks',
            ),
            value: reminderEnabled,
            onChanged: (_) async {
              await ref.read(reminderEnabledProvider.notifier).toggle();
              if (!reminderEnabled) {
                final service = ref.read(notificationServiceProvider);
                await service.requestPermission();
              }
            },
          ),
          ListTile(
            key: const Key('reminder_time'),
            title: const Text('Reminder Time'),
            subtitle: Text(reminderTime.format(context)),
            enabled: reminderEnabled,
            trailing: const Icon(Icons.access_time),
            onTap: reminderEnabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: reminderTime,
                    );
                    if (picked != null) {
                      await ref
                          .read(reminderTimeProvider.notifier)
                          .setTime(picked);
                    }
                  }
                : null,
          ),
          const Divider(),

          // ── Streak Alert ────────────────────────────────────────
          SwitchListTile(
            key: const Key('streak_alert_toggle'),
            title: const Text('Streak Alert'),
            subtitle: const Text(
              'Get alerted when your learning streak is at risk',
            ),
            value: streakAlertEnabled,
            onChanged: (_) async {
              await ref.read(streakAlertEnabledProvider.notifier).toggle();
            },
          ),
          ListTile(
            key: const Key('streak_alert_time'),
            title: const Text('Streak Alert Time'),
            subtitle: Text(streakAlertTime.format(context)),
            enabled: streakAlertEnabled,
            trailing: const Icon(Icons.access_time),
            onTap: streakAlertEnabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: streakAlertTime,
                    );
                    if (picked != null) {
                      await ref
                          .read(streakAlertTimeProvider.notifier)
                          .setTime(picked);
                    }
                  }
                : null,
          ),
          const Divider(),

          // ── Reward Notifications ────────────────────────────────
          SwitchListTile(
            key: const Key('reward_notification_toggle'),
            title: const Text('Reward Notifications'),
            subtitle: const Text(
              'Get notified when you earn reward milestones',
            ),
            value: rewardEnabled,
            onChanged: (_) async {
              await ref
                  .read(rewardNotificationEnabledProvider.notifier)
                  .toggle();
            },
          ),
          const Divider(),

          // ── Shabbos / Yom Tov Quiet Mode ────────────────────────
          SwitchListTile(
            key: const Key('shabbos_mode_toggle'),
            title: const Text('Shabbos / Yom Tov Mode'),
            subtitle: const Text(
              'Suppress all notifications during Shabbos and Yom Tov',
            ),
            value: shabbosEnabled,
            onChanged: (_) async {
              await ref.read(shabbosModeEnabledProvider.notifier).toggle();
            },
          ),
          if (shabbosEnabled) ...[
            SwitchListTile(
              key: const Key('shabbos_use_location_toggle'),
              title: const Text('Use Location for Times'),
              subtitle: const Text(
                'Calculate candle lighting and havdalah from your location',
              ),
              value: shabbosUseLocation,
              onChanged: (_) async {
                await ref
                    .read(shabbosModeUseLocationProvider.notifier)
                    .toggle();
              },
            ),
            if (!shabbosUseLocation) ...[
              ListTile(
                key: const Key('shabbos_start_time'),
                title: const Text('Quiet Start (Candle Lighting)'),
                subtitle: Text(shabbosStartTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: shabbosStartTime,
                  );
                  if (picked != null) {
                    await ref
                        .read(shabbosModeFixedStartTimeProvider.notifier)
                        .setTime(picked);
                  }
                },
              ),
              ListTile(
                key: const Key('shabbos_end_time'),
                title: const Text('Quiet End (Havdalah)'),
                subtitle: Text(shabbosEndTime.format(context)),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: shabbosEndTime,
                  );
                  if (picked != null) {
                    await ref
                        .read(shabbosModeFixedEndTimeProvider.notifier)
                        .setTime(picked);
                  }
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
