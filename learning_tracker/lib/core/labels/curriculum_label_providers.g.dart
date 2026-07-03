// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curriculum_label_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Renders the **full breadcrumb chain** for [sefariaRef] as a single
/// string joined by ` › ` (e.g. "זרעים › ברכות › פרק א › משנה א" in
/// Hebrew mode). Looks up the matching `ContentItem` for the leaf AND
/// for each ancestor segment so every named level renders in Hebrew,
/// not just the leaf. Callers should render the result in a `Text` that
/// allows wrapping so the chain stays legible on narrow widgets.

@ProviderFor(renderedDisplayForRef)
final renderedDisplayForRefProvider = RenderedDisplayForRefFamily._();

/// Renders the **full breadcrumb chain** for [sefariaRef] as a single
/// string joined by ` › ` (e.g. "זרעים › ברכות › פרק א › משנה א" in
/// Hebrew mode). Looks up the matching `ContentItem` for the leaf AND
/// for each ancestor segment so every named level renders in Hebrew,
/// not just the leaf. Callers should render the result in a `Text` that
/// allows wrapping so the chain stays legible on narrow widgets.

final class RenderedDisplayForRefProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Renders the **full breadcrumb chain** for [sefariaRef] as a single
  /// string joined by ` › ` (e.g. "זרעים › ברכות › פרק א › משנה א" in
  /// Hebrew mode). Looks up the matching `ContentItem` for the leaf AND
  /// for each ancestor segment so every named level renders in Hebrew,
  /// not just the leaf. Callers should render the result in a `Text` that
  /// allows wrapping so the chain stays legible on narrow widgets.
  RenderedDisplayForRefProvider._({
    required RenderedDisplayForRefFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'renderedDisplayForRefProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$renderedDisplayForRefHash();

  @override
  String toString() {
    return r'renderedDisplayForRefProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return renderedDisplayForRef(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RenderedDisplayForRefProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$renderedDisplayForRefHash() =>
    r'7ce376f0c36a994a9f22d9c65674797095f2e611';

/// Renders the **full breadcrumb chain** for [sefariaRef] as a single
/// string joined by ` › ` (e.g. "זרעים › ברכות › פרק א › משנה א" in
/// Hebrew mode). Looks up the matching `ContentItem` for the leaf AND
/// for each ancestor segment so every named level renders in Hebrew,
/// not just the leaf. Callers should render the result in a `Text` that
/// allows wrapping so the chain stays legible on narrow widgets.

final class RenderedDisplayForRefFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  RenderedDisplayForRefFamily._()
    : super(
        retry: null,
        name: r'renderedDisplayForRefProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Renders the **full breadcrumb chain** for [sefariaRef] as a single
  /// string joined by ` › ` (e.g. "זרעים › ברכות › פרק א › משנה א" in
  /// Hebrew mode). Looks up the matching `ContentItem` for the leaf AND
  /// for each ancestor segment so every named level renders in Hebrew,
  /// not just the leaf. Callers should render the result in a `Text` that
  /// allows wrapping so the chain stays legible on narrow widgets.

  RenderedDisplayForRefProvider call(String sefariaRef) =>
      RenderedDisplayForRefProvider._(argument: sefariaRef, from: this);

  @override
  String toString() => r'renderedDisplayForRefProvider';
}

/// Renders just the leaf segment of [sefariaRef] (e.g. "משנה א"). Useful
/// when the caller already shows ancestor context elsewhere and doesn't
/// want to duplicate it.

@ProviderFor(renderedLeafForRef)
final renderedLeafForRefProvider = RenderedLeafForRefFamily._();

/// Renders just the leaf segment of [sefariaRef] (e.g. "משנה א"). Useful
/// when the caller already shows ancestor context elsewhere and doesn't
/// want to duplicate it.

final class RenderedLeafForRefProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Renders just the leaf segment of [sefariaRef] (e.g. "משנה א"). Useful
  /// when the caller already shows ancestor context elsewhere and doesn't
  /// want to duplicate it.
  RenderedLeafForRefProvider._({
    required RenderedLeafForRefFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'renderedLeafForRefProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$renderedLeafForRefHash();

  @override
  String toString() {
    return r'renderedLeafForRefProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return renderedLeafForRef(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RenderedLeafForRefProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$renderedLeafForRefHash() =>
    r'fbd7b989cc02a8861f4ab3aa43802f0db325f5f8';

/// Renders just the leaf segment of [sefariaRef] (e.g. "משנה א"). Useful
/// when the caller already shows ancestor context elsewhere and doesn't
/// want to duplicate it.

final class RenderedLeafForRefFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  RenderedLeafForRefFamily._()
    : super(
        retry: null,
        name: r'renderedLeafForRefProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Renders just the leaf segment of [sefariaRef] (e.g. "משנה א"). Useful
  /// when the caller already shows ancestor context elsewhere and doesn't
  /// want to duplicate it.

  RenderedLeafForRefProvider call(String sefariaRef) =>
      RenderedLeafForRefProvider._(argument: sefariaRef, from: this);

  @override
  String toString() => r'renderedLeafForRefProvider';
}

/// Renders the parent (one level above leaf) display string for [sefariaRef].
/// Used by the reader page's two-line AppBar — leaf big, parent small.
/// Returns null when the item is already at level 1.
///
/// Looks up Hebrew names for every ancestor segment (mirroring
/// [renderedDisplayForRef]) so named levels like "Seder Zeraim" or "Genesis"
/// render in Hebrew rather than as raw English organizational labels.

@ProviderFor(renderedParentForRef)
final renderedParentForRefProvider = RenderedParentForRefFamily._();

/// Renders the parent (one level above leaf) display string for [sefariaRef].
/// Used by the reader page's two-line AppBar — leaf big, parent small.
/// Returns null when the item is already at level 1.
///
/// Looks up Hebrew names for every ancestor segment (mirroring
/// [renderedDisplayForRef]) so named levels like "Seder Zeraim" or "Genesis"
/// render in Hebrew rather than as raw English organizational labels.

final class RenderedParentForRefProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Renders the parent (one level above leaf) display string for [sefariaRef].
  /// Used by the reader page's two-line AppBar — leaf big, parent small.
  /// Returns null when the item is already at level 1.
  ///
  /// Looks up Hebrew names for every ancestor segment (mirroring
  /// [renderedDisplayForRef]) so named levels like "Seder Zeraim" or "Genesis"
  /// render in Hebrew rather than as raw English organizational labels.
  RenderedParentForRefProvider._({
    required RenderedParentForRefFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'renderedParentForRefProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$renderedParentForRefHash();

  @override
  String toString() {
    return r'renderedParentForRefProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String;
    return renderedParentForRef(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RenderedParentForRefProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$renderedParentForRefHash() =>
    r'd4b8d01d3c43de09b5adb44002fed6c7af9a7c88';

/// Renders the parent (one level above leaf) display string for [sefariaRef].
/// Used by the reader page's two-line AppBar — leaf big, parent small.
/// Returns null when the item is already at level 1.
///
/// Looks up Hebrew names for every ancestor segment (mirroring
/// [renderedDisplayForRef]) so named levels like "Seder Zeraim" or "Genesis"
/// render in Hebrew rather than as raw English organizational labels.

final class RenderedParentForRefFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String> {
  RenderedParentForRefFamily._()
    : super(
        retry: null,
        name: r'renderedParentForRefProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Renders the parent (one level above leaf) display string for [sefariaRef].
  /// Used by the reader page's two-line AppBar — leaf big, parent small.
  /// Returns null when the item is already at level 1.
  ///
  /// Looks up Hebrew names for every ancestor segment (mirroring
  /// [renderedDisplayForRef]) so named levels like "Seder Zeraim" or "Genesis"
  /// render in Hebrew rather than as raw English organizational labels.

  RenderedParentForRefProvider call(String sefariaRef) =>
      RenderedParentForRefProvider._(argument: sefariaRef, from: this);

  @override
  String toString() => r'renderedParentForRefProvider';
}

/// Renders every breadcrumb segment for [sefariaRef] in order. Looks up
/// the Hebrew name of every ancestor segment so each renders in Hebrew
/// rather than the raw English value.

@ProviderFor(renderedBreadcrumbForRef)
final renderedBreadcrumbForRefProvider = RenderedBreadcrumbForRefFamily._();

/// Renders every breadcrumb segment for [sefariaRef] in order. Looks up
/// the Hebrew name of every ancestor segment so each renders in Hebrew
/// rather than the raw English value.

final class RenderedBreadcrumbForRefProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Renders every breadcrumb segment for [sefariaRef] in order. Looks up
  /// the Hebrew name of every ancestor segment so each renders in Hebrew
  /// rather than the raw English value.
  RenderedBreadcrumbForRefProvider._({
    required RenderedBreadcrumbForRefFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'renderedBreadcrumbForRefProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$renderedBreadcrumbForRefHash();

  @override
  String toString() {
    return r'renderedBreadcrumbForRefProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    final argument = this.argument as String;
    return renderedBreadcrumbForRef(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RenderedBreadcrumbForRefProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$renderedBreadcrumbForRefHash() =>
    r'7b773929492b6567d1c866769e41a7a5b8118bea';

/// Renders every breadcrumb segment for [sefariaRef] in order. Looks up
/// the Hebrew name of every ancestor segment so each renders in Hebrew
/// rather than the raw English value.

final class RenderedBreadcrumbForRefFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<String>>, String> {
  RenderedBreadcrumbForRefFamily._()
    : super(
        retry: null,
        name: r'renderedBreadcrumbForRefProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Renders every breadcrumb segment for [sefariaRef] in order. Looks up
  /// the Hebrew name of every ancestor segment so each renders in Hebrew
  /// rather than the raw English value.

  RenderedBreadcrumbForRefProvider call(String sefariaRef) =>
      RenderedBreadcrumbForRefProvider._(argument: sefariaRef, from: this);

  @override
  String toString() => r'renderedBreadcrumbForRefProvider';
}
