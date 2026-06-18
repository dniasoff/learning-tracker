import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/sacred_time/data/services/location_service.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_location_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Stand-alone screen that requests notification and location permissions.
///
/// Both permissions are optional — users can skip either or both. The screen
/// is reachable from:
///   • the Settings screen (to re-prompt after install)
///   • the Onboarding flow (shown once after profile creation is complete,
///     pushed with [isOnboarding] = true)
///
/// Uses the existing [notificationServiceProvider].requestPermission and
/// [SacredLocationNotifier].detect infrastructure, which already handle
/// Android 13+ POST_NOTIFICATIONS, Android 12+ exact-alarm, and iOS alerts.
@RoutePage()
class PermissionPromptScreen extends ConsumerStatefulWidget {
  const PermissionPromptScreen({
    super.key,

    /// When [isOnboarding] is true the title reads "Almost Done!" and the CTA
    /// reads "Start Learning". When false (launched from Settings) the title is
    /// "App Permissions" and the CTA reads "Done".
    this.isOnboarding = false,
  });

  final bool isOnboarding;

  @override
  ConsumerState<PermissionPromptScreen> createState() =>
      _PermissionPromptScreenState();
}

/// Permission state for a single system permission card.
enum _PermissionStatus { idle, requesting, granted, denied }

class _PermissionPromptScreenState
    extends ConsumerState<PermissionPromptScreen> {
  _PermissionStatus _notifStatus = _PermissionStatus.idle;
  _PermissionStatus _locationStatus = _PermissionStatus.idle;

  bool get _notifDone =>
      _notifStatus == _PermissionStatus.granted ||
      _notifStatus == _PermissionStatus.denied;
  bool get _locationDone =>
      _locationStatus == _PermissionStatus.granted ||
      _locationStatus == _PermissionStatus.denied;

  /// True once the user has resolved (allowed or denied) both permission cards.
  bool get _allDone => _notifDone && _locationDone;

  // ── Notification permission ───────────────────────────────────────────────

  Future<void> _requestNotifications() async {
    if (_notifStatus == _PermissionStatus.requesting) return;
    setState(() => _notifStatus = _PermissionStatus.requesting);

    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestPermission();

    if (!mounted) return;
    setState(
      () => _notifStatus = granted
          ? _PermissionStatus.granted
          : _PermissionStatus.denied,
    );
  }

  // ── Location permission ───────────────────────────────────────────────────

  Future<void> _requestLocation() async {
    if (_locationStatus == _PermissionStatus.requesting) return;
    setState(() => _locationStatus = _PermissionStatus.requesting);

    final result = await ref.read(sacredLocationProvider.notifier).detect();

    if (!mounted) return;
    setState(() {
      _locationStatus = result is LocationFetchSuccess
          ? _PermissionStatus.granted
          : _PermissionStatus.denied;
    });
  }

  // ── Dismiss ───────────────────────────────────────────────────────────────

  void _finish() => context.maybePop();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final variant = ref.watch(currentTransliterationVariantProvider);
    final terms = domainTermLabels(ref);
    final shabbos = terms.shabbos(variant: variant);
    final havdalah = terms.havdalah(variant: variant);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.isOnboarding
              ? l10n.permissionPromptTitleOnboarding
              : l10n.settingsAppPermissions,
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
                    ? l10n.permissionPromptBodyOnboarding(shabbos)
                    : l10n.permissionPromptBodySettings(shabbos),
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
                title: l10n.notifications,
                subtitle: l10n.permissionPromptNotifSubtitle,
                status: _notifStatus,
                onTap: _notifDone ? null : _requestNotifications,
              ),
              const SizedBox(height: 12),
              _PermissionCard(
                icon: Icons.location_on_outlined,
                iconColor: const Color(0xFF1E7B5A),
                iconBackground: const Color(0xFFDDF3EB),
                title: l10n.permissionPromptLocationTitle,
                subtitle: l10n.permissionPromptLocationSubtitle(
                  shabbos,
                  havdalah,
                ),
                status: _locationStatus,
                onTap: _locationDone ? null : _requestLocation,
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  elevation: 3,
                  shadowColor: AppTheme.brandBlue.withValues(alpha: 0.35),
                ),
                onPressed: _finish,
                child: Text(
                  widget.isOnboarding
                      ? l10n.startLearning
                      : l10n.permissionPromptCtaDone,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // "Skip for now" is only meaningful while at least one card is
              // still in the idle state — once both are resolved (granted or
              // denied) the primary CTA is the only action needed.
              if (!_allDone) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _finish,
                  child: Text(
                    l10n.actionSkipForNow,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
  final _PermissionStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12061D56),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF151B2D),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            const SizedBox(width: 10),
            _PermissionStatusWidget(status: status, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _PermissionStatusWidget extends StatelessWidget {
  const _PermissionStatusWidget({required this.status, required this.onTap});

  final _PermissionStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (status) {
      _PermissionStatus.idle => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF123CA5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: const StadiumBorder(),
        ),
        child: Text(
          l10n.permissionPromptAllowButton,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      _PermissionStatus.requesting => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      _PermissionStatus.granted => const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF1E7B5A),
        size: 26,
      ),
      _PermissionStatus.denied => const Icon(
        Icons.cancel_outlined,
        color: Color(0xFF9CA3B4),
        size: 26,
      ),
    };
  }
}
