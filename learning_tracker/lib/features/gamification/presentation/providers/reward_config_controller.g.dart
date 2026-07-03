// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reward_config_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier that owns all mutable form state for [RewardConfigurationScreen].
///
/// The screen reads [state] reactively and calls the mutation methods below.
/// Dialog and SnackBar presentation remain in the screen because they require
/// a [BuildContext]; this notifier is pure data + async IO.

@ProviderFor(RewardConfigController)
final rewardConfigControllerProvider = RewardConfigControllerProvider._();

/// Notifier that owns all mutable form state for [RewardConfigurationScreen].
///
/// The screen reads [state] reactively and calls the mutation methods below.
/// Dialog and SnackBar presentation remain in the screen because they require
/// a [BuildContext]; this notifier is pure data + async IO.
final class RewardConfigControllerProvider
    extends $NotifierProvider<RewardConfigController, RewardForm> {
  /// Notifier that owns all mutable form state for [RewardConfigurationScreen].
  ///
  /// The screen reads [state] reactively and calls the mutation methods below.
  /// Dialog and SnackBar presentation remain in the screen because they require
  /// a [BuildContext]; this notifier is pure data + async IO.
  RewardConfigControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rewardConfigControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rewardConfigControllerHash();

  @$internal
  @override
  RewardConfigController create() => RewardConfigController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RewardForm value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RewardForm>(value),
    );
  }
}

String _$rewardConfigControllerHash() =>
    r'e13b59fa8fa1f4005eaf49f159511e4dda362722';

/// Notifier that owns all mutable form state for [RewardConfigurationScreen].
///
/// The screen reads [state] reactively and calls the mutation methods below.
/// Dialog and SnackBar presentation remain in the screen because they require
/// a [BuildContext]; this notifier is pure data + async IO.

abstract class _$RewardConfigController extends $Notifier<RewardForm> {
  RewardForm build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RewardForm, RewardForm>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RewardForm, RewardForm>,
              RewardForm,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
