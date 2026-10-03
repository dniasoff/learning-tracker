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

/// Provides the legacy completion repository (R1). No screen reads it any
/// more; Story 1.21 (DNI-483) deletes it with its tests.

@ProviderFor(completionRepository)
final completionRepositoryProvider = CompletionRepositoryProvider._();

/// Provides the legacy completion repository (R1). No screen reads it any
/// more; Story 1.21 (DNI-483) deletes it with its tests.

final class CompletionRepositoryProvider
    extends
        $FunctionalProvider<
          CompletionRepository,
          CompletionRepository,
          CompletionRepository
        >
    with $Provider<CompletionRepository> {
  /// Provides the legacy completion repository (R1). No screen reads it any
  /// more; Story 1.21 (DNI-483) deletes it with its tests.
  CompletionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionRepositoryHash();

  @$internal
  @override
  $ProviderElement<CompletionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompletionRepository create(Ref ref) {
    return completionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompletionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompletionRepository>(value),
    );
  }
}

String _$completionRepositoryHash() =>
    r'50a66b9ac044d5347a9d015c7b7c346fff3a641b';

/// Legacy per-item completion count (R1, no production reader); deleted
/// with [completionRepository].

@ProviderFor(completionCount)
final completionCountProvider = CompletionCountFamily._();

/// Legacy per-item completion count (R1, no production reader); deleted
/// with [completionRepository].

final class CompletionCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Legacy per-item completion count (R1, no production reader); deleted
  /// with [completionRepository].
  CompletionCountProvider._({
    required CompletionCountFamily super.from,
    required ({String curriculumId, String sefariaRef}) super.argument,
  }) : super(
         retry: null,
         name: r'completionCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$completionCountHash();

  @override
  String toString() {
    return r'completionCountProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    final argument =
        this.argument as ({String curriculumId, String sefariaRef});
    return completionCount(
      ref,
      curriculumId: argument.curriculumId,
      sefariaRef: argument.sefariaRef,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CompletionCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$completionCountHash() => r'2fed986edd27df92631c47e2c071949e59e457cf';

/// Legacy per-item completion count (R1, no production reader); deleted
/// with [completionRepository].

final class CompletionCountFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<int>,
          ({String curriculumId, String sefariaRef})
        > {
  CompletionCountFamily._()
    : super(
        retry: null,
        name: r'completionCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Legacy per-item completion count (R1, no production reader); deleted
  /// with [completionRepository].

  CompletionCountProvider call({
    required String curriculumId,
    required String sefariaRef,
  }) => CompletionCountProvider._(
    argument: (curriculumId: curriculumId, sefariaRef: sefariaRef),
    from: this,
  );

  @override
  String toString() => r'completionCountProvider';
}
