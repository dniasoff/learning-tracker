// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the active profile ID for the current session.
///
/// All profile-scoped providers watch this value and rebuild when it changes.
/// Default value 0 represents the legacy/default profile.

@ProviderFor(ActiveProfileId)
final activeProfileIdProvider = ActiveProfileIdProvider._();

/// Holds the active profile ID for the current session.
///
/// All profile-scoped providers watch this value and rebuild when it changes.
/// Default value 0 represents the legacy/default profile.
final class ActiveProfileIdProvider
    extends $NotifierProvider<ActiveProfileId, int> {
  /// Holds the active profile ID for the current session.
  ///
  /// All profile-scoped providers watch this value and rebuild when it changes.
  /// Default value 0 represents the legacy/default profile.
  ActiveProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeProfileIdProvider',
        isAutoDispose: true,
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

String _$activeProfileIdHash() => r'0401aafd20f341b2f08d1a6d05189390cfb0eb79';

/// Holds the active profile ID for the current session.
///
/// All profile-scoped providers watch this value and rebuild when it changes.
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
