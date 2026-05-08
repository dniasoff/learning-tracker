// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the content repository (singleton).
///
/// keepAlive: true ensures the in-memory content cache persists for the
/// lifetime of the app — rebuilding this provider would discard cached data.
/// Loads hierarchy content from bundled assets.

@ProviderFor(contentRepository)
final contentRepositoryProvider = ContentRepositoryProvider._();

/// Provides the content repository (singleton).
///
/// keepAlive: true ensures the in-memory content cache persists for the
/// lifetime of the app — rebuilding this provider would discard cached data.
/// Loads hierarchy content from bundled assets.

final class ContentRepositoryProvider
    extends
        $FunctionalProvider<
          ContentRepository,
          ContentRepository,
          ContentRepository
        >
    with $Provider<ContentRepository> {
  /// Provides the content repository (singleton).
  ///
  /// keepAlive: true ensures the in-memory content cache persists for the
  /// lifetime of the app — rebuilding this provider would discard cached data.
  /// Loads hierarchy content from bundled assets.
  ContentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentRepositoryHash();

  @$internal
  @override
  $ProviderElement<ContentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContentRepository create(Ref ref) {
    return contentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContentRepository>(value),
    );
  }
}

String _$contentRepositoryHash() => r'15a1d1414ef5a187fe197e36f9f9779b55f85fb5';

/// Provides all content items for a specific curriculum (family provider).

@ProviderFor(curriculumContent)
final curriculumContentProvider = CurriculumContentFamily._();

/// Provides all content items for a specific curriculum (family provider).

final class CurriculumContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContentItem>>,
          List<ContentItem>,
          FutureOr<List<ContentItem>>
        >
    with
        $FutureModifier<List<ContentItem>>,
        $FutureProvider<List<ContentItem>> {
  /// Provides all content items for a specific curriculum (family provider).
  CurriculumContentProvider._({
    required CurriculumContentFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'curriculumContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curriculumContentHash();

  @override
  String toString() {
    return r'curriculumContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContentItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContentItem>> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return curriculumContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CurriculumContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curriculumContentHash() => r'b9700b7cebfed94be143af59090f0666d28121b7';

/// Provides all content items for a specific curriculum (family provider).

final class CurriculumContentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ContentItem>>, CurriculumId> {
  CurriculumContentFamily._()
    : super(
        retry: null,
        name: r'curriculumContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides all content items for a specific curriculum (family provider).

  CurriculumContentProvider call(CurriculumId curriculumId) =>
      CurriculumContentProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumContentProvider';
}

/// Map of `sefariaRef → displayNameHe` for every leaf in [curriculumId].
///
/// Lets widgets that have a Sefaria ref (daily-task cards, completion
/// history, etc.) show the canonical Hebrew form when Hebrew Terms is on,
/// without having to plumb the Hebrew name through the model layer.

@ProviderFor(curriculumHeNames)
final curriculumHeNamesProvider = CurriculumHeNamesFamily._();

/// Map of `sefariaRef → displayNameHe` for every leaf in [curriculumId].
///
/// Lets widgets that have a Sefaria ref (daily-task cards, completion
/// history, etc.) show the canonical Hebrew form when Hebrew Terms is on,
/// without having to plumb the Hebrew name through the model layer.

final class CurriculumHeNamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// Map of `sefariaRef → displayNameHe` for every leaf in [curriculumId].
  ///
  /// Lets widgets that have a Sefaria ref (daily-task cards, completion
  /// history, etc.) show the canonical Hebrew form when Hebrew Terms is on,
  /// without having to plumb the Hebrew name through the model layer.
  CurriculumHeNamesProvider._({
    required CurriculumHeNamesFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'curriculumHeNamesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curriculumHeNamesHash();

  @override
  String toString() {
    return r'curriculumHeNamesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return curriculumHeNames(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CurriculumHeNamesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curriculumHeNamesHash() => r'33bd58d7620e0125654dcbfe883676f9b8503958';

/// Map of `sefariaRef → displayNameHe` for every leaf in [curriculumId].
///
/// Lets widgets that have a Sefaria ref (daily-task cards, completion
/// history, etc.) show the canonical Hebrew form when Hebrew Terms is on,
/// without having to plumb the Hebrew name through the model layer.

final class CurriculumHeNamesFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<Map<String, String>>, CurriculumId> {
  CurriculumHeNamesFamily._()
    : super(
        retry: null,
        name: r'curriculumHeNamesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Map of `sefariaRef → displayNameHe` for every leaf in [curriculumId].
  ///
  /// Lets widgets that have a Sefaria ref (daily-task cards, completion
  /// history, etc.) show the canonical Hebrew form when Hebrew Terms is on,
  /// without having to plumb the Hebrew name through the model layer.

  CurriculumHeNamesProvider call(CurriculumId curriculumId) =>
      CurriculumHeNamesProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumHeNamesProvider';
}

/// Provides the hierarchy configuration for a specific curriculum.

@ProviderFor(curriculumHierarchyConfig)
final curriculumHierarchyConfigProvider = CurriculumHierarchyConfigFamily._();

/// Provides the hierarchy configuration for a specific curriculum.

final class CurriculumHierarchyConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<CurriculumHierarchyConfig>,
          CurriculumHierarchyConfig,
          FutureOr<CurriculumHierarchyConfig>
        >
    with
        $FutureModifier<CurriculumHierarchyConfig>,
        $FutureProvider<CurriculumHierarchyConfig> {
  /// Provides the hierarchy configuration for a specific curriculum.
  CurriculumHierarchyConfigProvider._({
    required CurriculumHierarchyConfigFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'curriculumHierarchyConfigProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$curriculumHierarchyConfigHash();

  @override
  String toString() {
    return r'curriculumHierarchyConfigProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CurriculumHierarchyConfig> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CurriculumHierarchyConfig> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return curriculumHierarchyConfig(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CurriculumHierarchyConfigProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$curriculumHierarchyConfigHash() =>
    r'f1e4bec4a97cda68d4f291280cff6fbeb0c42297';

/// Provides the hierarchy configuration for a specific curriculum.

final class CurriculumHierarchyConfigFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<CurriculumHierarchyConfig>,
          CurriculumId
        > {
  CurriculumHierarchyConfigFamily._()
    : super(
        retry: null,
        name: r'curriculumHierarchyConfigProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides the hierarchy configuration for a specific curriculum.

  CurriculumHierarchyConfigProvider call(CurriculumId curriculumId) =>
      CurriculumHierarchyConfigProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'curriculumHierarchyConfigProvider';
}

/// Provides filtered content by hierarchy level.

@ProviderFor(filteredContent)
final filteredContentProvider = FilteredContentFamily._();

/// Provides filtered content by hierarchy level.

final class FilteredContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContentItem>>,
          List<ContentItem>,
          FutureOr<List<ContentItem>>
        >
    with
        $FutureModifier<List<ContentItem>>,
        $FutureProvider<List<ContentItem>> {
  /// Provides filtered content by hierarchy level.
  FilteredContentProvider._({
    required FilteredContentFamily super.from,
    required ({
      CurriculumId curriculumId,
      String? level1,
      String? level2,
      String? level3,
      String? level4,
    })
    super.argument,
  }) : super(
         retry: null,
         name: r'filteredContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$filteredContentHash();

  @override
  String toString() {
    return r'filteredContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContentItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContentItem>> create(Ref ref) {
    final argument =
        this.argument
            as ({
              CurriculumId curriculumId,
              String? level1,
              String? level2,
              String? level3,
              String? level4,
            });
    return filteredContent(
      ref,
      curriculumId: argument.curriculumId,
      level1: argument.level1,
      level2: argument.level2,
      level3: argument.level3,
      level4: argument.level4,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FilteredContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$filteredContentHash() => r'7048fbc2d1817b1cdfd70140f6285148970752d2';

/// Provides filtered content by hierarchy level.

final class FilteredContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ContentItem>>,
          ({
            CurriculumId curriculumId,
            String? level1,
            String? level2,
            String? level3,
            String? level4,
          })
        > {
  FilteredContentFamily._()
    : super(
        retry: null,
        name: r'filteredContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides filtered content by hierarchy level.

  FilteredContentProvider call({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) => FilteredContentProvider._(
    argument: (
      curriculumId: curriculumId,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
    ),
    from: this,
  );

  @override
  String toString() => r'filteredContentProvider';
}

/// Provides search results for a curriculum.

@ProviderFor(contentSearch)
final contentSearchProvider = ContentSearchFamily._();

/// Provides search results for a curriculum.

final class ContentSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ContentItem>>,
          List<ContentItem>,
          FutureOr<List<ContentItem>>
        >
    with
        $FutureModifier<List<ContentItem>>,
        $FutureProvider<List<ContentItem>> {
  /// Provides search results for a curriculum.
  ContentSearchProvider._({
    required ContentSearchFamily super.from,
    required ({CurriculumId curriculumId, String query}) super.argument,
  }) : super(
         retry: null,
         name: r'contentSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contentSearchHash();

  @override
  String toString() {
    return r'contentSearchProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ContentItem>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ContentItem>> create(Ref ref) {
    final argument =
        this.argument as ({CurriculumId curriculumId, String query});
    return contentSearch(
      ref,
      curriculumId: argument.curriculumId,
      query: argument.query,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContentSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contentSearchHash() => r'c78291d29165579a3dcd2db26df7f1906b002a3d';

/// Provides search results for a curriculum.

final class ContentSearchFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ContentItem>>,
          ({CurriculumId curriculumId, String query})
        > {
  ContentSearchFamily._()
    : super(
        retry: null,
        name: r'contentSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides search results for a curriculum.

  ContentSearchProvider call({
    required CurriculumId curriculumId,
    required String query,
  }) => ContentSearchProvider._(
    argument: (curriculumId: curriculumId, query: query),
    from: this,
  );

  @override
  String toString() => r'contentSearchProvider';
}

/// Provides a specific content item by its sefariaRef.

@ProviderFor(contentByRef)
final contentByRefProvider = ContentByRefFamily._();

/// Provides a specific content item by its sefariaRef.

final class ContentByRefProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentItem?>,
          ContentItem?,
          FutureOr<ContentItem?>
        >
    with $FutureModifier<ContentItem?>, $FutureProvider<ContentItem?> {
  /// Provides a specific content item by its sefariaRef.
  ContentByRefProvider._({
    required ContentByRefFamily super.from,
    required ({CurriculumId curriculumId, String sefariaRef}) super.argument,
  }) : super(
         retry: null,
         name: r'contentByRefProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contentByRefHash();

  @override
  String toString() {
    return r'contentByRefProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ContentItem?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentItem?> create(Ref ref) {
    final argument =
        this.argument as ({CurriculumId curriculumId, String sefariaRef});
    return contentByRef(
      ref,
      curriculumId: argument.curriculumId,
      sefariaRef: argument.sefariaRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ContentByRefProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contentByRefHash() => r'a8ee8749041e1da2b4f8d827d775fa130f0161c2';

/// Provides a specific content item by its sefariaRef.

final class ContentByRefFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ContentItem?>,
          ({CurriculumId curriculumId, String sefariaRef})
        > {
  ContentByRefFamily._()
    : super(
        retry: null,
        name: r'contentByRefProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provides a specific content item by its sefariaRef.

  ContentByRefProvider call({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) => ContentByRefProvider._(
    argument: (curriculumId: curriculumId, sefariaRef: sefariaRef),
    from: this,
  );

  @override
  String toString() => r'contentByRefProvider';
}
