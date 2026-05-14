// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_ledger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the learning ledger repository.

@ProviderFor(learningLedgerRepository)
final learningLedgerRepositoryProvider = LearningLedgerRepositoryProvider._();

/// Provides the learning ledger repository.

final class LearningLedgerRepositoryProvider
    extends
        $FunctionalProvider<
          LearningLedgerRepository,
          LearningLedgerRepository,
          LearningLedgerRepository
        >
    with $Provider<LearningLedgerRepository> {
  /// Provides the learning ledger repository.
  LearningLedgerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningLedgerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningLedgerRepositoryHash();

  @$internal
  @override
  $ProviderElement<LearningLedgerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LearningLedgerRepository create(Ref ref) {
    return learningLedgerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningLedgerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningLedgerRepository>(value),
    );
  }
}

String _$learningLedgerRepositoryHash() =>
    r'2f5627f17ad5cf0e414ed22e96494e5c8e663753';

/// Provides the manual completion use case.

@ProviderFor(manualCompletionUseCase)
final manualCompletionUseCaseProvider = ManualCompletionUseCaseProvider._();

/// Provides the manual completion use case.

final class ManualCompletionUseCaseProvider
    extends
        $FunctionalProvider<
          ManualCompletionUseCase,
          ManualCompletionUseCase,
          ManualCompletionUseCase
        >
    with $Provider<ManualCompletionUseCase> {
  /// Provides the manual completion use case.
  ManualCompletionUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'manualCompletionUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$manualCompletionUseCaseHash();

  @$internal
  @override
  $ProviderElement<ManualCompletionUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ManualCompletionUseCase create(Ref ref) {
    return manualCompletionUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ManualCompletionUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ManualCompletionUseCase>(value),
    );
  }
}

String _$manualCompletionUseCaseHash() =>
    r'b67a203ab9e182bc27787021b6565134ba5ac583';
