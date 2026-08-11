// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the active profile's ULID (AD-24) for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active, returns the
/// talmid's own profileId directly — `hasActiveTutorAccess` grants the tutor
/// direct Firestore read/write on the talmid's tree, so there is no local
/// mirror to resolve. Otherwise delegates to [selectedProfileIdProvider]
/// (own profile).
///
/// `keepAlive` ensures the state survives route changes.
// keepAlive: read from many screens across navigation, must survive route/widget-tree changes.

@ProviderFor(ActiveProfileId)
final activeProfileIdProvider = ActiveProfileIdProvider._();

/// Holds the active profile's ULID (AD-24) for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active, returns the
/// talmid's own profileId directly — `hasActiveTutorAccess` grants the tutor
/// direct Firestore read/write on the talmid's tree, so there is no local
/// mirror to resolve. Otherwise delegates to [selectedProfileIdProvider]
/// (own profile).
///
/// `keepAlive` ensures the state survives route changes.
// keepAlive: read from many screens across navigation, must survive route/widget-tree changes.
final class ActiveProfileIdProvider
    extends $NotifierProvider<ActiveProfileId, String?> {
  /// Holds the active profile's ULID (AD-24) for the current session.
  ///
  /// Single chokepoint (§4.2): when a tutored selection is active, returns the
  /// talmid's own profileId directly — `hasActiveTutorAccess` grants the tutor
  /// direct Firestore read/write on the talmid's tree, so there is no local
  /// mirror to resolve. Otherwise delegates to [selectedProfileIdProvider]
  /// (own profile).
  ///
  /// `keepAlive` ensures the state survives route changes.
  // keepAlive: read from many screens across navigation, must survive route/widget-tree changes.
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
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeProfileIdHash() => r'c7bc17208ef813796456e1253ad3deac93f1496a';

/// Holds the active profile's ULID (AD-24) for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active, returns the
/// talmid's own profileId directly — `hasActiveTutorAccess` grants the tutor
/// direct Firestore read/write on the talmid's tree, so there is no local
/// mirror to resolve. Otherwise delegates to [selectedProfileIdProvider]
/// (own profile).
///
/// `keepAlive` ensures the state survives route changes.
// keepAlive: read from many screens across navigation, must survive route/widget-tree changes.

abstract class _$ActiveProfileId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The *active* profile — the identity the UI is currently rendering.
///
/// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
/// signed-in user's own chosen profile = the tutor in a tutored session), this
/// resolves through [activeProfileIdProvider]. In a tutored session that id is
/// the talmid's own profileId, so this returns the TALMID's profile — the
/// dashboard greeting must show the talmid's name and identity, not the
/// tutor's. Outside a tutored session it resolves to the same profile as
/// [selectedProfileProvider].

@ProviderFor(activeProfile)
final activeProfileProvider = ActiveProfileProvider._();

/// The *active* profile — the identity the UI is currently rendering.
///
/// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
/// signed-in user's own chosen profile = the tutor in a tutored session), this
/// resolves through [activeProfileIdProvider]. In a tutored session that id is
/// the talmid's own profileId, so this returns the TALMID's profile — the
/// dashboard greeting must show the talmid's name and identity, not the
/// tutor's. Outside a tutored session it resolves to the same profile as
/// [selectedProfileProvider].

final class ActiveProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<LearnerProfileEntity?>,
          LearnerProfileEntity?,
          FutureOr<LearnerProfileEntity?>
        >
    with
        $FutureModifier<LearnerProfileEntity?>,
        $FutureProvider<LearnerProfileEntity?> {
  /// The *active* profile — the identity the UI is currently rendering.
  ///
  /// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
  /// signed-in user's own chosen profile = the tutor in a tutored session), this
  /// resolves through [activeProfileIdProvider]. In a tutored session that id is
  /// the talmid's own profileId, so this returns the TALMID's profile — the
  /// dashboard greeting must show the talmid's name and identity, not the
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
  $FutureProviderElement<LearnerProfileEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LearnerProfileEntity?> create(Ref ref) {
    return activeProfile(ref);
  }
}

String _$activeProfileHash() => r'013819c68395dc2e1bf74cd9cbeb827b53c9da8e';
