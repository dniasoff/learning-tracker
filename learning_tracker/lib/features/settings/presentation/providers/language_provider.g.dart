// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Facade over [currentAppLocaleProvider] exposing the selected language as a
/// plain code (e.g. `en`, `he`) for UI pickers. Writes go through
/// [CurrentAppLocale.set] so the change actually propagates to
/// `MaterialApp.locale`.

@ProviderFor(LanguageNotifier)
final languageProvider = LanguageNotifierProvider._();

/// Facade over [currentAppLocaleProvider] exposing the selected language as a
/// plain code (e.g. `en`, `he`) for UI pickers. Writes go through
/// [CurrentAppLocale.set] so the change actually propagates to
/// `MaterialApp.locale`.
final class LanguageNotifierProvider
    extends $NotifierProvider<LanguageNotifier, String> {
  /// Facade over [currentAppLocaleProvider] exposing the selected language as a
  /// plain code (e.g. `en`, `he`) for UI pickers. Writes go through
  /// [CurrentAppLocale.set] so the change actually propagates to
  /// `MaterialApp.locale`.
  LanguageNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'languageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$languageNotifierHash();

  @$internal
  @override
  LanguageNotifier create() => LanguageNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$languageNotifierHash() => r'2d57fa780da2cb5bb4c0b1e5827f1ffa46d2eeca';

/// Facade over [currentAppLocaleProvider] exposing the selected language as a
/// plain code (e.g. `en`, `he`) for UI pickers. Writes go through
/// [CurrentAppLocale.set] so the change actually propagates to
/// `MaterialApp.locale`.

abstract class _$LanguageNotifier extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
