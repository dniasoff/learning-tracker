// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_display_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the text cache repository.

@ProviderFor(textCacheRepository)
final textCacheRepositoryProvider = TextCacheRepositoryProvider._();

/// Provider for the text cache repository.

final class TextCacheRepositoryProvider
    extends
        $FunctionalProvider<
          TextCacheRepository,
          TextCacheRepository,
          TextCacheRepository
        >
    with $Provider<TextCacheRepository> {
  /// Provider for the text cache repository.
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
  $ProviderElement<TextCacheRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TextCacheRepository create(Ref ref) {
    return textCacheRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TextCacheRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TextCacheRepository>(value),
    );
  }
}

String _$textCacheRepositoryHash() =>
    r'566b49d7100e94ac79428a39005321a08b2473b8';

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

String _$textContentHash() => r'3d8b7afc5e13eceb2971c02001b06bd6be1cad4a';

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

@ProviderFor(FontSizeNotifier)
final fontSizeProvider = FontSizeNotifierProvider._();

/// Facade over [currentFontSizeProvider] kept under the existing
/// `fontSizeProvider` name to avoid churning the text-display call sites.
/// The single source of truth lives in `core/preferences/`.
final class FontSizeNotifierProvider
    extends $NotifierProvider<FontSizeNotifier, FontSize> {
  /// Facade over [currentFontSizeProvider] kept under the existing
  /// `fontSizeProvider` name to avoid churning the text-display call sites.
  /// The single source of truth lives in `core/preferences/`.
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

@ProviderFor(ShowNikud)
final showNikudProvider = ShowNikudProvider._();

/// Facade over [showNikudPrefProvider] kept under the existing
/// `showNikudProvider` name to avoid churning consumers.
final class ShowNikudProvider extends $NotifierProvider<ShowNikud, bool> {
  /// Facade over [showNikudPrefProvider] kept under the existing
  /// `showNikudProvider` name to avoid churning consumers.
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

/// Provider for the text download service.

@ProviderFor(textDownloadService)
final textDownloadServiceProvider = TextDownloadServiceProvider._();

/// Provider for the text download service.

final class TextDownloadServiceProvider
    extends
        $FunctionalProvider<
          TextDownloadService,
          TextDownloadService,
          TextDownloadService
        >
    with $Provider<TextDownloadService> {
  /// Provider for the text download service.
  TextDownloadServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'textDownloadServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$textDownloadServiceHash();

  @$internal
  @override
  $ProviderElement<TextDownloadService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TextDownloadService create(Ref ref) {
    return textDownloadService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TextDownloadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TextDownloadService>(value),
    );
  }
}

String _$textDownloadServiceHash() =>
    r'a987e52b2e5676915260301373156324862e785e';

/// Provider to check if text is downloaded for a curriculum.

@ProviderFor(isTextDownloaded)
final isTextDownloadedProvider = IsTextDownloadedFamily._();

/// Provider to check if text is downloaded for a curriculum.

final class IsTextDownloadedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider to check if text is downloaded for a curriculum.
  IsTextDownloadedProvider._({
    required IsTextDownloadedFamily super.from,
    required CurriculumId super.argument,
  }) : super(
         retry: null,
         name: r'isTextDownloadedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isTextDownloadedHash();

  @override
  String toString() {
    return r'isTextDownloadedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as CurriculumId;
    return isTextDownloaded(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsTextDownloadedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isTextDownloadedHash() => r'66560b414647f93881bef2085d81432201cee91d';

/// Provider to check if text is downloaded for a curriculum.

final class IsTextDownloadedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, CurriculumId> {
  IsTextDownloadedFamily._()
    : super(
        retry: null,
        name: r'isTextDownloadedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to check if text is downloaded for a curriculum.

  IsTextDownloadedProvider call(CurriculumId curriculumId) =>
      IsTextDownloadedProvider._(argument: curriculumId, from: this);

  @override
  String toString() => r'isTextDownloadedProvider';
}
