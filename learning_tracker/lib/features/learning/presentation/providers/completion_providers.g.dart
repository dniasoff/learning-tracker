// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the completion repository.

@ProviderFor(completionRepository)
const completionRepositoryProvider = CompletionRepositoryProvider._();

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
  const CompletionRepositoryProvider._()
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
    r'd5c4618dc73b72827c6496d5447ae19ea5f3697c';

/// Provides the mark completion use case.

@ProviderFor(markCompletionUseCase)
const markCompletionUseCaseProvider = MarkCompletionUseCaseProvider._();

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
  const MarkCompletionUseCaseProvider._()
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
const bulkMarkCompletionUseCaseProvider = BulkMarkCompletionUseCaseProvider._();

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
  const BulkMarkCompletionUseCaseProvider._()
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
