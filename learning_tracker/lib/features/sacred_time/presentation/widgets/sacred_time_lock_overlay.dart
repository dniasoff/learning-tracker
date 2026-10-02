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

/// The full-screen Sacred Time lock (AD-36, DNI-481 AC-1).
///
/// Mounted in the `MaterialApp.router` builder slot, so it wraps the WHOLE
/// router output — every tab, pushed route and dialog. While
/// [currentSacredWindowProvider] reports a lock (the union of `lockWindows`
/// over every learner whose lock drives the device) it shows the opaque
/// existing surface — background, white icon and greeting, no zmanim — and
/// the app behind it is offstage: not painted, not hit-testable, excluded
/// from semantics, its tickers paused. The greeting is a live region, so a
/// screen reader announces it. System back is swallowed by
/// `SacredTimeBackButtonDispatcher` (the router's back dispatcher).
///
/// The child keeps its place in the tree through lock and unlock (only its
/// [Offstage] / [TickerMode] flags flip), so navigation state survives a
/// lock. The overlay lifts by itself when the lock ends: the provider
/// re-judges at the lock's boundaries.
class SacredTimeLockOverlay extends ConsumerWidget {
  const SacredTimeLockOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _LockCover(window: ref.watch(currentSacredWindowProvider), child: child);
}

/// The cover over a locked talmid's screens in a tutored session (DNI-481
/// AC-1 tutor rule, AD-36 "Multi-learner devices").
///
/// A talmid viewed through a tutor grant never drives the device lock
/// ([SacredTimeLockOverlay]). While an active tutored session shows a
/// talmid inside their own lock ([currentTutoredSacredWindowProvider]),
/// this covers what the router renders — the talmid's data and controls
/// are offstage, exactly as under the device lock — with the same
/// sacred-time surface, plus ONE control of the tutor's own: [onExit]
/// leaves the tutored session, so the tutor is never trapped behind the
/// talmid's lock. Mounted inside [SacredTimeLockOverlay], so the tutor's
/// own account lock still covers everything.
class TutoredLearnerLockOverlay extends ConsumerWidget {
  const TutoredLearnerLockOverlay({
    required this.onExit,
    required this.child,
    super.key,
  });

  /// Leaves the tutored session (back to the tutor's own profile).
  final VoidCallback onExit;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _LockCover(
    window: ref.watch(currentTutoredSacredWindowProvider),
    onExitTutoredSession: onExit,
    child: child,
  );
}

/// Shows [child] while [window] is null; otherwise keeps it in the tree
/// but offstage (no paint, touch or semantics, tickers paused) under the
/// opaque lock screen of [window].
///
/// The root `ScaffoldMessenger` (from `MaterialApp.router`) sits ABOVE the
/// builder slot this cover is mounted in. Its snack bars and material
/// banners are painted by the Scaffolds of the covered routes, so they are
/// offstage with them; still, when the lock engages the cover dismisses
/// them and drops the queue, so no snack bar (and no action of one — e.g.
/// the after-lock location prompt) is pending behind the lock, resurfaces
/// when it lifts, or paints on any Scaffold outside the cover (AC-1 touch
/// and semantics boundary).
class _LockCover extends ConsumerStatefulWidget {
  const _LockCover({
    required this.window,
    required this.child,
    this.onExitTutoredSession,
  });

  final SacredWindow? window;
  final Widget child;
  final VoidCallback? onExitTutoredSession;

  @override
  ConsumerState<_LockCover> createState() => _LockCoverState();
}

class _LockCoverState extends ConsumerState<_LockCover> {
  @override
  void initState() {
    super.initState();
    if (widget.window != null) _dismissMessengerSurfaces();
  }

  @override
  void didUpdateWidget(_LockCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window == null && widget.window != null) {
      _dismissMessengerSurfaces();
    }
  }

  /// Removes every snack bar and material banner of the enclosing (root)
  /// messenger, current and queued, at once — after this frame, since the
  /// messenger rebuilds its scaffolds.
  void _dismissMessengerSurfaces() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger
        ..clearSnackBars()
        ..removeCurrentSnackBar()
        ..clearMaterialBanners()
        ..removeCurrentMaterialBanner();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeWindow = widget.window;
    final locked = activeWindow != null;
    // Resolve the variant-aware Shabbos term once here (this is the Consumer
    // layer) and hand the composed greeting/subtitle down to the plain
    // _LockScreen widget. Keeps the Hebrew-terms toggle + Ashkenazi/Sephardi
    // nusach honoured rather than baking "Shabbos" into the ARB.
    final shabbos = locked
        ? domainTermLabels(
            ref,
          ).shabbos(variant: ref.watch(currentTransliterationVariantProvider))
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Same position and type locked or not: the app's element subtree
        // (router, navigation stack) is kept, only hidden.
        Offstage(
          offstage: locked,
          child: TickerMode(enabled: !locked, child: widget.child),
        ),
        if (locked)
          _LockScreen(
            window: activeWindow,
            shabbos: shabbos!,
            onExitTutoredSession: widget.onExitTutoredSession,
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.window,
    required this.shabbos,
    this.onExitTutoredSession,
  });

  final SacredWindow window;

  /// When set (a tutored session's cover), the tutor's exit control.
  final VoidCallback? onExitTutoredSession;

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
                // A live region: the greeting is announced when the lock
                // starts (UX-DR-159).
                child: Semantics(
                  container: true,
                  liveRegion: true,
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
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                              height: 1.4,
                            ),
                      ),
                      if (onExitTutoredSession case final onExit?) ...[
                        const SizedBox(height: 32),
                        Text(
                          l10n.tutorModeIndicator,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('tutoredLearnerLockExit'),
                          onPressed: onExit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            minimumSize: const Size(
                              kMinInteractiveDimension,
                              kMinInteractiveDimension,
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(l10n.tutorModeExit),
                        ),
                      ],
                    ],
                  ),
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
          // AUD-darkmode: accentPurpleDeep is an ink/icon-on-card role that
          // LIGHTENS in dark mode, but this full-screen lock overlay paints
          // it as a HERO FILL with hardcoded white greeting/icon text --
          // measured ~1.97:1 in dark. sacredTimeLockYomTovBg is pinned to
          // the exact old accentPurpleDeep light literal in both themes,
          // restoring ~10.55:1 (matching the other sacred-time lock
          // backgrounds, which already stay deep in both themes).
          background: context.colors.sacredTimeLockYomTovBg,
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
