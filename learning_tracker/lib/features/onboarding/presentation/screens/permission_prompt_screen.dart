import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/notifications/domain/services/notification_service.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';

/// Stand-alone screen that requests notification and location permissions.
///
/// Both permissions are optional — users can skip either or both. The screen
/// is reachable from:
///   • the Settings screen (to re-prompt after install)
///   • the Onboarding flow (shown once after profile creation is complete)
///
/// Uses the existing [NotificationService.requestPermission] and
/// [SacredLocationNotifier.detect] infrastructure, which already handle
/// Android 13+ POST_NOTIFICATIONS, Android 12+ exact-alarm, and iOS alerts.
@RoutePage()
class PermissionPromptScreen extends ConsumerStatefulWidget {
  const PermissionPromptScreen({
    super.key,

    /// When [isOnboarding] is true the screen shows a "Continue" CTA that pops
    /// back. When false (launched from Settings) only the "Done" button is
    /// shown. The behaviour is identical — this flag just adjusts button labels.
    this.isOnboarding = false,
  });

  final bool isOnboarding;

  @override
  ConsumerState<PermissionPromptScreen> createState() =>
      _PermissionPromptScreenState();
}

enum _PermStatus { idle, requesting, granted, denied }

class _PermissionPromptScreenState
    extends ConsumerState<PermissionPromptScreen> {
  _PermStatus _notifStatus = _PermStatus.idle;
  _PermStatus _locationStatus = _PermStatus.idle;

  bool get _notifDone =>
      _notifStatus == _PermStatus.granted || _notifStatus == _PermStatus.denied;
  bool get _locationDone =>
      _locationStatus == _PermStatus.granted ||
      _locationStatus == _PermStatus.denied;

  // ── Notification permission ───────────────────────────────────────────────

  Future<void> _requestNotifications() async {
    if (_notifStatus == _PermStatus.requesting) return;
    setState(() => _notifStatus = _PermStatus.requesting);

    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestPermission();

    if (!mounted) return;
    setState(
      () => _notifStatus = granted ? _PermStatus.granted : _PermStatus.denied,
    );
  }

  // ── Location permission ───────────────────────────────────────────────────

  Future<void> _requestLocation() async {
    if (_locationStatus == _PermStatus.requesting) return;
    setState(() => _locationStatus = _PermStatus.requesting);

    final result = await ref.read(sacredLocationProvider.notifier).detect();

    if (!mounted) return;
    setState(() {
      _locationStatus = result is LocationFetchSuccess
          ? _PermStatus.granted
          : _PermStatus.denied;
    });
  }

  // ── Dismiss ───────────────────────────────────────────────────────────────

  void _finish() => context.maybePop();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F8),
        elevation: 0,
        title: Text(
          widget.isOnboarding ? 'Almost Done!' : 'App Permissions',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isOnboarding
                    ? 'Allow these optional permissions so Learning Tracker '
                          'can remind you to learn and compute Shabbos times '
                          'for your location.'
                    : 'Manage optional permissions for reminders and '
                          'Shabbos-time calculations.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _PermissionCard(
                icon: Icons.notifications_active_outlined,
                iconColor: const Color(0xFF2A4BB3),
                iconBackground: const Color(0xFFE8EBFF),
                title: 'Notifications',
                subtitle:
                    'Daily learning reminders and streak-protection alerts.',
                status: _notifStatus,
                onTap: _notifDone ? null : _requestNotifications,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                icon: Icons.location_on_outlined,
                iconColor: const Color(0xFF1E7B5A),
                iconBackground: const Color(0xFFDDF3EB),
                title: 'Location',
                subtitle:
                    'Accurate Shabbos candle-lighting and Havdalah times '
                    'based on your city.',
                status: _locationStatus,
                onTap: _locationDone ? null : _requestLocation,
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                onPressed: _finish,
                child: Text(
                  widget.isOnboarding ? 'Start Learning' : 'Done',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _finish,
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Color(0xFF7A8293)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Permission card widget ────────────────────────────────────────────────────

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final _PermStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF151B2D),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7A8293),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusWidget(status: status, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _StatusWidget extends StatelessWidget {
  const _StatusWidget({required this.status, required this.onTap});

  final _PermStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _PermStatus.idle => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF123CA5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'Allow',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      _PermStatus.requesting => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _PermStatus.granted => const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF1E7B5A),
        size: 28,
      ),
      _PermStatus.denied => const Icon(
        Icons.cancel_outlined,
        color: Color(0xFF9CA3B4),
        size: 28,
      ),
    };
  }
}
