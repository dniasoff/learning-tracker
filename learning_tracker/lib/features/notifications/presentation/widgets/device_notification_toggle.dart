import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Device-level OS notification toggle (WS5.two-layers / DEC-27).
///
/// Layer 1 of the two-layer notification model: controls whether the OS
/// delivers any notifications from this app at all. This is distinct from
/// per-profile reminder schedules (layer 2).
///
/// Available even on the empty-login surface (before any profile is created),
/// because the OS permission is device-scoped.
///
/// The toggle:
///   • reads the current OS permission state via [NotificationGateway.hasPermission],
///   • calls [NotificationGateway.requestPermission] when the user enables it,
///   • shows a subtle instruction ("Open Settings") when notifications are
///     blocked at the OS level (the OS cannot be un-blocked programmatically
///     once denied — the user must go to Settings).
class DeviceNotificationToggle extends ConsumerStatefulWidget {
  const DeviceNotificationToggle({super.key});

  @override
  ConsumerState<DeviceNotificationToggle> createState() =>
      _DeviceNotificationToggleState();
}

class _DeviceNotificationToggleState
    extends ConsumerState<DeviceNotificationToggle>
    with WidgetsBindingObserver {
  /// Current OS-level permission state. `null` means not yet checked.
  bool? _hasPermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permission when the user returns from Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final gateway = ref.read(notificationServiceProvider);
    final permitted = await gateway.hasPermission();
    if (mounted) {
      setState(() => _hasPermission = permitted);
    }
  }

  Future<void> _onToggleChanged(bool value) async {
    if (!value) {
      // Cannot programmatically disable OS notifications — show a hint.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.deviceNotificationsDisableHint,
            ),
          ),
        );
      }
      return;
    }

    // Request OS permission.
    final gateway = ref.read(notificationServiceProvider);
    final granted = await gateway.requestPermission();
    if (mounted) {
      setState(() => _hasPermission = granted);
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.deviceNotificationsBlockedHint,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permitted = _hasPermission;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      key: const Key('device_notification_toggle'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: Text(
          l10n.deviceNotificationsTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          permitted == null
              ? l10n.deviceNotificationsChecking
              : permitted
              ? l10n.deviceNotificationsAllowed
              : l10n.deviceNotificationsBlocked,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.notifSubtitleText,
          ),
        ),
        value: permitted ?? true,
        onChanged: _onToggleChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: context.colors.notifDeviceToggleActiveTrack,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: context.colors.notifDeviceToggleInactiveTrack,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
