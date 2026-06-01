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

/// The *active* profile model — the identity the UI is currently rendering.
///
/// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
/// signed-in user's own chosen profile = the tutor in a tutored session), this
/// resolves through [activeProfileIdProvider]. In a tutored session that id is
/// the talmid's synthetic local mirror, so this returns the TALMID's profile —
/// the dashboard greeting must show the talmid's name and identity, not the
/// tutor's. Outside a tutored session it resolves to the same profile as
/// [selectedProfileProvider].

@ProviderFor(activeProfile)
final activeProfileProvider = ActiveProfileProvider._();

/// The *active* profile model — the identity the UI is currently rendering.
///
/// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
/// signed-in user's own chosen profile = the tutor in a tutored session), this
/// resolves through [activeProfileIdProvider]. In a tutored session that id is
/// the talmid's synthetic local mirror, so this returns the TALMID's profile —
/// the dashboard greeting must show the talmid's name and identity, not the
/// tutor's. Outside a tutored session it resolves to the same profile as
/// [selectedProfileProvider].

final class ActiveProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileModel?>,
          ProfileModel?,
          FutureOr<ProfileModel?>
        >
    with $FutureModifier<ProfileModel?>, $FutureProvider<ProfileModel?> {
  /// The *active* profile model — the identity the UI is currently rendering.
  ///
  /// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
  /// signed-in user's own chosen profile = the tutor in a tutored session), this
  /// resolves through [activeProfileIdProvider]. In a tutored session that id is
  /// the talmid's synthetic local mirror, so this returns the TALMID's profile —
  /// the dashboard greeting must show the talmid's name and identity, not the
  /// tutor's. Outside a tutored session it resolves to the same profile as
  /// [selectedProfileProvider].
  ActiveProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeProfileHash();

  @$internal
  @override
  $FutureProviderElement<ProfileModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileModel?> create(Ref ref) {
    return activeProfile(ref);
  }
}

String _$activeProfileHash() => r'2cc33760c30e87d3f44166ceb5dd45fc61a3a848';
