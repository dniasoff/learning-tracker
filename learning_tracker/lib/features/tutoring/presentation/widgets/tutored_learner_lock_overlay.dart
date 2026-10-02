/// Covers a TUTORED learner's screens while that learner is inside a lock
/// window (Story 1.24, DNI-486, AC-6; AD-36 multi-learner rule).
///
/// Learners viewed through a tutor grant do not drive the device overlay
/// (`SacredTimeLockOverlay`, the union over the account's OWN profiles).
/// While the talmid in view is locked, this cover hides every screen of the
/// tutored context — no data, no controls — in the same full-screen style.
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
class TutoredLearnerLockOverlay extends ConsumerWidget {
  /// Creates the overlay.
  const TutoredLearnerLockOverlay({required this.child, super.key});

  /// Everything below.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(tutoredLearnerLockProvider);
    // Covered while locked, and when the talmid's lock cannot be read (fail
    // closed). While it loads, writes are still refused by the preflight.
    final covered = lock.hasError || lock.value == true;
    return Stack(
      children: [child, if (covered) const _TutoredLearnerLockScreen()],
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
