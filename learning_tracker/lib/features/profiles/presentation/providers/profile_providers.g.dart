// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active account's local `accounts.id` within the currently-mounted
/// per-account user DB (FR22, Story 25.21).
///
/// Resolves from [authStateProvider] — when a user is signed-in, the
/// `currentUser.profileId` is the int FK that `learner_profiles.accountId`
/// and the snapshot collections key off. Falls back to `1` during the
/// brief signed-out window (e.g. between sign-up and the
/// `setLocalBornSession` call that lands onboarding) so DAO calls that
/// happen before auth-state settles keep their previous behavior.

@ProviderFor(currentAccountId)
final currentAccountIdProvider = CurrentAccountIdProvider._();

/// The active account's local `accounts.id` within the currently-mounted
/// per-account user DB (FR22, Story 25.21).
///
/// Resolves from [authStateProvider] — when a user is signed-in, the
/// `currentUser.profileId` is the int FK that `learner_profiles.accountId`
/// and the snapshot collections key off. Falls back to `1` during the
/// brief signed-out window (e.g. between sign-up and the
/// `setLocalBornSession` call that lands onboarding) so DAO calls that
/// happen before auth-state settles keep their previous behavior.

final class CurrentAccountIdProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// The active account's local `accounts.id` within the currently-mounted
  /// per-account user DB (FR22, Story 25.21).
  ///
  /// Resolves from [authStateProvider] — when a user is signed-in, the
  /// `currentUser.profileId` is the int FK that `learner_profiles.accountId`
  /// and the snapshot collections key off. Falls back to `1` during the
  /// brief signed-out window (e.g. between sign-up and the
  /// `setLocalBornSession` call that lands onboarding) so DAO calls that
  /// happen before auth-state settles keep their previous behavior.
  CurrentAccountIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentAccountIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentAccountIdHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return currentAccountId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$currentAccountIdHash() => r'49a36871feb359d35d08592973d7e6ceb9282cec';

/// Provider for the ProfileRepository implementation.

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

/// Provider for the ProfileRepository implementation.

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository,
          ProfileRepository,
          ProfileRepository
        >
    with $Provider<ProfileRepository> {
  /// Provider for the ProfileRepository implementation.
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

String _$profileRepositoryHash() => r'c9296d2f6106fde461c56e63533441e6ca991519';

/// The currently selected profile ID. Null means no profile selected yet.

@ProviderFor(SelectedProfileId)
final selectedProfileIdProvider = SelectedProfileIdProvider._();

/// The currently selected profile ID. Null means no profile selected yet.
final class SelectedProfileIdProvider
    extends $NotifierProvider<SelectedProfileId, int?> {
  /// The currently selected profile ID. Null means no profile selected yet.
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
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$selectedProfileIdHash() => r'7b2ad48d035d9a0a6211950b76474f43941d5d66';

/// The currently selected profile ID. Null means no profile selected yet.

abstract class _$SelectedProfileId extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
///
/// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
/// session, the app skips the interactive sign-in flow (which is the only
/// place that calls `selectedProfileIdProvider.notifier.select(...)`, see
/// `sign_in_controller.dart`). Without this effect the in-memory
/// `selectedProfileIdProvider` stays `null`, so `activeProfileIdProvider`
/// returns `0` and any write into a `profile_id`-FK'd table (e.g.
/// `stage_definitions` during track creation) fails with
/// `SqliteException(787): FOREIGN KEY constraint failed`.
///
/// Mirrors the single-profile branch of `_navigateAfterSignIn` (line ~536 of
/// sign_in_controller): whenever auth transitions to signed-in AND no profile
/// is selected yet, select the account's first profile.
///
/// BUG D1 (round 2 — the real crux): the previous fix only handled the case
/// where ≥1 profile already existed. This account (a cloud account whose
/// profiles never materialised locally — restored / skipped-onboarding) has
/// ZERO rows in `learner_profiles`, so `profiles.first` had nothing to select
/// and `profileId` stayed `0`. An authenticated account must NEVER operate at
/// `profile_id = 0`. So when the account has no profile we self-heal by
/// creating a default adult profile (and adopting any orphaned `profile_id = 0`
/// rows, e.g. a pre-existing track) and select it. After this an authenticated
/// account always has ≥1 profile selected.
///
/// Watched by the app shell so it runs on every auth-valid mount. Returns the
/// id that was selected (existing or newly healed), or null when signed-out.

@ProviderFor(autoSelectedProfileId)
final autoSelectedProfileIdProvider = AutoSelectedProfileIdProvider._();

/// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
///
/// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
/// session, the app skips the interactive sign-in flow (which is the only
/// place that calls `selectedProfileIdProvider.notifier.select(...)`, see
/// `sign_in_controller.dart`). Without this effect the in-memory
/// `selectedProfileIdProvider` stays `null`, so `activeProfileIdProvider`
/// returns `0` and any write into a `profile_id`-FK'd table (e.g.
/// `stage_definitions` during track creation) fails with
/// `SqliteException(787): FOREIGN KEY constraint failed`.
///
/// Mirrors the single-profile branch of `_navigateAfterSignIn` (line ~536 of
/// sign_in_controller): whenever auth transitions to signed-in AND no profile
/// is selected yet, select the account's first profile.
///
/// BUG D1 (round 2 — the real crux): the previous fix only handled the case
/// where ≥1 profile already existed. This account (a cloud account whose
/// profiles never materialised locally — restored / skipped-onboarding) has
/// ZERO rows in `learner_profiles`, so `profiles.first` had nothing to select
/// and `profileId` stayed `0`. An authenticated account must NEVER operate at
/// `profile_id = 0`. So when the account has no profile we self-heal by
/// creating a default adult profile (and adopting any orphaned `profile_id = 0`
/// rows, e.g. a pre-existing track) and select it. After this an authenticated
/// account always has ≥1 profile selected.
///
/// Watched by the app shell so it runs on every auth-valid mount. Returns the
/// id that was selected (existing or newly healed), or null when signed-out.

final class AutoSelectedProfileIdProvider
    extends $FunctionalProvider<AsyncValue<int?>, int?, FutureOr<int?>>
    with $FutureModifier<int?>, $FutureProvider<int?> {
  /// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
  ///
  /// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
  /// session, the app skips the interactive sign-in flow (which is the only
  /// place that calls `selectedProfileIdProvider.notifier.select(...)`, see
  /// `sign_in_controller.dart`). Without this effect the in-memory
  /// `selectedProfileIdProvider` stays `null`, so `activeProfileIdProvider`
  /// returns `0` and any write into a `profile_id`-FK'd table (e.g.
  /// `stage_definitions` during track creation) fails with
  /// `SqliteException(787): FOREIGN KEY constraint failed`.
  ///
  /// Mirrors the single-profile branch of `_navigateAfterSignIn` (line ~536 of
  /// sign_in_controller): whenever auth transitions to signed-in AND no profile
  /// is selected yet, select the account's first profile.
  ///
  /// BUG D1 (round 2 — the real crux): the previous fix only handled the case
  /// where ≥1 profile already existed. This account (a cloud account whose
  /// profiles never materialised locally — restored / skipped-onboarding) has
  /// ZERO rows in `learner_profiles`, so `profiles.first` had nothing to select
  /// and `profileId` stayed `0`. An authenticated account must NEVER operate at
  /// `profile_id = 0`. So when the account has no profile we self-heal by
  /// creating a default adult profile (and adopting any orphaned `profile_id = 0`
  /// rows, e.g. a pre-existing track) and select it. After this an authenticated
  /// account always has ≥1 profile selected.
  ///
  /// Watched by the app shell so it runs on every auth-valid mount. Returns the
  /// id that was selected (existing or newly healed), or null when signed-out.
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
  $FutureProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int?> create(Ref ref) {
    return autoSelectedProfileId(ref);
  }
}

String _$autoSelectedProfileIdHash() =>
    r'fc440350742743f450e4f2c74d3d82f51948e488';

/// Profiles for the current account.

@ProviderFor(profileList)
final profileListProvider = ProfileListProvider._();

/// Profiles for the current account.

final class ProfileListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProfileModel>>,
          List<ProfileModel>,
          FutureOr<List<ProfileModel>>
        >
    with
        $FutureModifier<List<ProfileModel>>,
        $FutureProvider<List<ProfileModel>> {
  /// Profiles for the current account.
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
  $FutureProviderElement<List<ProfileModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProfileModel>> create(Ref ref) {
    return profileList(ref);
  }
}

String _$profileListHash() => r'4fa991a4edbce8afb13b4f3100fbce120d6b59a8';

/// Stream of profiles for the current account, for reactive UI.

@ProviderFor(profileListStream)
final profileListStreamProvider = ProfileListStreamProvider._();

/// Stream of profiles for the current account, for reactive UI.

final class ProfileListStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProfileModel>>,
          List<ProfileModel>,
          Stream<List<ProfileModel>>
        >
    with
        $FutureModifier<List<ProfileModel>>,
        $StreamProvider<List<ProfileModel>> {
  /// Stream of profiles for the current account, for reactive UI.
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
  $StreamProviderElement<List<ProfileModel>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProfileModel>> create(Ref ref) {
    return profileListStream(ref);
  }
}

String _$profileListStreamHash() => r'62745f3bc8d57d10a2c1a4627f104b0a60b9f404';

/// The currently selected profile model.

@ProviderFor(selectedProfile)
final selectedProfileProvider = SelectedProfileProvider._();

/// The currently selected profile model.

final class SelectedProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileModel?>,
          ProfileModel?,
          FutureOr<ProfileModel?>
        >
    with $FutureModifier<ProfileModel?>, $FutureProvider<ProfileModel?> {
  /// The currently selected profile model.
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
  $FutureProviderElement<ProfileModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileModel?> create(Ref ref) {
    return selectedProfile(ref);
  }
}

String _$selectedProfileHash() => r'b66d723d4e6e5829b73400bb6febf572535e6e4f';

/// The active profile session as a typed domain aggregate.
///
/// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers
/// talk about "a session" rather than a nullable integer. This is the
/// canonical read path for profile-selection state; write path stays on
/// `selectedProfileIdProvider.notifier` (select / clear).

@ProviderFor(profileSession)
final profileSessionProvider = ProfileSessionProvider._();

/// The active profile session as a typed domain aggregate.
///
/// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers
/// talk about "a session" rather than a nullable integer. This is the
/// canonical read path for profile-selection state; write path stays on
/// `selectedProfileIdProvider.notifier` (select / clear).

final class ProfileSessionProvider
    extends $FunctionalProvider<ProfileSession, ProfileSession, ProfileSession>
    with $Provider<ProfileSession> {
  /// The active profile session as a typed domain aggregate.
  ///
  /// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers
  /// talk about "a session" rather than a nullable integer. This is the
  /// canonical read path for profile-selection state; write path stays on
  /// `selectedProfileIdProvider.notifier` (select / clear).
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

String _$profileSessionHash() => r'da5f63dda22c5030184d117a52ae744f61055dba';
