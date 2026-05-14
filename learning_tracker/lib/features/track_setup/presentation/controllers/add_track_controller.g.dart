// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_track_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// State-machine controller for the Add Track wizard.
///
/// Manages [AddTrackFlowState] (navigation) and the accumulated
/// [AddTrackState] form data as the user progresses through steps.
///
/// Scoped per `(profileId, isOnboarding)` via a Riverpod family so that
/// separate invocations (onboarding vs settings) maintain independent state.

@ProviderFor(AddTrackController)
final addTrackControllerProvider = AddTrackControllerFamily._();

/// State-machine controller for the Add Track wizard.
///
/// Manages [AddTrackFlowState] (navigation) and the accumulated
/// [AddTrackState] form data as the user progresses through steps.
///
/// Scoped per `(profileId, isOnboarding)` via a Riverpod family so that
/// separate invocations (onboarding vs settings) maintain independent state.
final class AddTrackControllerProvider
    extends $NotifierProvider<AddTrackController, AddTrackFlowState> {
  /// State-machine controller for the Add Track wizard.
  ///
  /// Manages [AddTrackFlowState] (navigation) and the accumulated
  /// [AddTrackState] form data as the user progresses through steps.
  ///
  /// Scoped per `(profileId, isOnboarding)` via a Riverpod family so that
  /// separate invocations (onboarding vs settings) maintain independent state.
  AddTrackControllerProvider._({
    required AddTrackControllerFamily super.from,
    required (int, {bool isOnboarding}) super.argument,
  }) : super(
         retry: null,
         name: r'addTrackControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$addTrackControllerHash();

  @override
  String toString() {
    return r'addTrackControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  AddTrackController create() => AddTrackController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddTrackFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddTrackFlowState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AddTrackControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$addTrackControllerHash() =>
    r'1fea8b8b0b1969a5945944fe77c6b7e9f45fb583';

/// State-machine controller for the Add Track wizard.
///
/// Manages [AddTrackFlowState] (navigation) and the accumulated
/// [AddTrackState] form data as the user progresses through steps.
///
/// Scoped per `(profileId, isOnboarding)` via a Riverpod family so that
/// separate invocations (onboarding vs settings) maintain independent state.

final class AddTrackControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          AddTrackController,
          AddTrackFlowState,
          AddTrackFlowState,
          AddTrackFlowState,
          (int, {bool isOnboarding})
        > {
  AddTrackControllerFamily._()
    : super(
        retry: null,
        name: r'addTrackControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// State-machine controller for the Add Track wizard.
  ///
  /// Manages [AddTrackFlowState] (navigation) and the accumulated
  /// [AddTrackState] form data as the user progresses through steps.
  ///
  /// Scoped per `(profileId, isOnboarding)` via a Riverpod family so that
  /// separate invocations (onboarding vs settings) maintain independent state.

  AddTrackControllerProvider call(
    int profileId, {
    required bool isOnboarding,
  }) => AddTrackControllerProvider._(
    argument: (profileId, isOnboarding: isOnboarding),
    from: this,
  );

  @override
  String toString() => r'addTrackControllerProvider';
}

/// State-machine controller for the Add Track wizard.
///
/// Manages [AddTrackFlowState] (navigation) and the accumulated
/// [AddTrackState] form data as the user progresses through steps.
///
/// Scoped per `(profileId, isOnboarding)` via a Riverpod family so that
/// separate invocations (onboarding vs settings) maintain independent state.

abstract class _$AddTrackController extends $Notifier<AddTrackFlowState> {
  late final _$args = ref.$arg as (int, {bool isOnboarding});
  int get profileId => _$args.$1;
  bool get isOnboarding => _$args.isOnboarding;

  AddTrackFlowState build(int profileId, {required bool isOnboarding});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AddTrackFlowState, AddTrackFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AddTrackFlowState, AddTrackFlowState>,
              AddTrackFlowState,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(_$args.$1, isOnboarding: _$args.isOnboarding),
    );
  }
}
