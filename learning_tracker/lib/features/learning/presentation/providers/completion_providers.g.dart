// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the completion repository.

@ProviderFor(completionRepository)
final completionRepositoryProvider = CompletionRepositoryProvider._();

/// Provides the completion repository.

final class CompletionRepositoryProvider
    extends
        $FunctionalProvider<
          CompletionRepository,
          CompletionRepository,
          CompletionRepository
        >
    with $Provider<CompletionRepository> {
  /// Provides the completion repository.
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
    r'87fb3f5a2433a6b842b6e37835f612c9dc254410';

/// Provides the mark completion use case.

@ProviderFor(markCompletionUseCase)
final markCompletionUseCaseProvider = MarkCompletionUseCaseProvider._();

/// Provides the mark completion use case.

final class MarkCompletionUseCaseProvider
    extends
        $FunctionalProvider<
          MarkCompletionUseCase,
          MarkCompletionUseCase,
          MarkCompletionUseCase
        >
    with $Provider<MarkCompletionUseCase> {
  /// Provides the mark completion use case.
  MarkCompletionUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'markCompletionUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$markCompletionUseCaseHash();

  @$internal
  @override
  $ProviderElement<MarkCompletionUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MarkCompletionUseCase create(Ref ref) {
    return markCompletionUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarkCompletionUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarkCompletionUseCase>(value),
    );
  }
}

String _$markCompletionUseCaseHash() =>
    r'7c6f7f668bbff279db3e68350d013052584fc534';

/// Provides the bulk mark completion use case.

@ProviderFor(bulkMarkCompletionUseCase)
final bulkMarkCompletionUseCaseProvider = BulkMarkCompletionUseCaseProvider._();

/// Provides the bulk mark completion use case.

final class BulkMarkCompletionUseCaseProvider
    extends
        $FunctionalProvider<
          BulkMarkCompletionUseCase,
          BulkMarkCompletionUseCase,
          BulkMarkCompletionUseCase
        >
    with $Provider<BulkMarkCompletionUseCase> {
  /// Provides the bulk mark completion use case.
  BulkMarkCompletionUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bulkMarkCompletionUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bulkMarkCompletionUseCaseHash();

  @$internal
  @override
  $ProviderElement<BulkMarkCompletionUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BulkMarkCompletionUseCase create(Ref ref) {
    return bulkMarkCompletionUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BulkMarkCompletionUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BulkMarkCompletionUseCase>(value),
    );
  }
}

String _$bulkMarkCompletionUseCaseHash() =>
    r'cb0d52d29734909aba5219d6bd2c67f6149de9ef';

/// Provides the number of completions for a specific content item,
/// scoped to the active profile.

@ProviderFor(completionCount)
final completionCountProvider = CompletionCountFamily._();

/// Provides the number of completions for a specific content item,
/// scoped to the active profile.

final class CompletionCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Provides the number of completions for a specific content item,
  /// scoped to the active profile.
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

String _$completionCountHash() => r'6945dfea9b86842bd2801dd6e83c986f265960af';

/// Provides the number of completions for a specific content item,
/// scoped to the active profile.

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

  /// Provides the number of completions for a specific content item,
  /// scoped to the active profile.

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

/// Batch review counts for all items in a curriculum (AC-3, AC-7).
/// Single GROUP BY query — avoids N+1 per-item watches.

@ProviderFor(reviewCountsForCurriculum)
final reviewCountsForCurriculumProvider = ReviewCountsForCurriculumFamily._();

/// Batch review counts for all items in a curriculum (AC-3, AC-7).
/// Single GROUP BY query — avoids N+1 per-item watches.

final class ReviewCountsForCurriculumProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          FutureOr<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $FutureProvider<Map<String, int>> {
  /// Batch review counts for all items in a curriculum (AC-3, AC-7).
  /// Single GROUP BY query — avoids N+1 per-item watches.
  ReviewCountsForCurriculumProvider._({
    required ReviewCountsForCurriculumFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reviewCountsForCurriculumProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reviewCountsForCurriculumHash();

  @override
  String toString() {
    return r'reviewCountsForCurriculumProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, int>> create(Ref ref) {
    final argument = this.argument as String;
    return reviewCountsForCurriculum(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReviewCountsForCurriculumProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reviewCountsForCurriculumHash() =>
    r'71312744f39f7921dd5153a9aeaf589f21bf523d';

/// Batch review counts for all items in a curriculum (AC-3, AC-7).
/// Single GROUP BY query — avoids N+1 per-item watches.

final class ReviewCountsForCurriculumFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, int>>, String> {
  ReviewCountsForCurriculumFamily._()
    : super(
        retry: null,
        name: r'reviewCountsForCurriculumProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Batch review counts for all items in a curriculum (AC-3, AC-7).
  /// Single GROUP BY query — avoids N+1 per-item watches.

  ReviewCountsForCurriculumProvider call(String curriculumId) =>
      ReviewCountsForCurriculumProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'reviewCountsForCurriculumProvider';
}

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
    r'a6483b57733865d4ce8e43541014efbff3058043';

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
