// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_index.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a single [ContentIndex] populated from all 9 curricula.
///
/// `keepAlive: true` ensures the index is built once per app lifetime —
/// rebuilding it would discard the cached map and force a scan of 52K rows.

@ProviderFor(contentIndex)
final contentIndexProvider = ContentIndexProvider._();

/// Provides a single [ContentIndex] populated from all 9 curricula.
///
/// `keepAlive: true` ensures the index is built once per app lifetime —
/// rebuilding it would discard the cached map and force a scan of 52K rows.

final class ContentIndexProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentIndex>,
          ContentIndex,
          FutureOr<ContentIndex>
        >
    with $FutureModifier<ContentIndex>, $FutureProvider<ContentIndex> {
  /// Provides a single [ContentIndex] populated from all 9 curricula.
  ///
  /// `keepAlive: true` ensures the index is built once per app lifetime —
  /// rebuilding it would discard the cached map and force a scan of 52K rows.
  ContentIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentIndexHash();

  @$internal
  @override
  $FutureProviderElement<ContentIndex> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentIndex> create(Ref ref) {
    return contentIndex(ref);
  }
}

String _$contentIndexHash() => r'ae17be110d0e0384900424da7b4730b8153e2ef1';
