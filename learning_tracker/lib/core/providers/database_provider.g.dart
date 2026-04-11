// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// User database — read-write, all user data.

@ProviderFor(userDatabase)
final userDatabaseProvider = UserDatabaseProvider._();

/// User database — read-write, all user data.

final class UserDatabaseProvider
    extends $FunctionalProvider<UserDatabase, UserDatabase, UserDatabase>
    with $Provider<UserDatabase> {
  /// User database — read-write, all user data.
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

String _$userDatabaseHash() => r'b5b71185532a438393ea9db52f77a754de4b5050';

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
