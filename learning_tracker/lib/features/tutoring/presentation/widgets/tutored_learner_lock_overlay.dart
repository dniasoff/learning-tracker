/// Covers a TUTORED learner's screens while that learner is inside a lock
/// window (Story 1.24, DNI-486, AC-6; AD-36 multi-learner rule).
///
/// Learners viewed through a tutor grant do not drive the device overlay
/// (`SacredTimeLockOverlay`, the union over the account's OWN profiles).
/// Until the talmid in view is known to be unlocked (while his lock loads,
/// while he is locked, or when his lock cannot be read), a full-screen
/// cover hides every screen of the tutored context — no data, no
/// controls, visually or to assistive technology.
/// Its one action exits the tutored context, so the tutor's own app and
/// other learners stay usable.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/scrollable_fill_body.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Wraps the router output; covers it while the tutored learner is locked.
///
/// Renamed from `TutoredLearnerLockOverlay` at the 1.28 release (AG-4: that
/// public name is the DNI-481 overlay in `sacred_time_lock_overlay.dart`,
/// which is the one `LearningTrackerApp` mounts).
class TutoredLearnerLockCover extends ConsumerWidget {
  /// Creates the overlay.
  const TutoredLearnerLockCover({required this.child, super.key});

  /// Everything below.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(tutoredLearnerLockProvider);
    // Fail closed: the learner's screens show only on an explicit "not
    // locked". While the talmid's lock is loading they sit under a neutral
    // pending cover; when it is locked or cannot be read, under the lock
    // cover. Outside a tutored session the provider answers "not locked"
    // at once, so the tutor's own app is never covered.
    final open = switch (lock) {
      AsyncData(value: false) => true,
      _ => false,
    };
    final pending = !open && lock is AsyncLoading<bool>;
    final covered = !open;
    // The cover is not just visual: while covered, the learner's screens
    // leave the semantics tree (a screen reader reads nothing of them), take
    // no pointer input and no keyboard focus. The wrappers stay in the tree
    // either way, so the screens keep their state across a lock.
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: covered,
          child: AbsorbPointer(
            absorbing: covered,
            child: ExcludeFocus(excluding: covered, child: child),
          ),
        ),
        if (pending)
          const _TutoredLearnerPendingScreen()
        else if (covered)
          const _TutoredLearnerLockScreen(),
      ],
    );
  }
}

/// The cover while the talmid's lock is still being read: no learner data
/// or controls, no claim that the learner is locked, and the same exit.
/// Static (no progress animation), so it never keeps frames scheduled.
class _TutoredLearnerPendingScreen extends ConsumerWidget {
  const _TutoredLearnerPendingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Material(
        key: const Key('tutoredLearnerLockPending'),
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ScrollableFillBody(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.loading,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    key: const Key('tutoredLearnerLockExit'),
                    onPressed: () => ref
                        .read(activeTutoredProfileSelectionProvider.notifier)
                        .exit(),
                    child: Text(l10n.tutorModeExit),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutoredLearnerLockScreen extends ConsumerWidget {
  const _TutoredLearnerLockScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // The theme's onPrimary ink (white in both themes) over the deep,
    // theme-independent lock fill — no raw colour literal.
    final ink = Theme.of(context).colorScheme.onPrimary;
    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          key: const Key('tutoredLearnerLockOverlay'),
          color: context.colors.sacredTimeLockShabbosBg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ScrollableFillBody(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 96,
                      color: ink.withValues(alpha: 0.92),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.tutorCaptureLearnerLocked,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton(
                      key: const Key('tutoredLearnerLockExit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ink,
                        side: BorderSide(color: ink.withValues(alpha: 0.7)),
                      ),
                      onPressed: () => ref
                          .read(activeTutoredProfileSelectionProvider.notifier)
                          .exit(),
                      child: Text(l10n.tutorModeExit),
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
}
