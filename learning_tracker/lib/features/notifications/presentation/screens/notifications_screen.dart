import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F8),
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.notifications, color: Color(0xFF1338A2)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 38,
              height: 0.98,
              fontWeight: FontWeight.w800,
              color: Color(0xFF161D2F),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Keep your Torah journey on track!',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6F7788),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            children: [
              _NotificationSwitchRow(
                key: const Key('reminder_toggle'),
                icon: Icons.event_note_outlined,
                iconTint: const Color(0xFF2A4BB3),
                iconBg: const Color(0xFFE8EBFF),
                title: 'Daily Reminder',
                subtitle: 'Don\'t forget to learn today!',
                value: reminderEnabled,
                onChanged: (willEnable) async {
                  if (willEnable) {
                    final service = ref.read(notificationServiceProvider);
                    await service.requestPermission();
                  }
                  await ref.read(reminderEnabledProvider.notifier).toggle();
                },
              ),
              const Divider(height: 1),
              _SettingsTimeRow(
                key: const Key('reminder_time'),
                icon: Icons.access_time_filled_rounded,
                title: 'Reminder Time',
                timeText: reminderTime.format(context),
                enabled: reminderEnabled,
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
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            children: [
              _NotificationSwitchRow(
                key: const Key('streak_alert_toggle'),
                icon: Icons.local_fire_department_rounded,
                iconTint: const Color(0xFFE35D66),
                iconBg: const Color(0xFFFDECEF),
                title: 'Streak Alert',
                subtitle: 'Keep your fire burning!',
                value: streakAlertEnabled,
                trailingTopBadge: const _TopBadge(text: 'HOT STREAK'),
                onChanged: (willEnable) async {
                  if (willEnable) {
                    final service = ref.read(notificationServiceProvider);
                    await service.requestPermission();
                  }
                  await ref.read(streakAlertEnabledProvider.notifier).toggle();
                },
              ),
              const Divider(height: 1),
              _SettingsTimeRow(
                key: const Key('streak_alert_time'),
                icon: Icons.alarm_rounded,
                title: 'Streak Alert Time',
                timeText: streakAlertTime.format(context),
                enabled: streakAlertEnabled,
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
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            children: [
              _NotificationSwitchRow(
                key: const Key('reward_notification_toggle'),
                icon: Icons.auto_awesome_rounded,
                iconTint: const Color(0xFFB07A2A),
                iconBg: const Color(0xFFFDF2DE),
                title: 'Reward Notifications',
                subtitle: 'When you earn Mitzvah Points!',
                value: rewardEnabled,
                onChanged: (willEnable) async {
                  if (willEnable) {
                    final service = ref.read(notificationServiceProvider);
                    await service.requestPermission();
                  }
                  await ref
                      .read(rewardNotificationEnabledProvider.notifier)
                      .toggle();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SacredTimeCard(
            shabbosEnabled: shabbosEnabled,
            shabbosUseLocation: shabbosUseLocation,
            shabbosStartTime: shabbosStartTime,
            shabbosEndTime: shabbosEndTime,
            onToggleShabbosMode: () async {
              await ref.read(shabbosModeEnabledProvider.notifier).toggle();
            },
            onToggleUseLocation: () async {
              await ref.read(shabbosModeUseLocationProvider.notifier).toggle();
            },
            onEditStartTime: () async {
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
            onEditEndTime: () async {
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
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12061D56),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _NotificationSwitchRow extends StatelessWidget {
  const _NotificationSwitchRow({
    required this.icon,
    required this.iconTint,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
    this.trailingTopBadge,
  });

  final IconData icon;
  final Color iconTint;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailingTopBadge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Icon(icon, color: iconTint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF151B2D),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A8293),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (trailingTopBadge != null) ...[
                trailingTopBadge!,
                const SizedBox(height: 6),
              ],
              Switch(
                value: value,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF123CA5),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE0E4ED),
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTimeRow extends StatelessWidget {
  const _SettingsTimeRow({
    required this.icon,
    required this.title,
    required this.timeText,
    required this.enabled,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String timeText;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? const Color(0xFF1A2340) : const Color(0xFF9CA3B4);
    return ListTile(
      key: key,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, size: 18, color: const Color(0xFF163A9D)),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeText,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: textColor),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6A78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SacredTimeCard extends StatelessWidget {
  const _SacredTimeCard({
    required this.shabbosEnabled,
    required this.shabbosUseLocation,
    required this.shabbosStartTime,
    required this.shabbosEndTime,
    required this.onToggleShabbosMode,
    required this.onToggleUseLocation,
    required this.onEditStartTime,
    required this.onEditEndTime,
  });

  final bool shabbosEnabled;
  final bool shabbosUseLocation;
  final TimeOfDay shabbosStartTime;
  final TimeOfDay shabbosEndTime;
  final VoidCallback onToggleShabbosMode;
  final VoidCallback onToggleUseLocation;
  final VoidCallback onEditStartTime;
  final VoidCallback onEditEndTime;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12061D56),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF11389F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: Colors.white, size: 17),
                SizedBox(width: 8),
                Text(
                  'SACRED TIME',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                _NotificationSwitchRow(
                  key: const Key('shabbos_mode_toggle'),
                  icon: Icons.nightlight_round,
                  iconTint: const Color(0xFF153DA8),
                  iconBg: const Color(0xFFEBEEFF),
                  title: 'Shabbos / Yom Tov\nMode',
                  subtitle: 'Quiet learning during holy days',
                  value: shabbosEnabled,
                  onChanged: (_) => onToggleShabbosMode(),
                ),
                const SizedBox(height: 6),
                Container(height: 1, color: const Color(0xFFE8EAF0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Use Location for Times',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF596175),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Switch(
                      key: const Key('shabbos_use_location_toggle'),
                      value: shabbosUseLocation,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF123CA5),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFE0E4ED),
                      onChanged: shabbosEnabled
                          ? (_) => onToggleUseLocation()
                          : null,
                    ),
                  ],
                ),
                if (shabbosEnabled && !shabbosUseLocation) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _QuietTimeTile(
                          key: const Key('shabbos_start_time'),
                          label: 'QUIET START',
                          time: shabbosStartTime.format(context),
                          hint: 'Candle lighting',
                          onTap: onEditStartTime,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuietTimeTile(
                          key: const Key('shabbos_end_time'),
                          label: 'QUIET END',
                          time: shabbosEndTime.format(context),
                          hint: 'Havdalah',
                          onTap: onEditEndTime,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietTimeTile extends StatelessWidget {
  const _QuietTimeTile({
    required this.label,
    required this.time,
    required this.hint,
    required this.onTap,
    super.key,
  });

  final String label;
  final String time;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A5370),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2340),
                    ),
                  ),
                ),
                const Icon(Icons.edit, size: 16, color: Color(0xFF2141A6)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8E95A7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
