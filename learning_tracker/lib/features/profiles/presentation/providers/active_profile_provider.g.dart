// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the active profile ID for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active and the
/// synthetic mirror has been populated ([resolvedTutoredLocalProfileIdProvider]
/// is non-null), returns the mirror's local id so the entire UI renders the
/// talmid.  Otherwise delegates to [selectedProfileIdProvider] (own profile).
///
/// `keepAlive` ensures the state survives route changes.
/// Default value 0 represents the legacy/default profile.

@ProviderFor(ActiveProfileId)
final activeProfileIdProvider = ActiveProfileIdProvider._();

/// Holds the active profile ID for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active and the
/// synthetic mirror has been populated ([resolvedTutoredLocalProfileIdProvider]
/// is non-null), returns the mirror's local id so the entire UI renders the
/// talmid.  Otherwise delegates to [selectedProfileIdProvider] (own profile).
///
/// `keepAlive` ensures the state survives route changes.
/// Default value 0 represents the legacy/default profile.
final class ActiveProfileIdProvider
    extends $NotifierProvider<ActiveProfileId, int> {
  /// Holds the active profile ID for the current session.
  ///
  /// Single chokepoint (§4.2): when a tutored selection is active and the
  /// synthetic mirror has been populated ([resolvedTutoredLocalProfileIdProvider]
  /// is non-null), returns the mirror's local id so the entire UI renders the
  /// talmid.  Otherwise delegates to [selectedProfileIdProvider] (own profile).
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

String _$activeProfileIdHash() => r'49a4f4b10a5f18e4a94fc8ad925448de982f8c66';

/// Holds the active profile ID for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active and the
/// synthetic mirror has been populated ([resolvedTutoredLocalProfileIdProvider]
/// is non-null), returns the mirror's local id so the entire UI renders the
/// talmid.  Otherwise delegates to [selectedProfileIdProvider] (own profile).
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
