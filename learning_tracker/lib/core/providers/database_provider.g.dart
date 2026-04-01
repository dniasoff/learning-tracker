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

/// Content database — read-only, bundled content.
///
/// In production, this opens a pre-built seed file. In tests, it uses
/// an in-memory database. The seed file is managed by SeedManager.

@ProviderFor(contentDatabase)
final contentDatabaseProvider = ContentDatabaseProvider._();

/// Content database — read-only, bundled content.
///
/// In production, this opens a pre-built seed file. In tests, it uses
/// an in-memory database. The seed file is managed by SeedManager.

final class ContentDatabaseProvider
    extends
        $FunctionalProvider<ContentDatabase, ContentDatabase, ContentDatabase>
    with $Provider<ContentDatabase> {
  /// Content database — read-only, bundled content.
  ///
  /// In production, this opens a pre-built seed file. In tests, it uses
  /// an in-memory database. The seed file is managed by SeedManager.
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

String _$contentDatabaseHash() => r'fa7e0c0e654297d8fc8daba72f7a97ed56854ddc';

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
