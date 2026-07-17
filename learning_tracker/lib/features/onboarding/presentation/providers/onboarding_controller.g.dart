// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod notifier that owns the step list and current position.
///
/// Constructed with an initial [steps] list. Consumers call [advance] /
/// [retreat] to move between steps. Each step's [OnboardingStep.save] is
/// called before advancing and [OnboardingStep.load] is called on the
/// incoming step.

@ProviderFor(OnboardingController)
final onboardingControllerProvider = OnboardingControllerProvider._();

/// Riverpod notifier that owns the step list and current position.
///
/// Constructed with an initial [steps] list. Consumers call [advance] /
/// [retreat] to move between steps. Each step's [OnboardingStep.save] is
/// called before advancing and [OnboardingStep.load] is called on the
/// incoming step.
final class OnboardingControllerProvider
    extends $NotifierProvider<OnboardingController, OnboardingControllerState> {
  /// Riverpod notifier that owns the step list and current position.
  ///
  /// Constructed with an initial [steps] list. Consumers call [advance] /
  /// [retreat] to move between steps. Each step's [OnboardingStep.save] is
  /// called before advancing and [OnboardingStep.load] is called on the
  /// incoming step.
  OnboardingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingControllerHash();

  @$internal
  @override
  OnboardingController create() => OnboardingController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnboardingControllerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnboardingControllerState>(value),
    );
  }
}

String _$onboardingControllerHash() =>
    r'f635c8e1031b0e3274994d82b133c432c89f7adb';

/// Riverpod notifier that owns the step list and current position.
///
/// Constructed with an initial [steps] list. Consumers call [advance] /
/// [retreat] to move between steps. Each step's [OnboardingStep.save] is
/// called before advancing and [OnboardingStep.load] is called on the
/// incoming step.

abstract class _$OnboardingController
    extends $Notifier<OnboardingControllerState> {
  OnboardingControllerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<OnboardingControllerState, OnboardingControllerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OnboardingControllerState, OnboardingControllerState>,
              OnboardingControllerState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
