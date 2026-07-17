// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'switcher_sheet_pin_guard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AN-2: Whether the active profile is a child with a configured Parent PIN —
/// the guard condition that gates all escalating actions in the switcher sheet.
///
/// AUD-profiles-17: migrated from a hand-declared top-level [FutureProvider]
/// in `profile_switcher_sheet.dart` to `@riverpod` codegen (SM-1) and moved
/// under `presentation/providers/` (placement convention), matching every
/// other provider in this feature. Codegen providers are autoDispose by
/// default, so this no longer stays alive for the app's remaining lifetime
/// once read — it tears down with the switcher sheet like the rest of the
/// feature's providers. Still exposed as an overridable provider so tests
/// can inject a known result without touching [FlutterSecureStorage].

@ProviderFor(switcherSheetPinGuardRequired)
final switcherSheetPinGuardRequiredProvider =
    SwitcherSheetPinGuardRequiredProvider._();

/// AN-2: Whether the active profile is a child with a configured Parent PIN —
/// the guard condition that gates all escalating actions in the switcher sheet.
///
/// AUD-profiles-17: migrated from a hand-declared top-level [FutureProvider]
/// in `profile_switcher_sheet.dart` to `@riverpod` codegen (SM-1) and moved
/// under `presentation/providers/` (placement convention), matching every
/// other provider in this feature. Codegen providers are autoDispose by
/// default, so this no longer stays alive for the app's remaining lifetime
/// once read — it tears down with the switcher sheet like the rest of the
/// feature's providers. Still exposed as an overridable provider so tests
/// can inject a known result without touching [FlutterSecureStorage].

final class SwitcherSheetPinGuardRequiredProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// AN-2: Whether the active profile is a child with a configured Parent PIN —
  /// the guard condition that gates all escalating actions in the switcher sheet.
  ///
  /// AUD-profiles-17: migrated from a hand-declared top-level [FutureProvider]
  /// in `profile_switcher_sheet.dart` to `@riverpod` codegen (SM-1) and moved
  /// under `presentation/providers/` (placement convention), matching every
  /// other provider in this feature. Codegen providers are autoDispose by
  /// default, so this no longer stays alive for the app's remaining lifetime
  /// once read — it tears down with the switcher sheet like the rest of the
  /// feature's providers. Still exposed as an overridable provider so tests
  /// can inject a known result without touching [FlutterSecureStorage].
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
    r'f5abf2694959788d8c3b9c4b88ff2cfbb9f08573';
