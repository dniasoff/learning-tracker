// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the ProfileRepository implementation.
// keepAlive: stateless repository facade, cheap to keep for the app's lifetime.

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

/// Provider for the ProfileRepository implementation.
// keepAlive: stateless repository facade, cheap to keep for the app's lifetime.

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository,
          ProfileRepository,
          ProfileRepository
        >
    with $Provider<ProfileRepository> {
  /// Provider for the ProfileRepository implementation.
  // keepAlive: stateless repository facade, cheap to keep for the app's lifetime.
  ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository>(value),
    );
  }
}

String _$profileRepositoryHash() => r'303da1dcedb7739328ecf4ae8aec4589f4c6c305';

/// The currently selected profile's ULID (AD-24). Null means no profile
/// selected yet.
// keepAlive: the session's profile selection must survive route changes and unrelated rebuilds.

@ProviderFor(SelectedProfileId)
final selectedProfileIdProvider = SelectedProfileIdProvider._();

/// The currently selected profile's ULID (AD-24). Null means no profile
/// selected yet.
// keepAlive: the session's profile selection must survive route changes and unrelated rebuilds.
final class SelectedProfileIdProvider
    extends $NotifierProvider<SelectedProfileId, String?> {
  /// The currently selected profile's ULID (AD-24). Null means no profile
  /// selected yet.
  // keepAlive: the session's profile selection must survive route changes and unrelated rebuilds.
  SelectedProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedProfileIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedProfileIdHash();

  @$internal
  @override
  SelectedProfileId create() => SelectedProfileId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedProfileIdHash() => r'152b27f7bee397fa8d5db0b9871ad73031aecff5';

/// The currently selected profile's ULID (AD-24). Null means no profile
/// selected yet.
// keepAlive: the session's profile selection must survive route changes and unrelated rebuilds.

abstract class _$SelectedProfileId extends $Notifier<String?> {
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

/// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
///
/// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
/// session, the app skips the interactive sign-in flow (the only place that
/// otherwise calls `selectedProfileIdProvider.notifier.select(...)`, see
/// `sign_in_controller.dart`). Without this effect the in-memory
/// `selectedProfileIdProvider` stays `null`.
///
/// AUD-profiles-21 (SM-2 — provider `build` must be pure): the self-heal
/// logic lives in [ensureSelected], not `build()` — see `app_shell.dart`'s
/// post-frame auth-valid effect for the caller.
// keepAlive: the app shell triggers ensureSelected() once per auth transition, must survive unrelated rebuilds.

@ProviderFor(AutoSelectedProfileId)
final autoSelectedProfileIdProvider = AutoSelectedProfileIdProvider._();

/// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
///
/// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
/// session, the app skips the interactive sign-in flow (the only place that
/// otherwise calls `selectedProfileIdProvider.notifier.select(...)`, see
/// `sign_in_controller.dart`). Without this effect the in-memory
/// `selectedProfileIdProvider` stays `null`.
///
/// AUD-profiles-21 (SM-2 — provider `build` must be pure): the self-heal
/// logic lives in [ensureSelected], not `build()` — see `app_shell.dart`'s
/// post-frame auth-valid effect for the caller.
// keepAlive: the app shell triggers ensureSelected() once per auth transition, must survive unrelated rebuilds.
final class AutoSelectedProfileIdProvider
    extends $AsyncNotifierProvider<AutoSelectedProfileId, String?> {
  /// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
  ///
  /// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
  /// session, the app skips the interactive sign-in flow (the only place that
  /// otherwise calls `selectedProfileIdProvider.notifier.select(...)`, see
  /// `sign_in_controller.dart`). Without this effect the in-memory
  /// `selectedProfileIdProvider` stays `null`.
  ///
  /// AUD-profiles-21 (SM-2 — provider `build` must be pure): the self-heal
  /// logic lives in [ensureSelected], not `build()` — see `app_shell.dart`'s
  /// post-frame auth-valid effect for the caller.
  // keepAlive: the app shell triggers ensureSelected() once per auth transition, must survive unrelated rebuilds.
  AutoSelectedProfileIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'autoSelectedProfileIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$autoSelectedProfileIdHash();

  @$internal
  @override
  AutoSelectedProfileId create() => AutoSelectedProfileId();
}

String _$autoSelectedProfileIdHash() =>
    r'64fd1d4886985c484f49a8d1d1518b0f62d0b1b3';

/// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
///
/// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
/// session, the app skips the interactive sign-in flow (the only place that
/// otherwise calls `selectedProfileIdProvider.notifier.select(...)`, see
/// `sign_in_controller.dart`). Without this effect the in-memory
/// `selectedProfileIdProvider` stays `null`.
///
/// AUD-profiles-21 (SM-2 — provider `build` must be pure): the self-heal
/// logic lives in [ensureSelected], not `build()` — see `app_shell.dart`'s
/// post-frame auth-valid effect for the caller.
// keepAlive: the app shell triggers ensureSelected() once per auth transition, must survive unrelated rebuilds.

abstract class _$AutoSelectedProfileId extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Profiles for the active account.

@ProviderFor(profileList)
final profileListProvider = ProfileListProvider._();

/// Profiles for the active account.

final class ProfileListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LearnerProfileEntity>>,
          List<LearnerProfileEntity>,
          FutureOr<List<LearnerProfileEntity>>
        >
    with
        $FutureModifier<List<LearnerProfileEntity>>,
        $FutureProvider<List<LearnerProfileEntity>> {
  /// Profiles for the active account.
  ProfileListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileListHash();

  @$internal
  @override
  $FutureProviderElement<List<LearnerProfileEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LearnerProfileEntity>> create(Ref ref) {
    return profileList(ref);
  }
}

String _$profileListHash() => r'2b464a9964d99a4b8a2793bd5be0cefa2fec5de0';

/// Stream of profiles for the active account, for reactive UI.

@ProviderFor(profileListStream)
final profileListStreamProvider = ProfileListStreamProvider._();

/// Stream of profiles for the active account, for reactive UI.

final class ProfileListStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LearnerProfileEntity>>,
          List<LearnerProfileEntity>,
          Stream<List<LearnerProfileEntity>>
        >
    with
        $FutureModifier<List<LearnerProfileEntity>>,
        $StreamProvider<List<LearnerProfileEntity>> {
  /// Stream of profiles for the active account, for reactive UI.
  ProfileListStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileListStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileListStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<LearnerProfileEntity>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LearnerProfileEntity>> create(Ref ref) {
    return profileListStream(ref);
  }
}

String _$profileListStreamHash() => r'aee5b5766ce3a8c977e97ab641ba6e8c39184e00';

/// The currently selected profile.

@ProviderFor(selectedProfile)
final selectedProfileProvider = SelectedProfileProvider._();

/// The currently selected profile.

final class SelectedProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<LearnerProfileEntity?>,
          LearnerProfileEntity?,
          FutureOr<LearnerProfileEntity?>
        >
    with
        $FutureModifier<LearnerProfileEntity?>,
        $FutureProvider<LearnerProfileEntity?> {
  /// The currently selected profile.
  SelectedProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedProfileHash();

  @$internal
  @override
  $FutureProviderElement<LearnerProfileEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LearnerProfileEntity?> create(Ref ref) {
    return selectedProfile(ref);
  }
}

String _$selectedProfileHash() => r'faf12901a6c123d1c1183bf8e62b902aa50caf85';

/// The active profile session as a typed domain aggregate.
///
/// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers talk
/// about "a session" rather than a nullable String. This is the canonical
/// read path for profile-selection state; write path stays on
/// `selectedProfileIdProvider.notifier` (select / clear).
// keepAlive: wraps selectedProfileIdProvider, which is itself keepAlive — must not defeat that.

@ProviderFor(profileSession)
final profileSessionProvider = ProfileSessionProvider._();

/// The active profile session as a typed domain aggregate.
///
/// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers talk
/// about "a session" rather than a nullable String. This is the canonical
/// read path for profile-selection state; write path stays on
/// `selectedProfileIdProvider.notifier` (select / clear).
// keepAlive: wraps selectedProfileIdProvider, which is itself keepAlive — must not defeat that.

final class ProfileSessionProvider
    extends $FunctionalProvider<ProfileSession, ProfileSession, ProfileSession>
    with $Provider<ProfileSession> {
  /// The active profile session as a typed domain aggregate.
  ///
  /// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers talk
  /// about "a session" rather than a nullable String. This is the canonical
  /// read path for profile-selection state; write path stays on
  /// `selectedProfileIdProvider.notifier` (select / clear).
  // keepAlive: wraps selectedProfileIdProvider, which is itself keepAlive — must not defeat that.
  ProfileSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileSessionHash();

  @$internal
  @override
  $ProviderElement<ProfileSession> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProfileSession create(Ref ref) {
    return profileSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileSession value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileSession>(value),
    );
  }
}

String _$profileSessionHash() => r'd0706e695f8d6717d283d7d665c1aa1f7bd0937a';
