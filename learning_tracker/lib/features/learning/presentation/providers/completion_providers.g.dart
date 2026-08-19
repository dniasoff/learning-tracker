// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the completion repository — storage-only since the
/// completion-orchestrator lift (`docs/firestore-rewrite-map.md`, owner
/// decision 1). See [completionOrchestratorProvider] for where order
/// validation, points, siyum detection, bookmark advance and streak now
/// live.
///
/// **Firestore-backed** via [FirestoreCompletionRepositoryAdapter] (wired
/// Phase 3, T-20). The Drift-backed [CompletionRepositoryImpl] is
/// deprecated and will be removed in Phase 4.

@ProviderFor(completionRepository)
final completionRepositoryProvider = CompletionRepositoryProvider._();

/// Provides the completion repository — storage-only since the
/// completion-orchestrator lift (`docs/firestore-rewrite-map.md`, owner
/// decision 1). See [completionOrchestratorProvider] for where order
/// validation, points, siyum detection, bookmark advance and streak now
/// live.
///
/// **Firestore-backed** via [FirestoreCompletionRepositoryAdapter] (wired
/// Phase 3, T-20). The Drift-backed [CompletionRepositoryImpl] is
/// deprecated and will be removed in Phase 4.

final class CompletionRepositoryProvider
    extends
        $FunctionalProvider<
          CompletionRepository,
          CompletionRepository,
          CompletionRepository
        >
    with $Provider<CompletionRepository> {
  /// Provides the completion repository — storage-only since the
  /// completion-orchestrator lift (`docs/firestore-rewrite-map.md`, owner
  /// decision 1). See [completionOrchestratorProvider] for where order
  /// validation, points, siyum detection, bookmark advance and streak now
  /// live.
  ///
  /// **Firestore-backed** via [FirestoreCompletionRepositoryAdapter] (wired
  /// Phase 3, T-20). The Drift-backed [CompletionRepositoryImpl] is
  /// deprecated and will be removed in Phase 4.
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

/// Firestore-backed [CompletionPointsPort] — see that class's doc comment.
///
/// This provider participates in a completion write that awaits an async
/// Firestore gap before using the port again. It must survive when the last
/// listener drops to zero; autoDispose would tear down its [Ref] during that
/// gap and make the later points lookup fail.

@ProviderFor(completionPointsPort)
final completionPointsPortProvider = CompletionPointsPortProvider._();

/// Firestore-backed [CompletionPointsPort] — see that class's doc comment.
///
/// This provider participates in a completion write that awaits an async
/// Firestore gap before using the port again. It must survive when the last
/// listener drops to zero; autoDispose would tear down its [Ref] during that
/// gap and make the later points lookup fail.

final class CompletionPointsPortProvider
    extends
        $FunctionalProvider<
          CompletionPointsPort,
          CompletionPointsPort,
          CompletionPointsPort
        >
    with $Provider<CompletionPointsPort> {
  /// Firestore-backed [CompletionPointsPort] — see that class's doc comment.
  ///
  /// This provider participates in a completion write that awaits an async
  /// Firestore gap before using the port again. It must survive when the last
  /// listener drops to zero; autoDispose would tear down its [Ref] during that
  /// gap and make the later points lookup fail.
  CompletionPointsPortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionPointsPortProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionPointsPortHash();

  @$internal
  @override
  $ProviderElement<CompletionPointsPort> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompletionPointsPort create(Ref ref) {
    return completionPointsPort(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompletionPointsPort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompletionPointsPort>(value),
    );
  }
}

String _$completionPointsPortHash() =>
    r'bab952a3e0313b372613166e4375f4c3953f70ae';

/// Firestore-backed [CompletionStreakPort] — see that class's doc comment.
///
/// The recorder resolves its own repository from `ref`, so this presentation
/// provider never names a data-access-ring type (AD-23/AD-28).
///
/// This provider participates in a completion write that awaits an async
/// Firestore gap before using the port again. It must survive when the last
/// listener drops to zero; autoDispose would tear down its [Ref] during that
/// gap and make the later streak write fail.

@ProviderFor(completionStreakPort)
final completionStreakPortProvider = CompletionStreakPortProvider._();

/// Firestore-backed [CompletionStreakPort] — see that class's doc comment.
///
/// The recorder resolves its own repository from `ref`, so this presentation
/// provider never names a data-access-ring type (AD-23/AD-28).
///
/// This provider participates in a completion write that awaits an async
/// Firestore gap before using the port again. It must survive when the last
/// listener drops to zero; autoDispose would tear down its [Ref] during that
/// gap and make the later streak write fail.

final class CompletionStreakPortProvider
    extends
        $FunctionalProvider<
          CompletionStreakPort,
          CompletionStreakPort,
          CompletionStreakPort
        >
    with $Provider<CompletionStreakPort> {
  /// Firestore-backed [CompletionStreakPort] — see that class's doc comment.
  ///
  /// The recorder resolves its own repository from `ref`, so this presentation
  /// provider never names a data-access-ring type (AD-23/AD-28).
  ///
  /// This provider participates in a completion write that awaits an async
  /// Firestore gap before using the port again. It must survive when the last
  /// listener drops to zero; autoDispose would tear down its [Ref] during that
  /// gap and make the later streak write fail.
  CompletionStreakPortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionStreakPortProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionStreakPortHash();

  @$internal
  @override
  $ProviderElement<CompletionStreakPort> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompletionStreakPort create(Ref ref) {
    return completionStreakPort(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompletionStreakPort value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompletionStreakPort>(value),
    );
  }
}

String _$completionStreakPortHash() =>
    r'01dbd72ead497b624ba81ba69a4ecf3a2fbf562c';

/// Provides the [CompletionDetectionService] — the single "is this unit
/// covered" + siyum-crediting service, shared (Riverpod-cached) between
/// [completionOrchestratorProvider] and (via `onboarding_providers.dart`)
/// `BulkPriorCompletionService`'s D-M retraction path, rather than each
/// constructing its own instance.
///
/// This provider participates in a completion write that awaits an async
/// Firestore gap before using the service again. It must survive when the last
/// listener drops to zero; autoDispose would tear down its [Ref] during that
/// gap and make later detection work fail.

@ProviderFor(completionDetectionService)
final completionDetectionServiceProvider =
    CompletionDetectionServiceProvider._();

/// Provides the [CompletionDetectionService] — the single "is this unit
/// covered" + siyum-crediting service, shared (Riverpod-cached) between
/// [completionOrchestratorProvider] and (via `onboarding_providers.dart`)
/// `BulkPriorCompletionService`'s D-M retraction path, rather than each
/// constructing its own instance.
///
/// This provider participates in a completion write that awaits an async
/// Firestore gap before using the service again. It must survive when the last
/// listener drops to zero; autoDispose would tear down its [Ref] during that
/// gap and make later detection work fail.

final class CompletionDetectionServiceProvider
    extends
        $FunctionalProvider<
          CompletionDetectionService,
          CompletionDetectionService,
          CompletionDetectionService
        >
    with $Provider<CompletionDetectionService> {
  /// Provides the [CompletionDetectionService] — the single "is this unit
  /// covered" + siyum-crediting service, shared (Riverpod-cached) between
  /// [completionOrchestratorProvider] and (via `onboarding_providers.dart`)
  /// `BulkPriorCompletionService`'s D-M retraction path, rather than each
  /// constructing its own instance.
  ///
  /// This provider participates in a completion write that awaits an async
  /// Firestore gap before using the service again. It must survive when the last
  /// listener drops to zero; autoDispose would tear down its [Ref] during that
  /// gap and make later detection work fail.
  CompletionDetectionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionDetectionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionDetectionServiceHash();

  @$internal
  @override
  $ProviderElement<CompletionDetectionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompletionDetectionService create(Ref ref) {
    return completionDetectionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompletionDetectionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompletionDetectionService>(value),
    );
  }
}

String _$completionDetectionServiceHash() =>
    r'29b67f8038110470ee0efef9499c10525d252d23';

/// Provides the [CompletionOrchestrator] — the single place the five
/// completion side effects live (`docs/firestore-rewrite-map.md`, owner
/// decision 1). [MarkCompletionUseCase], [BulkMarkCompletionUseCase], and
/// (via `onboarding_providers.dart`) `BulkPriorCompletionService` all go
/// through this, not [completionRepositoryProvider] directly.
///
/// This provider owns a completion write that awaits an async Firestore gap
/// before running its remaining side effects. It must survive when the last
/// listener drops to zero; autoDispose would tear down the dependency chain's
/// [Ref] during that gap and make the write fail.

@ProviderFor(completionOrchestrator)
final completionOrchestratorProvider = CompletionOrchestratorProvider._();

/// Provides the [CompletionOrchestrator] — the single place the five
/// completion side effects live (`docs/firestore-rewrite-map.md`, owner
/// decision 1). [MarkCompletionUseCase], [BulkMarkCompletionUseCase], and
/// (via `onboarding_providers.dart`) `BulkPriorCompletionService` all go
/// through this, not [completionRepositoryProvider] directly.
///
/// This provider owns a completion write that awaits an async Firestore gap
/// before running its remaining side effects. It must survive when the last
/// listener drops to zero; autoDispose would tear down the dependency chain's
/// [Ref] during that gap and make the write fail.

final class CompletionOrchestratorProvider
    extends
        $FunctionalProvider<
          CompletionOrchestrator,
          CompletionOrchestrator,
          CompletionOrchestrator
        >
    with $Provider<CompletionOrchestrator> {
  /// Provides the [CompletionOrchestrator] — the single place the five
  /// completion side effects live (`docs/firestore-rewrite-map.md`, owner
  /// decision 1). [MarkCompletionUseCase], [BulkMarkCompletionUseCase], and
  /// (via `onboarding_providers.dart`) `BulkPriorCompletionService` all go
  /// through this, not [completionRepositoryProvider] directly.
  ///
  /// This provider owns a completion write that awaits an async Firestore gap
  /// before running its remaining side effects. It must survive when the last
  /// listener drops to zero; autoDispose would tear down the dependency chain's
  /// [Ref] during that gap and make the write fail.
  CompletionOrchestratorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionOrchestratorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionOrchestratorHash();

  @$internal
  @override
  $ProviderElement<CompletionOrchestrator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CompletionOrchestrator create(Ref ref) {
    return completionOrchestrator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompletionOrchestrator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompletionOrchestrator>(value),
    );
  }
}

String _$completionOrchestratorHash() =>
    r'c86d918e29e5e52c6192e89392c715973d565d5e';

/// Provides the mark completion use case.
///
/// This use case is reached by a one-shot read and then awaits an async
/// Firestore gap. It must survive when the last listener drops to zero;
/// autoDispose would tear down the completion chain before the write resumes.

@ProviderFor(markCompletionUseCase)
final markCompletionUseCaseProvider = MarkCompletionUseCaseProvider._();

/// Provides the mark completion use case.
///
/// This use case is reached by a one-shot read and then awaits an async
/// Firestore gap. It must survive when the last listener drops to zero;
/// autoDispose would tear down the completion chain before the write resumes.

final class MarkCompletionUseCaseProvider
    extends
        $FunctionalProvider<
          MarkCompletionUseCase,
          MarkCompletionUseCase,
          MarkCompletionUseCase
        >
    with $Provider<MarkCompletionUseCase> {
  /// Provides the mark completion use case.
  ///
  /// This use case is reached by a one-shot read and then awaits an async
  /// Firestore gap. It must survive when the last listener drops to zero;
  /// autoDispose would tear down the completion chain before the write resumes.
  MarkCompletionUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'markCompletionUseCaseProvider',
        isAutoDispose: false,
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
    r'59e04d8acd937835b69bee2a6df945a22c99adc9';

/// Provides the bulk mark completion use case.
///
/// This use case is reached by a one-shot read and then awaits an async
/// Firestore gap. It must survive when the last listener drops to zero;
/// autoDispose would tear down the completion chain before the bulk write
/// resumes.

@ProviderFor(bulkMarkCompletionUseCase)
final bulkMarkCompletionUseCaseProvider = BulkMarkCompletionUseCaseProvider._();

/// Provides the bulk mark completion use case.
///
/// This use case is reached by a one-shot read and then awaits an async
/// Firestore gap. It must survive when the last listener drops to zero;
/// autoDispose would tear down the completion chain before the bulk write
/// resumes.

final class BulkMarkCompletionUseCaseProvider
    extends
        $FunctionalProvider<
          BulkMarkCompletionUseCase,
          BulkMarkCompletionUseCase,
          BulkMarkCompletionUseCase
        >
    with $Provider<BulkMarkCompletionUseCase> {
  /// Provides the bulk mark completion use case.
  ///
  /// This use case is reached by a one-shot read and then awaits an async
  /// Firestore gap. It must survive when the last listener drops to zero;
  /// autoDispose would tear down the completion chain before the bulk write
  /// resumes.
  BulkMarkCompletionUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bulkMarkCompletionUseCaseProvider',
        isAutoDispose: false,
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
    r'2be1d6bc1dc3c2bfdf44c298332a250d3ad831e0';

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

String _$completionCountHash() => r'2fed986edd27df92631c47e2c071949e59e457cf';

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

@ProviderFor(reviewCountsForCurriculum)
final reviewCountsForCurriculumProvider = ReviewCountsForCurriculumFamily._();

/// Batch review counts for all items in a curriculum (AC-3, AC-7).

final class ReviewCountsForCurriculumProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          FutureOr<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $FutureProvider<Map<String, int>> {
  /// Batch review counts for all items in a curriculum (AC-3, AC-7).
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
    r'efc2d8599ea58559682239919131b9d4247a63cb';

/// Batch review counts for all items in a curriculum (AC-3, AC-7).

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
    r'ff0d5cd62793d0c2be2a74efbf3e8190b8aebc7a';

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
