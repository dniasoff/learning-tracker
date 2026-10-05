import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/scrollable_fill_body.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_settings_editor_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/lock_cover_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/screens/city_picker_screen.dart';
import 'package:learning_tracker/features/sacred_time/presentation/widgets/sacred_time_settings_card.dart';
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
///
/// Its one action, "Wrong location? Change location" (product ruling
/// 2026-10-05), opens the city picker INSIDE the overlay (behind the same
/// Parent PIN guards as the after-lock prompt) for the learner whose lock
/// is shown — an own profile of the person using the device. Saving
/// recomputes the lock at once; the app behind stays covered throughout,
/// so it is never a way around the lock itself.
class SacredTimeLockOverlay extends ConsumerWidget {
  const SacredTimeLockOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _LockCover(window: ref.watch(currentSacredWindowProvider), child: child);
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
  const _LockCover({required this.window, required this.child});

  final SacredWindow? window;
  final Widget child;

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

  /// The learner whose location the in-overlay city picker edits, while
  /// it is open.
  String? _fixingLocationFor;

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
      setState(() {
        _shown = null;
        _fixingLocationFor = null;
      });
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
            onChangeLocation: activeWindow.profileId == null
                ? null
                : () => setState(
                    () => _fixingLocationFor = activeWindow.profileId,
                  ),
          ),
        if (locked && _fixingLocationFor != null)
          _LockLocationFlow(
            key: ValueKey(_fixingLocationFor),
            profileId: _fixingLocationFor!,
            onClose: () {
              if (mounted) setState(() => _fixingLocationFor = null);
            },
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.window,
    required this.shabbos,
    this.onChangeLocation,
  });

  final SacredWindow window;

  /// Opens the in-overlay city picker; null hides the action.
  final VoidCallback? onChangeLocation;

  /// Variant-resolved Shabbos term ("Shabbos" / "Shabbat" / "שבת"), composed
  /// into the localized greeting and subtitle frames.
  final String shabbos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spec = _specFor(context, window.kind);
    final (greeting, subtitle) = _stringsFor(window.kind, l10n, shabbos);
    final zone = LearnerZone.of(window.timeZone);
    final start = zone.wallTimeOf(window.startUtc);
    final end = zone.wallTimeOf(window.endUtc);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String weekday(DateTime local) => DateFormat.E(locale).format(local);
    String time(DateTime local) =>
        MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay(hour: local.hour, minute: local.minute),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );
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
                      const SizedBox(height: 24),
                      Text(
                        l10n.sacredTimeLockStartedAt(
                          weekday(start),
                          time(start),
                        ),
                        key: const Key('sacredTimeLockStartTime'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.colors.sacredTimeLockInk.withValues(
                            alpha: 0.86,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.sacredTimeLockUnlocksAt(weekday(end), time(end)),
                        key: const Key('sacredTimeLockUnlockTime'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: context.colors.sacredTimeLockInk,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (onChangeLocation case final onChange?) ...[
                        const SizedBox(height: 32),
                        OutlinedButton.icon(
                          key: const Key('sacredTimeLockChangeLocation'),
                          onPressed: onChange,
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
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: Text(
                            l10n.sacredTimeLockChangeLocation,
                            textAlign: TextAlign.center,
                          ),
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

/// The overlay's "change location" flow for own learner [profileId]: the
/// Parent PIN guards of the after-lock prompt
/// ([guardLearnerLocationPromptAccess]), then the city picker writing to
/// that learner ([lockLocationEditorProvider]). Hosted in its own
/// [Navigator] inside the overlay, so the PIN dialog and the picker show
/// above the lock screen while the app stays covered. [onClose] runs on
/// cancel, a refused PIN, or a saved city.
class _LockLocationFlow extends ConsumerStatefulWidget {
  const _LockLocationFlow({
    required this.profileId,
    required this.onClose,
    super.key,
  });

  final String profileId;
  final VoidCallback onClose;

  @override
  ConsumerState<_LockLocationFlow> createState() => _LockLocationFlowState();
}

class _LockLocationFlowState extends ConsumerState<_LockLocationFlow> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authorize());
  }

  Future<void> _authorize() async {
    final navigatorContext = _navigator.currentContext;
    if (!mounted || navigatorContext == null) return;
    final ok = await guardLearnerLocationPromptAccess(
      navigatorContext,
      ref,
      widget.profileId,
    );
    if (!mounted) return;
    if (!ok) {
      widget.onClose();
      return;
    }
    setState(() => _authorized = true);
  }

  @override
  Widget build(BuildContext context) {
    // Watched, so the editor and its write dependencies stay alive while
    // the picker is open.
    final editor = ref.watch(lockLocationEditorProvider(widget.profileId));
    return HeroControllerScope.none(
      child: Navigator(
        key: _navigator,
        pages: [
          MaterialPage<void>(
            key: ValueKey(_authorized),
            child: _authorized
                ? CityPickerView(
                    key: const Key('sacredTimeLockCityPicker'),
                    editor: (_) => editor,
                    onSaved: (_) => widget.onClose(),
                    onCancel: widget.onClose,
                  )
                : Material(color: Theme.of(context).colorScheme.surface),
          ),
        ],
        onDidRemovePage: (_) {},
      ),
    );
  }
}
