import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Top-level wrapper that overlays a full-screen "Sacred Time" lock when
/// [currentSacredWindowProvider] returns non-null. Mounted at the
/// `MaterialApp.router` builder slot so every route is covered (onboarding,
/// settings, dashboard, etc.).
///
/// The overlay shows only a greeting message — no zmanim. It dismisses itself
/// silently when the window ends (provider re-evaluates every 30s).
class SacredTimeLockOverlay extends ConsumerWidget {
  const SacredTimeLockOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWindow = ref.watch(currentSacredWindowProvider);
    return Stack(
      children: [
        child,
        if (activeWindow != null) _LockScreen(window: activeWindow),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.window});

  final SacredWindow window;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spec = _specFor(window.kind);
    final (greeting, subtitle) = _stringsFor(window.kind, l10n);
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          color: spec.background,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    spec.icon,
                    size: 96,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static _LockSpec _specFor(SacredWindowKind kind) {
    switch (kind) {
      case SacredWindowKind.shabbos:
        return const _LockSpec(
          icon: Icons.local_fire_department_outlined,
          background: Color(0xFF11215C),
        );
      case SacredWindowKind.yomTov:
        return const _LockSpec(
          icon: Icons.celebration_outlined,
          background: Color(0xFF4A2A8A),
        );
      case SacredWindowKind.shabbosYomTov:
        return const _LockSpec(
          icon: Icons.celebration_outlined,
          background: Color(0xFF31246C),
        );
      case SacredWindowKind.yomKippur:
        return const _LockSpec(
          icon: Icons.menu_book_outlined,
          background: Color(0xFF1A2333),
        );
    }
  }

  static (String greeting, String subtitle) _stringsFor(
    SacredWindowKind kind,
    AppLocalizations l10n,
  ) {
    switch (kind) {
      case SacredWindowKind.shabbos:
        return (
          l10n.sacredTimeLockGoodShabbos,
          l10n.sacredTimeLockShabbosSubtitle,
        );
      case SacredWindowKind.yomTov:
        return (
          l10n.sacredTimeLockGoodYomTov,
          l10n.sacredTimeLockYomTovSubtitle,
        );
      case SacredWindowKind.shabbosYomTov:
        return (
          l10n.sacredTimeLockShabbosYomTovGreeting,
          l10n.sacredTimeLockShabbosYomTovSubtitle,
        );
      case SacredWindowKind.yomKippur:
        return (
          l10n.sacredTimeLockYomKippurGreeting,
          l10n.sacredTimeLockYomKippurSubtitle,
        );
    }
  }
}

class _LockSpec {
  const _LockSpec({required this.icon, required this.background});

  final IconData icon;
  final Color background;
}
