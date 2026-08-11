// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

String _$contentDatabaseHash() => r'3b0abd70c91e83caeb5640494bbbfffbc250b8ee';
