import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';

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
          const SnackBar(
            content: Text(
              'To disable notifications, go to Settings > Apps > Learning Tracker.',
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
          const SnackBar(
            content: Text(
              'Notifications blocked. Enable them in Settings > Apps > '
              'Learning Tracker > Notifications.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permitted = _hasPermission;

    return Card(
      key: const Key('device_notification_toggle'),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: const Text(
          'Device notifications',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          permitted == null
              ? 'Checking permission…'
              : permitted
              ? 'Notifications allowed on this device'
              : 'Notifications blocked — tap to open Settings',
          style: const TextStyle(fontSize: 13, color: Color(0xFF7A8293)),
        ),
        value: permitted ?? true,
        onChanged: _onToggleChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF123CA5),
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFE0E4ED),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
