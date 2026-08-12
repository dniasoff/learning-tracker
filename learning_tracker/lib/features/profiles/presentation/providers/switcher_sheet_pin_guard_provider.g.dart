// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'switcher_sheet_pin_guard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AN-2: Whether the active profile is a child with a configured Parent PIN —
/// the guard condition that gates all escalating actions in the switcher sheet.

@ProviderFor(switcherSheetPinGuardRequired)
final switcherSheetPinGuardRequiredProvider =
    SwitcherSheetPinGuardRequiredProvider._();

/// AN-2: Whether the active profile is a child with a configured Parent PIN —
/// the guard condition that gates all escalating actions in the switcher sheet.

final class SwitcherSheetPinGuardRequiredProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// AN-2: Whether the active profile is a child with a configured Parent PIN —
  /// the guard condition that gates all escalating actions in the switcher sheet.
  SwitcherSheetPinGuardRequiredProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'switcherSheetPinGuardRequiredProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$switcherSheetPinGuardRequiredHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return switcherSheetPinGuardRequired(ref);
  }
}

String _$switcherSheetPinGuardRequiredHash() =>
    r'1341f130a5e226f78b500acd049936bb9d780949';
