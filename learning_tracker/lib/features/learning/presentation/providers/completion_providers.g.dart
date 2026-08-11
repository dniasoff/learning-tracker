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

@ProviderFor(completionPointsPort)
final completionPointsPortProvider = CompletionPointsPortProvider._();

/// Firestore-backed [CompletionPointsPort] — see that class's doc comment.

final class CompletionPointsPortProvider
    extends
        $FunctionalProvider<
          CompletionPointsPort,
          CompletionPointsPort,
          CompletionPointsPort
        >
    with $Provider<CompletionPointsPort> {
  /// Firestore-backed [CompletionPointsPort] — see that class's doc comment.
  CompletionPointsPortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionPointsPortProvider',
        isAutoDispose: true,
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
    r'5ccae26b938ad8047ef7713bde888bb21c9e3930';

/// Firestore-backed [CompletionStreakPort] — see that class's doc comment.
///
/// The recorder resolves its own repository from `ref`, so this presentation
/// provider never names a data-access-ring type (AD-23/AD-28).

@ProviderFor(completionStreakPort)
final completionStreakPortProvider = CompletionStreakPortProvider._();

/// Firestore-backed [CompletionStreakPort] — see that class's doc comment.
///
/// The recorder resolves its own repository from `ref`, so this presentation
/// provider never names a data-access-ring type (AD-23/AD-28).

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
  CompletionStreakPortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionStreakPortProvider',
        isAutoDispose: true,
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
    r'12e5cdb6ffc62d66c38c1e50146daeeb46be6ad3';

/// Provides the [CompletionOrchestrator] — the single place the five
/// completion side effects live (`docs/firestore-rewrite-map.md`, owner
/// decision 1). [MarkCompletionUseCase], [BulkMarkCompletionUseCase], and
/// (via `onboarding_providers.dart`) `BulkPriorCompletionService` all go
/// through this, not [completionRepositoryProvider] directly.

@ProviderFor(completionOrchestrator)
final completionOrchestratorProvider = CompletionOrchestratorProvider._();

/// Provides the [CompletionOrchestrator] — the single place the five
/// completion side effects live (`docs/firestore-rewrite-map.md`, owner
/// decision 1). [MarkCompletionUseCase], [BulkMarkCompletionUseCase], and
/// (via `onboarding_providers.dart`) `BulkPriorCompletionService` all go
/// through this, not [completionRepositoryProvider] directly.

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
  CompletionOrchestratorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionOrchestratorProvider',
        isAutoDispose: true,
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
    r'9ee0aa332ed3396c4035b40e072d966bdc855e8e';

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
    r'9672ee564915bfbac34fd030d7e25a34459ffb76';

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
    r'fa9117793175193b748541130a08347b70cc7084';

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
