import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Displays the current sync status as a compact icon with optional label.
///
/// States: synced (green check), syncing (spinning), pending (orange clock),
/// offline (grey cloud-off), error (red warning).
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({this.showLabel = false, super.key});

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    final (IconData icon, Color color, String label, bool spinning) =
        switch (status) {
          SyncStatusSynced() => (
            Icons.cloud_done,
            Colors.green,
            'Synced',
            false,
          ),
          SyncStatusSyncing() => (
            Icons.sync,
            Theme.of(context).colorScheme.primary,
            'Syncing',
            true,
          ),
          SyncStatusPending(:final pendingChanges) => (
            Icons.schedule,
            Colors.orange,
            '$pendingChanges pending',
            false,
          ),
          SyncStatusOffline(:final pendingChanges) => (
            Icons.cloud_off,
            Colors.grey,
            pendingChanges > 0 ? '$pendingChanges queued' : 'Offline',
            false,
          ),
          SyncStatusError() => (
            Icons.warning_amber,
            Colors.red,
            'Sync error',
            false,
          ),
        };

    return _buildIndicator(
      context,
      icon: icon,
      color: color,
      label: label,
      spinning: spinning,
    );
  }

  Widget _buildIndicator(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required bool spinning,
  }) {
    final iconWidget = Icon(icon, color: color, size: 20);
    final displayIcon =
        spinning
            ? SizedBox(
              width: 20,
              height: 20,
              child: RepaintBoundary(
                child: _SpinningIcon(icon: icon, color: color),
              ),
            )
            : iconWidget;

    if (!showLabel) {
      return Tooltip(message: label, child: displayIcon);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        displayIcon,
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, color: widget.color, size: 20),
    );
  }
}
