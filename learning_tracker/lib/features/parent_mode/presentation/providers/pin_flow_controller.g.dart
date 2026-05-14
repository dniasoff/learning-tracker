// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_flow_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod notifier that owns state transitions for the unified PIN flow.
///
/// A single instance is shared across the lifetime of [PinFlowScreen]. Call
/// [reset] whenever the screen mounts so that the correct initial [PinFlowStep]
/// is set for the active [PinFlowMode].
///
/// Lockout state is read directly from [PinService] (E25/DNI-339); the
/// controller surfaces `lockedOut` / `lockoutMinutes` into its own state so
/// that the UI can render the lockout panel without touching the service again.
///
/// keepAlive: true — the screen mounts a persistent subscription for the
/// duration of the PIN flow. Auto-dispose would tear down state mid-flow when
/// there is a momentary gap between widget rebuilds.

@ProviderFor(PinFlowController)
final pinFlowControllerProvider = PinFlowControllerProvider._();

/// Riverpod notifier that owns state transitions for the unified PIN flow.
///
/// A single instance is shared across the lifetime of [PinFlowScreen]. Call
/// [reset] whenever the screen mounts so that the correct initial [PinFlowStep]
/// is set for the active [PinFlowMode].
///
/// Lockout state is read directly from [PinService] (E25/DNI-339); the
/// controller surfaces `lockedOut` / `lockoutMinutes` into its own state so
/// that the UI can render the lockout panel without touching the service again.
///
/// keepAlive: true — the screen mounts a persistent subscription for the
/// duration of the PIN flow. Auto-dispose would tear down state mid-flow when
/// there is a momentary gap between widget rebuilds.
final class PinFlowControllerProvider
    extends $NotifierProvider<PinFlowController, PinFlowState> {
  /// Riverpod notifier that owns state transitions for the unified PIN flow.
  ///
  /// A single instance is shared across the lifetime of [PinFlowScreen]. Call
  /// [reset] whenever the screen mounts so that the correct initial [PinFlowStep]
  /// is set for the active [PinFlowMode].
  ///
  /// Lockout state is read directly from [PinService] (E25/DNI-339); the
  /// controller surfaces `lockedOut` / `lockoutMinutes` into its own state so
  /// that the UI can render the lockout panel without touching the service again.
  ///
  /// keepAlive: true — the screen mounts a persistent subscription for the
  /// duration of the PIN flow. Auto-dispose would tear down state mid-flow when
  /// there is a momentary gap between widget rebuilds.
  PinFlowControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pinFlowControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pinFlowControllerHash();

  @$internal
  @override
  PinFlowController create() => PinFlowController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PinFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PinFlowState>(value),
    );
  }
}

String _$pinFlowControllerHash() => r'644da93fd84f32384c03c2554eb1e6e27a533b25';

/// Riverpod notifier that owns state transitions for the unified PIN flow.
///
/// A single instance is shared across the lifetime of [PinFlowScreen]. Call
/// [reset] whenever the screen mounts so that the correct initial [PinFlowStep]
/// is set for the active [PinFlowMode].
///
/// Lockout state is read directly from [PinService] (E25/DNI-339); the
/// controller surfaces `lockedOut` / `lockoutMinutes` into its own state so
/// that the UI can render the lockout panel without touching the service again.
///
/// keepAlive: true — the screen mounts a persistent subscription for the
/// duration of the PIN flow. Auto-dispose would tear down state mid-flow when
/// there is a momentary gap between widget rebuilds.

abstract class _$PinFlowController extends $Notifier<PinFlowState> {
  PinFlowState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PinFlowState, PinFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PinFlowState, PinFlowState>,
              PinFlowState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
