import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/widgets/device_notification_toggle.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // AUD-notifications-02: the preference providers are AsyncNotifiers that
    // genuinely await SharedPreferences before resolving (no hardcoded
    // synchronous default). While the initial load is in flight (AsyncLoading)
    // these fall back to the same defaults the old synchronous build() used
    // to return first — the difference is the underlying provider state
    // itself never lies about being settled.
    final reminderEnabled = ref.watch(reminderEnabledProvider).value ?? true;
    final reminderTime =
        ref.watch(reminderTimeProvider).value ??
        const TimeOfDay(
          hour: defaultReminderHour,
          minute: defaultReminderMinute,
        );
    final streakAlertEnabled =
        ref.watch(streakAlertEnabledProvider).value ?? true;
    final streakAlertTime =
        ref.watch(streakAlertTimeProvider).value ??
        const TimeOfDay(
          hour: defaultStreakAlertHour,
          minute: defaultStreakAlertMinute,
        );
    final rewardEnabled =
        ref.watch(rewardNotificationEnabledProvider).value ?? true;

    // Activate sync effects so scheduling reacts to setting changes.
    ref.watch(reminderSyncEffectProvider);
    ref.watch(streakAlertSyncEffectProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceF3,
      appBar: AppBar(
        backgroundColor: context.colors.surfaceF3,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          l10n.notifAppBarNotifications,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Layer 1: device-level OS toggle (WS5.two-layers / DEC-27).
          // Controls whether the OS delivers any notifications from this app.
          // Distinct from per-profile reminder schedules (layer 2 below).
          const DeviceNotificationToggle(),
          const SizedBox(height: 16),
          _SettingsGroupCard(
            children: [
              _NotificationSwitchRow(
                key: const Key('reminder_toggle'),
                icon: Icons.event_note_outlined,
                iconTint: context.colors.notifReminderIconTint,
                iconBg: context.colors.notifReminderIconBg,
                title: l10n.notifDailyReminder,
                subtitle: l10n.notifDailyReminderSubtitle,
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
                title: l10n.notifReminderTime,
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
              // ST-2 fix: hide the HOT STREAK badge when the toggle is OFF so
              // it does not falsely imply an active streak alert.
              _NotificationSwitchRow(
                key: const Key('streak_alert_toggle'),
                icon: Icons.local_fire_department_rounded,
                iconTint: context.colors.notifStreakIconTint,
                iconBg: context.colors.notifStreakIconBg,
                title: l10n.notifStreakAlert,
                subtitle: l10n.notifStreakAlertSubtitle,
                value: streakAlertEnabled,
                trailingTopBadge: streakAlertEnabled
                    ? _TopBadge(text: l10n.notifHotStreakBadge)
                    : null,
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
                title: l10n.notifStreakAlertTime,
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
                iconTint: context.colors.notifRewardIconTint,
                iconBg: context.colors.notifRewardIconBg,
                title: l10n.notifRewardMilestones,
                subtitle: l10n.notifRewardMilestonesSubtitle,
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
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: context.colors.notifCardShadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
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
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: context.colors.notifTitleText,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.notifSubtitleText,
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
              // ST-3 fix: wrap Switch in a Semantics node whose label matches
              // the row title so that screen readers announce the toggle by
              // name (e.g. "Daily Reminder, Switch, on") rather than as an
              // unlabeled control.
              Semantics(
                label: title,
                child: Switch(
                  value: value,
                  activeThumbColor: Colors.white,
                  activeTrackColor: context.colors.blueMid,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: context.colors.surfaceE9,
                  onChanged: onChanged,
                ),
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
    final textColor = enabled
        ? context.colors.notifTimeTextEnabled
        : context.colors.notifTimeTextDisabled;
    return ListTile(
      key: key,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, size: 18, color: context.colors.blueLight),
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
          // chevron_right_rounded sets IconData.matchTextDirection: true, so
          // the Icon widget auto-mirrors it to point left under RTL. A manual
          // rtl→chevron_left_rounded swap double-flips (that glyph also
          // auto-mirrors), pointing it right again in RTL — the R8 RTL defect.
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
        color: context.colors.notifHotStreakBadge,
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
