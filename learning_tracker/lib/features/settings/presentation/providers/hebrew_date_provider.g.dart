// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hebrew_date_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Global preference for Hebrew vs Gregorian calendar.
///
/// When true, all date pickers across the app use Hebrew calendar.
/// Set during onboarding or in Settings.

@ProviderFor(UseHebrewDateNotifier)
final useHebrewDateProvider = UseHebrewDateNotifierProvider._();

/// Global preference for Hebrew vs Gregorian calendar.
///
/// When true, all date pickers across the app use Hebrew calendar.
/// Set during onboarding or in Settings.
final class UseHebrewDateNotifierProvider
    extends $NotifierProvider<UseHebrewDateNotifier, bool> {
  /// Global preference for Hebrew vs Gregorian calendar.
  ///
  /// When true, all date pickers across the app use Hebrew calendar.
  /// Set during onboarding or in Settings.
  UseHebrewDateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'useHebrewDateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$useHebrewDateNotifierHash();

  @$internal
  @override
  UseHebrewDateNotifier create() => UseHebrewDateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$useHebrewDateNotifierHash() =>
    r'5ad736d30f43cda6502a8534702deb4ac5420711';

/// Global preference for Hebrew vs Gregorian calendar.
///
/// When true, all date pickers across the app use Hebrew calendar.
/// Set during onboarding or in Settings.

abstract class _$UseHebrewDateNotifier extends $Notifier<bool> {
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
