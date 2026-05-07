import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';

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
    final spec = _specFor(window.kind);
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
                    spec.greeting,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    spec.subtitle,
                    textAlign: TextAlign.center,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
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
          greeting: 'Good Shabbos',
          subtitle: 'The app is closed for Shabbos.',
          background: Color(0xFF11215C),
        );
      case SacredWindowKind.yomTov:
        return const _LockSpec(
          icon: Icons.celebration_outlined,
          greeting: 'Good Yom Tov',
          subtitle: 'The app is closed for Yom Tov.',
          background: Color(0xFF4A2A8A),
        );
      case SacredWindowKind.shabbosYomTov:
        return const _LockSpec(
          icon: Icons.celebration_outlined,
          greeting: 'Good Shabbos & Good Yom Tov',
          subtitle: 'The app is closed for Shabbos and Yom Tov.',
          background: Color(0xFF31246C),
        );
      case SacredWindowKind.yomKippur:
        return const _LockSpec(
          icon: Icons.menu_book_outlined,
          greeting: 'Have an easy and meaningful fast',
          subtitle: 'The app is closed for Yom Kippur.',
          background: Color(0xFF1A2333),
        );
    }
  }
}

class _LockSpec {
  const _LockSpec({
    required this.icon,
    required this.greeting,
    required this.subtitle,
    required this.background,
  });

  final IconData icon;
  final String greeting;
  final String subtitle;
  final Color background;
}
