// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_display_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the text cache repository.
///
/// **Composition-root carve-out (AUD-content_browsing-04):** this file's
/// `data/repositories/text_cache_repository.dart` import constructs the
/// concrete [TextCacheRepository] — the DI wiring step, not an entity
/// leak (TextContent/TextSegment live in domain/entities/text_content.dart
/// and are re-exported from here, not defined here). See
/// "Composition-root carve-out" in docs/coding-standards.md; the same
/// pattern is used by ~11 other feature `presentation/providers/` files
/// repo-wide.
///
/// Awaits [contentDatabaseProvider] so the repository is only created once
/// the content DB is ready (extraction completes on first launch).
// keepAlive: singleton repository wrapping the content-DB DAOs must survive rebuilds for the app's lifetime.

@ProviderFor(textCacheRepository)
final textCacheRepositoryProvider = TextCacheRepositoryProvider._();

/// Provider for the text cache repository.
///
/// **Composition-root carve-out (AUD-content_browsing-04):** this file's
/// `data/repositories/text_cache_repository.dart` import constructs the
/// concrete [TextCacheRepository] — the DI wiring step, not an entity
/// leak (TextContent/TextSegment live in domain/entities/text_content.dart
/// and are re-exported from here, not defined here). See
/// "Composition-root carve-out" in docs/coding-standards.md; the same
/// pattern is used by ~11 other feature `presentation/providers/` files
/// repo-wide.
///
/// Awaits [contentDatabaseProvider] so the repository is only created once
/// the content DB is ready (extraction completes on first launch).
// keepAlive: singleton repository wrapping the content-DB DAOs must survive rebuilds for the app's lifetime.

final class TextCacheRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TextCacheRepository>,
          TextCacheRepository,
          FutureOr<TextCacheRepository>
        >
    with
        $FutureModifier<TextCacheRepository>,
        $FutureProvider<TextCacheRepository> {
  /// Provider for the text cache repository.
  ///
  /// **Composition-root carve-out (AUD-content_browsing-04):** this file's
  /// `data/repositories/text_cache_repository.dart` import constructs the
  /// concrete [TextCacheRepository] — the DI wiring step, not an entity
  /// leak (TextContent/TextSegment live in domain/entities/text_content.dart
  /// and are re-exported from here, not defined here). See
  /// "Composition-root carve-out" in docs/coding-standards.md; the same
  /// pattern is used by ~11 other feature `presentation/providers/` files
  /// repo-wide.
  ///
  /// Awaits [contentDatabaseProvider] so the repository is only created once
  /// the content DB is ready (extraction completes on first launch).
  // keepAlive: singleton repository wrapping the content-DB DAOs must survive rebuilds for the app's lifetime.
  TextCacheRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'textCacheRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$textCacheRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<TextCacheRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TextCacheRepository> create(Ref ref) {
    return textCacheRepository(ref);
  }
}

String _$textCacheRepositoryHash() =>
    r'fcec3dbb01529902bf57125cb634a2f91cdf9aac';

/// Provider for fetching text by Sefaria reference.

@ProviderFor(textContent)
final textContentProvider = TextContentFamily._();

/// Provider for fetching text by Sefaria reference.

final class TextContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<TextContent?>,
          TextContent?,
          FutureOr<TextContent?>
        >
    with $FutureModifier<TextContent?>, $FutureProvider<TextContent?> {
  /// Provider for fetching text by Sefaria reference.
  TextContentProvider._({
    required TextContentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'textContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$textContentHash();

  @override
  String toString() {
    return r'textContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TextContent?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TextContent?> create(Ref ref) {
    final argument = this.argument as String;
    return textContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TextContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$textContentHash() => r'5d65669a057cd40f08ca73ccf24b627f706d6ecc';

/// Provider for fetching text by Sefaria reference.

final class TextContentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TextContent?>, String> {
  TextContentFamily._()
    : super(
        retry: null,
        name: r'textContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for fetching text by Sefaria reference.

  TextContentProvider call(String sefariaRef) =>
      TextContentProvider._(argument: sefariaRef, from: this);

  @override
  String toString() => r'textContentProvider';
}

/// Facade over [currentFontSizeProvider] kept under the existing
/// `fontSizeProvider` name to avoid churning the text-display call sites.
/// The single source of truth lives in `core/preferences/`.
// keepAlive: font-size toggle must survive navigating away from the reader and back.

@ProviderFor(FontSizeNotifier)
final fontSizeProvider = FontSizeNotifierProvider._();

/// Facade over [currentFontSizeProvider] kept under the existing
/// `fontSizeProvider` name to avoid churning the text-display call sites.
/// The single source of truth lives in `core/preferences/`.
// keepAlive: font-size toggle must survive navigating away from the reader and back.
final class FontSizeNotifierProvider
    extends $NotifierProvider<FontSizeNotifier, FontSize> {
  /// Facade over [currentFontSizeProvider] kept under the existing
  /// `fontSizeProvider` name to avoid churning the text-display call sites.
  /// The single source of truth lives in `core/preferences/`.
  // keepAlive: font-size toggle must survive navigating away from the reader and back.
  FontSizeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontSizeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontSizeNotifierHash();

  @$internal
  @override
  FontSizeNotifier create() => FontSizeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FontSize value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FontSize>(value),
    );
  }
}

String _$fontSizeNotifierHash() => r'64cc147b8512d7c80dd0dbc989f10bce81efaabf';

/// Facade over [currentFontSizeProvider] kept under the existing
/// `fontSizeProvider` name to avoid churning the text-display call sites.
/// The single source of truth lives in `core/preferences/`.
// keepAlive: font-size toggle must survive navigating away from the reader and back.

abstract class _$FontSizeNotifier extends $Notifier<FontSize> {
  FontSize build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FontSize, FontSize>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FontSize, FontSize>,
              FontSize,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Facade over [showNikudPrefProvider] kept under the existing
/// `showNikudProvider` name to avoid churning consumers.
// keepAlive: nikud-visibility toggle must survive navigating away from the reader and back.

@ProviderFor(ShowNikud)
final showNikudProvider = ShowNikudProvider._();

/// Facade over [showNikudPrefProvider] kept under the existing
/// `showNikudProvider` name to avoid churning consumers.
// keepAlive: nikud-visibility toggle must survive navigating away from the reader and back.
final class ShowNikudProvider extends $NotifierProvider<ShowNikud, bool> {
  /// Facade over [showNikudPrefProvider] kept under the existing
  /// `showNikudProvider` name to avoid churning consumers.
  // keepAlive: nikud-visibility toggle must survive navigating away from the reader and back.
  ShowNikudProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showNikudProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showNikudHash();

  @$internal
  @override
  ShowNikud create() => ShowNikud();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showNikudHash() => r'ce289c2aa555eb79f9c4d3d96ca3b72c7363a19e';

/// Facade over [showNikudPrefProvider] kept under the existing
/// `showNikudProvider` name to avoid churning consumers.
// keepAlive: nikud-visibility toggle must survive navigating away from the reader and back.

abstract class _$ShowNikud extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
