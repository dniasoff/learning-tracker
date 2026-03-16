import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';

@RoutePage()
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(reminderEnabledProvider);
    final time = ref.watch(reminderTimeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('reminder_toggle'),
            title: const Text('Daily Reminder'),
            subtitle: const Text(
              'Get reminded about your daily learning tasks',
            ),
            value: enabled,
            onChanged: (_) async {
              await ref.read(reminderEnabledProvider.notifier).toggle();
              if (!enabled) {
                // Was disabled, now enabling → request permission
                final service = ref.read(notificationServiceProvider);
                await service.requestPermission();
              }
            },
          ),
          ListTile(
            key: const Key('reminder_time'),
            title: const Text('Reminder Time'),
            subtitle: Text(time.format(context)),
            enabled: enabled,
            trailing: const Icon(Icons.access_time),
            onTap: enabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked != null) {
                      await ref
                          .read(reminderTimeProvider.notifier)
                          .setTime(picked);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
