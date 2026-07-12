// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Active account's DB file name — a mutable notifier so sign-in/signup
/// flows can swap accounts without a global side-effect.
///
/// Bootstrapped in `main.dart` via a [ProviderScope] override with the
/// value resolved by [bootstrapAccount]. Defaults to `'learning_tracker'`
/// so tests and fresh installs work without an override.
///
/// When the notifier's state changes, [userDatabaseProvider] rebuilds
/// automatically and opens the new database file.

@ProviderFor(AccountDbFileName)
final accountDbFileNameProvider = AccountDbFileNameProvider._();

/// Active account's DB file name — a mutable notifier so sign-in/signup
/// flows can swap accounts without a global side-effect.
///
/// Bootstrapped in `main.dart` via a [ProviderScope] override with the
/// value resolved by [bootstrapAccount]. Defaults to `'learning_tracker'`
/// so tests and fresh installs work without an override.
///
/// When the notifier's state changes, [userDatabaseProvider] rebuilds
/// automatically and opens the new database file.
final class AccountDbFileNameProvider
    extends $NotifierProvider<AccountDbFileName, String> {
  /// Active account's DB file name — a mutable notifier so sign-in/signup
  /// flows can swap accounts without a global side-effect.
  ///
  /// Bootstrapped in `main.dart` via a [ProviderScope] override with the
  /// value resolved by [bootstrapAccount]. Defaults to `'learning_tracker'`
  /// so tests and fresh installs work without an override.
  ///
  /// When the notifier's state changes, [userDatabaseProvider] rebuilds
  /// automatically and opens the new database file.
  AccountDbFileNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountDbFileNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountDbFileNameHash();

  @$internal
  @override
  AccountDbFileName create() => AccountDbFileName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$accountDbFileNameHash() => r'4033a3f9624cdea5594a62be6a8bb0ba60d715ba';

/// Active account's DB file name — a mutable notifier so sign-in/signup
/// flows can swap accounts without a global side-effect.
///
/// Bootstrapped in `main.dart` via a [ProviderScope] override with the
/// value resolved by [bootstrapAccount]. Defaults to `'learning_tracker'`
/// so tests and fresh installs work without an override.
///
/// When the notifier's state changes, [userDatabaseProvider] rebuilds
/// automatically and opens the new database file.

abstract class _$AccountDbFileName extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// User database — read-write, scoped to the active account.
///
/// Watches [accountDbFileNameProvider] so the database is automatically
/// swapped when a new account is selected during sign-in or sign-up.

@ProviderFor(userDatabase)
final userDatabaseProvider = UserDatabaseProvider._();

/// User database — read-write, scoped to the active account.
///
/// Watches [accountDbFileNameProvider] so the database is automatically
/// swapped when a new account is selected during sign-in or sign-up.

final class UserDatabaseProvider
    extends $FunctionalProvider<UserDatabase, UserDatabase, UserDatabase>
    with $Provider<UserDatabase> {
  /// User database — read-write, scoped to the active account.
  ///
  /// Watches [accountDbFileNameProvider] so the database is automatically
  /// swapped when a new account is selected during sign-in or sign-up.
  UserDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userDatabaseHash();

  @$internal
  @override
  $ProviderElement<UserDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserDatabase create(Ref ref) {
    return userDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserDatabase>(value),
    );
  }
}

String _$userDatabaseHash() => r'32a85d2484055a69ae0da3df23730d020ea762dd';

/// Filesystem path for the bundled content database.
///
/// Resolves the path by running [SeedManager.ensureContentDb] in the
/// background — decompresses the asset on first launch, no-ops on subsequent
/// launches. Runs independently of [runApp] so the UI is not blocked during
/// cold start (see bootstrap.dart).
///
/// Tests override [contentDatabaseProvider] directly with an in-memory DB and
/// never need to override this provider.

@ProviderFor(contentDbPath)
final contentDbPathProvider = ContentDbPathProvider._();

/// Filesystem path for the bundled content database.
///
/// Resolves the path by running [SeedManager.ensureContentDb] in the
/// background — decompresses the asset on first launch, no-ops on subsequent
/// launches. Runs independently of [runApp] so the UI is not blocked during
/// cold start (see bootstrap.dart).
///
/// Tests override [contentDatabaseProvider] directly with an in-memory DB and
/// never need to override this provider.

final class ContentDbPathProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Filesystem path for the bundled content database.
  ///
  /// Resolves the path by running [SeedManager.ensureContentDb] in the
  /// background — decompresses the asset on first launch, no-ops on subsequent
  /// launches. Runs independently of [runApp] so the UI is not blocked during
  /// cold start (see bootstrap.dart).
  ///
  /// Tests override [contentDatabaseProvider] directly with an in-memory DB and
  /// never need to override this provider.
  ContentDbPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentDbPathProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentDbPathHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return contentDbPath(ref);
  }
}

String _$contentDbPathHash() => r'26c2d81c42aeeb1e67d6f33ecee71a46819368e9';

/// Content database — read-only, bundled seed content.
///
/// Awaits [contentDbPathProvider] so extraction completes before the database
/// is opened. The first read after a fresh install/clear will suspend until
/// seeding finishes; subsequent launches return immediately (already extracted).
///
/// Tests typically override this with an in-memory database via
/// `createTestContentDatabase()` instead of relying on [contentDbPath].

@ProviderFor(contentDatabase)
final contentDatabaseProvider = ContentDatabaseProvider._();

/// Content database — read-only, bundled seed content.
///
/// Awaits [contentDbPathProvider] so extraction completes before the database
/// is opened. The first read after a fresh install/clear will suspend until
/// seeding finishes; subsequent launches return immediately (already extracted).
///
/// Tests typically override this with an in-memory database via
/// `createTestContentDatabase()` instead of relying on [contentDbPath].

final class ContentDatabaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentDatabase>,
          ContentDatabase,
          FutureOr<ContentDatabase>
        >
    with $FutureModifier<ContentDatabase>, $FutureProvider<ContentDatabase> {
  /// Content database — read-only, bundled seed content.
  ///
  /// Awaits [contentDbPathProvider] so extraction completes before the database
  /// is opened. The first read after a fresh install/clear will suspend until
  /// seeding finishes; subsequent launches return immediately (already extracted).
  ///
  /// Tests typically override this with an in-memory database via
  /// `createTestContentDatabase()` instead of relying on [contentDbPath].
  ContentDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentDatabaseHash();

  @$internal
  @override
  $FutureProviderElement<ContentDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentDatabase> create(Ref ref) {
    return contentDatabase(ref);
  }
}

String _$contentDatabaseHash() => r'6e7d8d35d2ce55fddbdad8d7e171cb517291d2ed';

/// Legacy alias — will be removed after full migration.
/// DO NOT use in new code.

@ProviderFor(appDatabase)
@Deprecated('Use userDatabaseProvider or contentDatabaseProvider instead')
final appDatabaseProvider = AppDatabaseProvider._();

/// Legacy alias — will be removed after full migration.
/// DO NOT use in new code.

@Deprecated('Use userDatabaseProvider or contentDatabaseProvider instead')
final class AppDatabaseProvider
    extends $FunctionalProvider<UserDatabase, UserDatabase, UserDatabase>
    with $Provider<UserDatabase> {
  /// Legacy alias — will be removed after full migration.
  /// DO NOT use in new code.
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<UserDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'fd3ef3312b58f507a312b4f704113db39080d95e';
