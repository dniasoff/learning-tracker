// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'magic_link_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single, app-wide [MagicLinkService] that listens for incoming
/// magic-link deep links and promotes the auth state on success.
///
/// Kept alive for the entire app lifetime so the link subscription
/// is never accidentally torn down by a route change.

@ProviderFor(magicLinkService)
final magicLinkServiceProvider = MagicLinkServiceProvider._();

/// Single, app-wide [MagicLinkService] that listens for incoming
/// magic-link deep links and promotes the auth state on success.
///
/// Kept alive for the entire app lifetime so the link subscription
/// is never accidentally torn down by a route change.

final class MagicLinkServiceProvider
    extends
        $FunctionalProvider<
          MagicLinkService,
          MagicLinkService,
          MagicLinkService
        >
    with $Provider<MagicLinkService> {
  /// Single, app-wide [MagicLinkService] that listens for incoming
  /// magic-link deep links and promotes the auth state on success.
  ///
  /// Kept alive for the entire app lifetime so the link subscription
  /// is never accidentally torn down by a route change.
  MagicLinkServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'magicLinkServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$magicLinkServiceHash();

  @$internal
  @override
  $ProviderElement<MagicLinkService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MagicLinkService create(Ref ref) {
    return magicLinkService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MagicLinkService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MagicLinkService>(value),
    );
  }
}

String _$magicLinkServiceHash() => r'4e2e75a52e5c239a9c2db0fa359dc2ef9a6b94ee';
