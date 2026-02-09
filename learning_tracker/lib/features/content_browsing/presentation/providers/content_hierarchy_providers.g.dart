// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_hierarchy_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for all active curricula with item counts.
/// Used by the curriculum list screen.

@ProviderFor(curriculumList)
const curriculumListProvider = CurriculumListProvider._();

/// Provider for all active curricula with item counts.
/// Used by the curriculum list screen.

final class CurriculumListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CurriculumInfo>>,
          List<CurriculumInfo>,
          FutureOr<List<CurriculumInfo>>
        >
    with
        $FutureModifier<List<CurriculumInfo>>,
        $FutureProvider<List<CurriculumInfo>> {
  /// Provider for all active curricula with item counts.
  /// Used by the curriculum list screen.
  const CurriculumListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'curriculumListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$curriculumListHash();

  @$internal
  @override
  $FutureProviderElement<List<CurriculumInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CurriculumInfo>> create(Ref ref) {
    return curriculumList(ref);
  }
}

String _$curriculumListHash() => r'aec373d2ca6362b08ee03e2fbbe2892fb2efa1c3';

/// Provider for hierarchy configuration labels for a curriculum.
/// Uses family pattern per P3 requirements.

@ProviderFor(hierarchyLabels)
const hierarchyLabelsProvider = HierarchyLabelsFamily._();

/// Provider for hierarchy configuration labels for a curriculum.
/// Uses family pattern per P3 requirements.

final class HierarchyLabelsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Provider for hierarchy configuration labels for a curriculum.
  /// Uses family pattern per P3 requirements.
  const HierarchyLabelsProvider._({
    required HierarchyLabelsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'hierarchyLabelsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hierarchyLabelsHash();

  @override
  String toString() {
    return r'hierarchyLabelsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return hierarchyLabels(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HierarchyLabelsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hierarchyLabelsHash() => r'8872122c0358bd0acd59af0cf47a5a9e1bd880b3';

/// Provider for hierarchy configuration labels for a curriculum.
/// Uses family pattern per P3 requirements.

final class HierarchyLabelsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  const HierarchyLabelsFamily._()
    : super(
        retry: null,
        name: r'hierarchyLabelsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for hierarchy configuration labels for a curriculum.
  /// Uses family pattern per P3 requirements.

  HierarchyLabelsProvider call(String curriculumId) =>
      HierarchyLabelsProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'hierarchyLabelsProvider';
}

/// Provider for content items at a specific hierarchy path.
/// Uses family pattern per P3 requirements.
/// Pass a hierarchy key in format "curriculumId/level1/level2/..." or just "curriculumId" for top level.

@ProviderFor(hierarchyItems)
const hierarchyItemsProvider = HierarchyItemsFamily._();

/// Provider for content items at a specific hierarchy path.
/// Uses family pattern per P3 requirements.
/// Pass a hierarchy key in format "curriculumId/level1/level2/..." or just "curriculumId" for top level.

final class HierarchyItemsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HierarchyItemDTO>>,
          List<HierarchyItemDTO>,
          FutureOr<List<HierarchyItemDTO>>
        >
    with
        $FutureModifier<List<HierarchyItemDTO>>,
        $FutureProvider<List<HierarchyItemDTO>> {
  /// Provider for content items at a specific hierarchy path.
  /// Uses family pattern per P3 requirements.
  /// Pass a hierarchy key in format "curriculumId/level1/level2/..." or just "curriculumId" for top level.
  const HierarchyItemsProvider._({
    required HierarchyItemsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'hierarchyItemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$hierarchyItemsHash();

  @override
  String toString() {
    return r'hierarchyItemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<HierarchyItemDTO>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HierarchyItemDTO>> create(Ref ref) {
    final argument = this.argument as String;
    return hierarchyItems(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HierarchyItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$hierarchyItemsHash() => r'347a8356f6e7804255fc6c1d1e396042df541aa9';

/// Provider for content items at a specific hierarchy path.
/// Uses family pattern per P3 requirements.
/// Pass a hierarchy key in format "curriculumId/level1/level2/..." or just "curriculumId" for top level.

final class HierarchyItemsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<HierarchyItemDTO>>, String> {
  const HierarchyItemsFamily._()
    : super(
        retry: null,
        name: r'hierarchyItemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for content items at a specific hierarchy path.
  /// Uses family pattern per P3 requirements.
  /// Pass a hierarchy key in format "curriculumId/level1/level2/..." or just "curriculumId" for top level.

  HierarchyItemsProvider call(String hierarchyKey) =>
      HierarchyItemsProvider._(argument: hierarchyKey, from: this);

  @override
  String toString() => r'hierarchyItemsProvider';
}

/// Provider for getting a specific content item's details by path.
/// Used for breadcrumb display names.

@ProviderFor(contentItemByPath)
const contentItemByPathProvider = ContentItemByPathFamily._();

/// Provider for getting a specific content item's details by path.
/// Used for breadcrumb display names.

final class ContentItemByPathProvider
    extends
        $FunctionalProvider<
          AsyncValue<HierarchyItemDTO?>,
          HierarchyItemDTO?,
          FutureOr<HierarchyItemDTO?>
        >
    with
        $FutureModifier<HierarchyItemDTO?>,
        $FutureProvider<HierarchyItemDTO?> {
  /// Provider for getting a specific content item's details by path.
  /// Used for breadcrumb display names.
  const ContentItemByPathProvider._({
    required ContentItemByPathFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'contentItemByPathProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contentItemByPathHash();

  @override
  String toString() {
    return r'contentItemByPathProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<HierarchyItemDTO?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HierarchyItemDTO?> create(Ref ref) {
    final argument = this.argument as String;
    return contentItemByPath(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ContentItemByPathProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contentItemByPathHash() => r'ec2bfa5196807dbc4851128f010bd045fcc9503c';

/// Provider for getting a specific content item's details by path.
/// Used for breadcrumb display names.

final class ContentItemByPathFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<HierarchyItemDTO?>, String> {
  const ContentItemByPathFamily._()
    : super(
        retry: null,
        name: r'contentItemByPathProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting a specific content item's details by path.
  /// Used for breadcrumb display names.

  ContentItemByPathProvider call(String hierarchyKey) =>
      ContentItemByPathProvider._(argument: hierarchyKey, from: this);

  @override
  String toString() => r'contentItemByPathProvider';
}
