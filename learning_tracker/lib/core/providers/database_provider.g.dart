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
/// Overridden in `main.dart` with the path resolved by `SeedManager`
/// (Story 19.2b T13). Tests leave this unset and rely on the content
/// provider override with an in-memory database.

@ProviderFor(contentDbPath)
final contentDbPathProvider = ContentDbPathProvider._();

/// Filesystem path for the bundled content database.
///
/// Overridden in `main.dart` with the path resolved by `SeedManager`
/// (Story 19.2b T13). Tests leave this unset and rely on the content
/// provider override with an in-memory database.

final class ContentDbPathProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Filesystem path for the bundled content database.
  ///
  /// Overridden in `main.dart` with the path resolved by `SeedManager`
  /// (Story 19.2b T13). Tests leave this unset and rely on the content
  /// provider override with an in-memory database.
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
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return contentDbPath(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$contentDbPathHash() => r'99bbed4b861478949d2e31ae1d1d0b38e3494257';

/// Content database — read-only, bundled seed content.
///
/// Opens the content.db file prepared by [SeedManager] at startup with
/// `PRAGMA query_only = ON` enforced at the SQLite level (Story 19.3 AC-10).
/// Tests typically override this with an in-memory database via
/// `createTestContentDatabase()` instead of relying on [contentDbPath].

@ProviderFor(contentDatabase)
final contentDatabaseProvider = ContentDatabaseProvider._();

/// Content database — read-only, bundled seed content.
///
/// Opens the content.db file prepared by [SeedManager] at startup with
/// `PRAGMA query_only = ON` enforced at the SQLite level (Story 19.3 AC-10).
/// Tests typically override this with an in-memory database via
/// `createTestContentDatabase()` instead of relying on [contentDbPath].

final class ContentDatabaseProvider
    extends
        $FunctionalProvider<ContentDatabase, ContentDatabase, ContentDatabase>
    with $Provider<ContentDatabase> {
  /// Content database — read-only, bundled seed content.
  ///
  /// Opens the content.db file prepared by [SeedManager] at startup with
  /// `PRAGMA query_only = ON` enforced at the SQLite level (Story 19.3 AC-10).
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
  $ProviderElement<ContentDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ContentDatabase create(Ref ref) {
    return contentDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentDatabase>(value),
    );
  }
}

String _$contentDatabaseHash() => r'5a481a7eabbd43d69fd32007098cb4f89de96742';

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
