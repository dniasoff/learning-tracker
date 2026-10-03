// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Per-stage breakdown for a single item (AC-1, AC-5).

@ProviderFor(itemStageBreakdown)
final itemStageBreakdownProvider = ItemStageBreakdownFamily._();

/// Per-stage breakdown for a single item (AC-1, AC-5).

final class ItemStageBreakdownProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, int>>,
          Map<int, int>,
          FutureOr<Map<int, int>>
        >
    with $FutureModifier<Map<int, int>>, $FutureProvider<Map<int, int>> {
  /// Per-stage breakdown for a single item (AC-1, AC-5).
  ItemStageBreakdownProvider._({
    required ItemStageBreakdownFamily super.from,
    required ({String curriculumId, String sefariaRef}) super.argument,
  }) : super(
         retry: null,
         name: r'itemStageBreakdownProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemStageBreakdownHash();

  @override
  String toString() {
    return r'itemStageBreakdownProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<int, int>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, int>> create(Ref ref) {
    final argument =
        this.argument as ({String curriculumId, String sefariaRef});
    return itemStageBreakdown(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ItemStageBreakdownProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemStageBreakdownHash() =>
    r'08487435fa9b62340402a8b18f9e64e3ccf598e4';

/// Per-stage breakdown for a single item (AC-1, AC-5).

final class ItemStageBreakdownFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<int, int>>,
          ({String curriculumId, String sefariaRef})
        > {
  ItemStageBreakdownFamily._()
    : super(
        retry: null,
        name: r'itemStageBreakdownProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-stage breakdown for a single item (AC-1, AC-5).

  ItemStageBreakdownProvider call(
    ({String curriculumId, String sefariaRef}) params,
  ) => ItemStageBreakdownProvider._(argument: params, from: this);

  @override
  String toString() => r'itemStageBreakdownProvider';
}
