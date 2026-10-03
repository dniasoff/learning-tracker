import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/scrollable_fill_body.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/lock_cover_provider.dart';
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
/// offstage with them; still, nothing requested from it may be pending
/// behind the lock or resurface when it lifts (AC-1 touch and semantics
/// boundary). So the root messenger is gated for the WHOLE locked
/// interval:
///  * when the lock engages, the cover dismisses every snack bar and banner
///    shown or queued before it;
///  * when the lock ends, the cover stays up one more frame, dismisses
///    every snack bar and banner requested while it was up (by any async
///    caller, at any point of the lock), and only then reveals the app.
/// The cover is registered in [lockCoversProvider] from engage to that
/// release, so after-lock surfaces (the location prompt) are requested
/// only once the discard has run.
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
  /// This cover's identity in [lockCoversProvider].
  final Object _token = Object();

  late final LockCovers _covers;

  /// The window on screen. It follows [_LockCover.window] at once when a
  /// lock starts or changes, but outlives it by the release step when the
  /// lock ends.
  SacredWindow? _shown;

  @override
  void initState() {
    super.initState();
    _covers = ref.read(lockCoversProvider.notifier);
    _shown = widget.window;
    if (_shown != null) _engage();
  }

  @override
  void didUpdateWidget(_LockCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    final window = widget.window;
    if (window != null) {
      final wasCovered = _shown != null;
      _shown = window;
      if (!wasCovered) _engage();
    } else if (oldWidget.window != null && _shown != null) {
      _release();
    }
  }

  @override
  void dispose() {
    final covers = _covers;
    final token = _token;
    // Providers cannot change while the tree is being torn down.
    WidgetsBinding.instance.addPostFrameCallback((_) => covers.release(token));
    super.dispose();
  }

  /// The lock started: drop what the messenger held before it (after this
  /// frame — the messenger rebuilds its scaffolds, and providers cannot
  /// change mid-build).
  void _engage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.window == null) return;
      _dismissMessengerSurfaces();
      _covers.engage(_token);
    });
  }

  /// The lock ended: drop what was requested while it was up, THEN reveal
  /// the app and release the cover — unless a lock started again first.
  void _release() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.window != null) return;
      _dismissMessengerSurfaces();
      setState(() => _shown = null);
      _covers.release(_token);
    });
  }

  /// Removes every snack bar and material banner of the enclosing (root)
  /// messenger, current and queued, at once (no exit animation).
  void _dismissMessengerSurfaces() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar()
      ..clearMaterialBanners()
      ..removeCurrentMaterialBanner();
  }

  @override
  Widget build(BuildContext context) {
    final activeWindow = _shown;
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
                        color: context.colors.sacredTimeLockInk.withValues(
                          alpha: 0.92,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        greeting,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: context.colors.sacredTimeLockInk,
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
                              color: context.colors.sacredTimeLockInk
                                  .withValues(alpha: 0.78),
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
                                color: context.colors.sacredTimeLockInk
                                    .withValues(alpha: 0.78),
                              ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('tutoredLearnerLockExit'),
                          onPressed: onExit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.sacredTimeLockInk,
                            side: BorderSide(
                              color: context.colors.sacredTimeLockInk,
                            ),
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
