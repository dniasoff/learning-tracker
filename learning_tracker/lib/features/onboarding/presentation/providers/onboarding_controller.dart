import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_controller.g.dart';

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
      await steps[0].load(ref);
    }
  }

  /// Validate and save the current step, then move to the next one.
  ///
  /// Returns the validation error string if validation fails, or `null` on
  /// success. The caller should display the error to the user.
  Future<String?> advance() async {
    final current = state.currentStep;
    final error = current.validate(ref);
    if (error != null) return error;

    await current.save(ref);

    if (!state.hasNext) return null;

    final nextIndex = state.currentIndex + 1;
    state = state.copyWith(currentIndex: nextIndex);
    await state.steps[nextIndex].load(ref);
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
    await state.steps[index].load(ref);
  }
}
