// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for bookmark repository.

@ProviderFor(bookmarkRepository)
const bookmarkRepositoryProvider = BookmarkRepositoryProvider._();

/// Provider for bookmark repository.

final class BookmarkRepositoryProvider
    extends
        $FunctionalProvider<
          BookmarkRepository,
          BookmarkRepository,
          BookmarkRepository
        >
    with $Provider<BookmarkRepository> {
  /// Provider for bookmark repository.
  const BookmarkRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookmarkRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookmarkRepository create(Ref ref) {
    return bookmarkRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookmarkRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookmarkRepository>(value),
    );
  }
}

String _$bookmarkRepositoryHash() =>
    r'1dc7c265fc392cd7bd657f8cff22b8b44e75ed56';

/// Provider for a specific bookmark (curriculum + track).

@ProviderFor(bookmark)
const bookmarkProvider = BookmarkFamily._();

/// Provider for a specific bookmark (curriculum + track).

final class BookmarkProvider
    extends
        $FunctionalProvider<
          AsyncValue<BookmarkEntity?>,
          BookmarkEntity?,
          FutureOr<BookmarkEntity?>
        >
    with $FutureModifier<BookmarkEntity?>, $FutureProvider<BookmarkEntity?> {
  /// Provider for a specific bookmark (curriculum + track).
  const BookmarkProvider._({
    required BookmarkFamily super.from,
    required ({CurriculumId curriculumId, TrackType trackType}) super.argument,
  }) : super(
         retry: null,
         name: r'bookmarkProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookmarkHash();

  @override
  String toString() {
    return r'bookmarkProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<BookmarkEntity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BookmarkEntity?> create(Ref ref) {
    final argument =
        this.argument as ({CurriculumId curriculumId, TrackType trackType});
    return bookmark(
      ref,
      curriculumId: argument.curriculumId,
      trackType: argument.trackType,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BookmarkProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookmarkHash() => r'f8a7dad9951c687a64e69485e66de73addc2840f';

/// Provider for a specific bookmark (curriculum + track).

final class BookmarkFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<BookmarkEntity?>,
          ({CurriculumId curriculumId, TrackType trackType})
        > {
  const BookmarkFamily._()
    : super(
        retry: null,
        name: r'bookmarkProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for a specific bookmark (curriculum + track).

  BookmarkProvider call({
    required CurriculumId curriculumId,
    required TrackType trackType,
  }) => BookmarkProvider._(
    argument: (curriculumId: curriculumId, trackType: trackType),
    from: this,
  );

  @override
  String toString() => r'bookmarkProvider';
}

/// Provider for setting/updating a bookmark.

@ProviderFor(BookmarkController)
const bookmarkControllerProvider = BookmarkControllerProvider._();

/// Provider for setting/updating a bookmark.
final class BookmarkControllerProvider
    extends $AsyncNotifierProvider<BookmarkController, void> {
  /// Provider for setting/updating a bookmark.
  const BookmarkControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkControllerHash();

  @$internal
  @override
  BookmarkController create() => BookmarkController();
}

String _$bookmarkControllerHash() =>
    r'de3ba231a3b43cc6159dde82e96a8665673c535a';

/// Provider for setting/updating a bookmark.

abstract class _$BookmarkController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
