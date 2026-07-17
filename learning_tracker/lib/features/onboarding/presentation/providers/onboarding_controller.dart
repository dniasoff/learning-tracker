import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.g.dart';

/// Sentinel returned by [OnboardingController.advance] when the current
/// step's [OnboardingStep.save] threw (AUD-core-preferences-04, EH-2/EH-5).
///
/// Not a human-facing message — [OnboardingStep.validate]'s error strings
/// and this sentinel share the same `String?` return channel, but presentation
/// does not currently branch on either value (`LearningProcessWizardScreen`'s
/// `ctx.advance` closure awaits [OnboardingController.advance] and discards
/// its result — a pre-existing gap, out of this finding's scope to wire up).
/// [AppLogger] is the actual diagnostic channel for a save failure today;
/// this constant keeps the return contract honest (never `null`-as-success
/// when the save actually failed) for whenever that UI plumbing is added.
const String kOnboardingStepSaveFailedErrorCode = 'onboarding_step_save_failed';

/// Immutable state for [OnboardingController].
class OnboardingControllerState {
  const OnboardingControllerState({required this.steps, this.currentIndex = 0});

  /// The ordered list of steps to advance through.
  final List<OnboardingStep> steps;

  /// Index of the currently active step.
  final int currentIndex;

  /// The currently active step.
  OnboardingStep get currentStep => steps[currentIndex];

  /// Whether there is a next step to advance to.
  bool get hasNext => currentIndex < steps.length - 1;

  /// Whether there is a previous step to retreat to.
  bool get hasPrevious => currentIndex > 0;

  OnboardingControllerState copyWith({
    List<OnboardingStep>? steps,
    int? currentIndex,
  }) {
    return OnboardingControllerState(
      steps: steps ?? this.steps,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

/// Riverpod notifier that owns the step list and current position.
///
/// Constructed with an initial [steps] list. Consumers call [advance] /
/// [retreat] to move between steps. Each step's [OnboardingStep.save] is
/// called before advancing and [OnboardingStep.load] is called on the
/// incoming step.
@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingControllerState build() {
    // Default to an empty step list. Callers override or rebuild with real
    // steps via [init].
    return const OnboardingControllerState(steps: []);
  }

  /// Initialise the controller with an ordered [steps] list and load the
  /// first step.
  Future<void> init(List<OnboardingStep> steps) async {
    state = OnboardingControllerState(steps: steps, currentIndex: 0);
    if (steps.isNotEmpty) {
      await _guardedLoad(steps[0]);
    }
  }

  /// Validate and save the current step, then move to the next one.
  ///
  /// Returns the validation error string if validation fails,
  /// [kOnboardingStepSaveFailedErrorCode] if the step's persistence call
  /// threw, or `null` on success. The caller should display the error to the
  /// user.
  Future<String?> advance() async {
    final current = state.currentStep;
    final error = current.validate(ref);
    if (error != null) return error;

    try {
      await current.save(ref);
    } catch (e, st) {
      // AUD-core-preferences-04 (EH-2): a raw persistence exception must
      // never propagate into presentation. Stay on the current step —
      // advancing past a step whose data failed to save would leave
      // in-memory state (the next step is now "current") silently diverged
      // from what is actually persisted, with the user believing the prior
      // step's data was saved when it was not.
      AppLogger.instance.error(
        event: 'onboarding_step_save_failed',
        exception: e,
        stackTrace: st,
        fields: {'stepId': current.id},
      );
      return kOnboardingStepSaveFailedErrorCode;
    }

    // AUD-onboarding-01 (SM-4): current.save(ref) may perform DB-touching
    // work. If the wizard screen (and therefore this autoDispose provider)
    // was torn down while that save was in flight, resuming and touching
    // `state` below throws — bail out cleanly instead.
    if (!ref.mounted) return null;

    if (!state.hasNext) return null;

    final nextIndex = state.currentIndex + 1;
    state = state.copyWith(currentIndex: nextIndex);
    await _guardedLoad(state.steps[nextIndex]);
    return null;
  }

  /// Move back to the previous step without saving the current step.
  void retreat() {
    if (!state.hasPrevious) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  /// Jump directly to a step by index (used when resuming from persisted state).
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.steps.length) return;
    state = state.copyWith(currentIndex: index);
    await _guardedLoad(state.steps[index]);
  }

  /// AUD-core-preferences-04 (EH-2): [OnboardingStep.load] is an arbitrary
  /// per-step override with no error channel of its own — an exception
  /// previously propagated as a raw, uncaught Future rejection out of
  /// [init]/[advance]/[jumpTo]. Catches and logs via [AppLogger] so a failed
  /// pre-fill never crashes the wizard; the step still renders (with
  /// default/blank fields) instead of leaving the user stuck.
  Future<void> _guardedLoad(OnboardingStep step) async {
    try {
      await step.load(ref);
    } catch (e, st) {
      AppLogger.instance.error(
        event: 'onboarding_step_load_failed',
        exception: e,
        stackTrace: st,
        fields: {'stepId': step.id},
      );
    }
  }
}
