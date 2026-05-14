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

String _$completionWriterHash() => r'ee31d13012a8c2c59954daee6629476a8f457fae';
