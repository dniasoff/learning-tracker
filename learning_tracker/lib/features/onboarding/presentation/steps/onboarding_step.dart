import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract base for a single onboarding step.
///
/// Each concrete step is a [ConsumerWidget] that encapsulates its own UI
/// and a `(load, save, validate)` triple:
///
/// - [load]     — called before the step becomes visible; restores any
///                persisted state for this step.
/// - [save]     — called when the user advances past this step; persists
///                the step's collected state.
/// - [validate] — called before [save]; returns `null` on success or an
///                error message string when the step's data is invalid.
///
/// The step widget receives [OnboardingStepContext] via its constructor so
/// it can call [OnboardingStepContext.advance] / [OnboardingStepContext.retreat]
/// without coupling to the controller directly.
///
/// [load], [save], and [validate] receive a [Ref] (the provider container ref)
/// so they can be called from the [OnboardingController] notifier without
/// depending on Flutter widget internals.
abstract class OnboardingStep {
  const OnboardingStep();

  /// Human-readable identifier used for persistence and debugging.
  String get id;

  /// Build the UI widget for this step.
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx);

  /// Restore previously saved state for this step (optional override).
  Future<void> load(Ref ref) async {}

  /// Persist the step's collected state (optional override).
  Future<void> save(Ref ref) async {}

  /// Return `null` if the step's data is valid, or an error message otherwise.
  String? validate(Ref ref) => null;
}

/// Context passed to each [OnboardingStep.build] so the step widget can
/// trigger navigation without importing the controller directly.
class OnboardingStepContext {
  const OnboardingStepContext({
    required this.advance,
    required this.retreat,
    required this.stepIndex,
    required this.totalSteps,
  });

  /// Move forward to the next step.
  final Future<void> Function() advance;

  /// Move back to the previous step.
  final void Function() retreat;

  final int stepIndex;
  final int totalSteps;
}
