import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/scrollable_fill_body.dart';
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
    if (activeWindow == null) {
      return Stack(children: [child]);
    }
    // Resolve the variant-aware Shabbos term once here (this is the Consumer
    // layer) and hand the composed greeting/subtitle down to the plain
    // _LockScreen widget. Keeps the Hebrew-terms toggle + Ashkenazi/Sephardi
    // nusach honoured rather than baking "Shabbos" into the ARB.
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final shabbos = terms.shabbos(variant: variant);
    return Stack(
      children: [
        child,
        _LockScreen(window: activeWindow, shabbos: shabbos),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.window, required this.shabbos});

  final SacredWindow window;

  /// Variant-resolved Shabbos term ("Shabbos" / "Shabbat" / "שבת"), composed
  /// into the localized greeting and subtitle frames.
  final String shabbos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spec = _specFor(context, window.kind);
    final (greeting, subtitle) = _stringsFor(window.kind, l10n, shabbos);
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          color: spec.background,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              // Centre the greeting on normal devices, but let it scroll when
              // the icon + large display text exceed the viewport height (small
              // screens at large text scales) instead of overflowing.
              child: ScrollableFillBody(
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
      ),
    );
  }

  static _LockSpec _specFor(BuildContext context, SacredWindowKind kind) {
    switch (kind) {
      case SacredWindowKind.shabbos:
        return _LockSpec(
          icon: Icons.local_fire_department_outlined,
          background: context.colors.sacredTimeLockShabbosBg,
        );
      case SacredWindowKind.yomTov:
        return _LockSpec(
          icon: Icons.celebration_outlined,
          background: context.colors.accentPurpleDeep,
        );
      case SacredWindowKind.shabbosYomTov:
        return _LockSpec(
          icon: Icons.celebration_outlined,
          background: context.colors.sacredTimeLockShabbosYomTovBg,
        );
      case SacredWindowKind.yomKippur:
        return _LockSpec(
          icon: Icons.menu_book_outlined,
          background: context.colors.sacredTimeLockYomKippurBg,
        );
    }
  }

  static (String greeting, String subtitle) _stringsFor(
    SacredWindowKind kind,
    AppLocalizations l10n,
    String shabbos,
  ) {
    switch (kind) {
      case SacredWindowKind.shabbos:
        return (
          l10n.sacredTimeLockGoodShabbos(shabbos),
          l10n.sacredTimeLockShabbosSubtitle(shabbos),
        );
      case SacredWindowKind.yomTov:
        return (
          l10n.sacredTimeLockGoodYomTov,
          l10n.sacredTimeLockYomTovSubtitle,
        );
      case SacredWindowKind.shabbosYomTov:
        return (
          l10n.sacredTimeLockShabbosYomTovGreeting(shabbos),
          l10n.sacredTimeLockShabbosYomTovSubtitle(shabbos),
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
