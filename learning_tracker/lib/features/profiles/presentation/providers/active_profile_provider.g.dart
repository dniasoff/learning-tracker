// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the active profile ID for the current session.
///
/// Derives from [selectedProfileIdProvider] so that profile selection
/// in the ProfileGuard, ProfilePicker, and onboarding all flow through
/// to every data provider that watches this value.
///
/// `keepAlive` ensures the state survives route changes.
/// Default value 0 represents the legacy/default profile.

@ProviderFor(ActiveProfileId)
final activeProfileIdProvider = ActiveProfileIdProvider._();

/// Holds the active profile ID for the current session.
///
/// Derives from [selectedProfileIdProvider] so that profile selection
/// in the ProfileGuard, ProfilePicker, and onboarding all flow through
/// to every data provider that watches this value.
///
/// `keepAlive` ensures the state survives route changes.
/// Default value 0 represents the legacy/default profile.
final class ActiveProfileIdProvider
    extends $NotifierProvider<ActiveProfileId, int> {
  /// Holds the active profile ID for the current session.
  ///
  /// Derives from [selectedProfileIdProvider] so that profile selection
  /// in the ProfileGuard, ProfilePicker, and onboarding all flow through
  /// to every data provider that watches this value.
  ///
  /// `keepAlive` ensures the state survives route changes.
  /// Default value 0 represents the legacy/default profile.
  ActiveProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeProfileIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeProfileIdHash();

  @$internal
  @override
  ActiveProfileId create() => ActiveProfileId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$activeProfileIdHash() => r'ec2a0e8a8ae4a73c76255c022cabed165d1dc87d';

/// Holds the active profile ID for the current session.
///
/// Derives from [selectedProfileIdProvider] so that profile selection
/// in the ProfileGuard, ProfilePicker, and onboarding all flow through
/// to every data provider that watches this value.
///
/// `keepAlive` ensures the state survives route changes.
/// Default value 0 represents the legacy/default profile.

abstract class _$ActiveProfileId extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
