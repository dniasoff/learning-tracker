// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_tree.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a single [ContentTree] built from all 9 curricula.
///
/// `keepAlive: true` — the tree must never be discarded mid-session; it is
/// built once on first use and held for the lifetime of the app.

@ProviderFor(contentTree)
final contentTreeProvider = ContentTreeProvider._();

/// Provides a single [ContentTree] built from all 9 curricula.
///
/// `keepAlive: true` — the tree must never be discarded mid-session; it is
/// built once on first use and held for the lifetime of the app.

final class ContentTreeProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentTree>,
          ContentTree,
          FutureOr<ContentTree>
        >
    with $FutureModifier<ContentTree>, $FutureProvider<ContentTree> {
  /// Provides a single [ContentTree] built from all 9 curricula.
  ///
  /// `keepAlive: true` — the tree must never be discarded mid-session; it is
  /// built once on first use and held for the lifetime of the app.
  ContentTreeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentTreeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentTreeHash();

  @$internal
  @override
  $FutureProviderElement<ContentTree> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ContentTree> create(Ref ref) {
    return contentTree(ref);
  }
}

String _$contentTreeHash() => r'58018b4f3fb68cbe3888edcb42d072d24e28bc77';
