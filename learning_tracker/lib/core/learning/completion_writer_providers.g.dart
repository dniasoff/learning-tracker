// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completion_writer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod entry point for [CompletionWriter] — the single authoritative
/// completion-write path (FR15).

@ProviderFor(completionWriter)
final completionWriterProvider = CompletionWriterProvider._();

/// Riverpod entry point for [CompletionWriter] — the single authoritative
/// completion-write path (FR15).

final class CompletionWriterProvider
    extends
        $FunctionalProvider<
          CompletionWriter,
          CompletionWriter,
          CompletionWriter
        >
    with $Provider<CompletionWriter> {
  /// Riverpod entry point for [CompletionWriter] — the single authoritative
  /// completion-write path (FR15).
  CompletionWriterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionWriterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionWriterHash();

  @$internal
  @override
  $ProviderElement<CompletionWriter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CompletionWriter create(Ref ref) {
    return completionWriter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompletionWriter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompletionWriter>(value),
    );
  }
}

String _$completionWriterHash() => r'59699010e94abe7a0eca93a8e75318b46474d37a';

/// Monotonically-increasing counter that increments once per successfully
/// committed completion (Story 26.13 — DNI-356).
///
/// Providers that depend on completion data watch this counter so they
/// automatically rebuild when a new completion is recorded, without
/// requiring manual [Ref.invalidate] calls at call sites.
///
/// Call sites increment via:
/// ```dart
/// ref.read(completionCommittedProvider.notifier).increment();
/// ```

@ProviderFor(CompletionCommitted)
final completionCommittedProvider = CompletionCommittedProvider._();

/// Monotonically-increasing counter that increments once per successfully
/// committed completion (Story 26.13 — DNI-356).
///
/// Providers that depend on completion data watch this counter so they
/// automatically rebuild when a new completion is recorded, without
/// requiring manual [Ref.invalidate] calls at call sites.
///
/// Call sites increment via:
/// ```dart
/// ref.read(completionCommittedProvider.notifier).increment();
/// ```
final class CompletionCommittedProvider
    extends $NotifierProvider<CompletionCommitted, int> {
  /// Monotonically-increasing counter that increments once per successfully
  /// committed completion (Story 26.13 — DNI-356).
  ///
  /// Providers that depend on completion data watch this counter so they
  /// automatically rebuild when a new completion is recorded, without
  /// requiring manual [Ref.invalidate] calls at call sites.
  ///
  /// Call sites increment via:
  /// ```dart
  /// ref.read(completionCommittedProvider.notifier).increment();
  /// ```
  CompletionCommittedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionCommittedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionCommittedHash();

  @$internal
  @override
  CompletionCommitted create() => CompletionCommitted();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$completionCommittedHash() =>
    r'57ed543d099d06b6c066581f6f29478b223caa67';

/// Monotonically-increasing counter that increments once per successfully
/// committed completion (Story 26.13 — DNI-356).
///
/// Providers that depend on completion data watch this counter so they
/// automatically rebuild when a new completion is recorded, without
/// requiring manual [Ref.invalidate] calls at call sites.
///
/// Call sites increment via:
/// ```dart
/// ref.read(completionCommittedProvider.notifier).increment();
/// ```

abstract class _$CompletionCommitted extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
