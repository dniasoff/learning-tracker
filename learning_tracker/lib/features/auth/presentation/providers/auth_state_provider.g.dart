// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Unified auth state notifier (Epic 20 v2 §3).
///
/// Single source of truth for `currentUser + tier + sessionStatus`.
/// Replaces the sealed `AppAuthState` hierarchy. Cloud-born and
/// local-born accounts differ only by backend — the UI reads the
/// same shape from this notifier regardless.

@ProviderFor(AuthStateNotifier)
final authStateProvider = AuthStateNotifierProvider._();

/// Unified auth state notifier (Epic 20 v2 §3).
///
/// Single source of truth for `currentUser + tier + sessionStatus`.
/// Replaces the sealed `AppAuthState` hierarchy. Cloud-born and
/// local-born accounts differ only by backend — the UI reads the
/// same shape from this notifier regardless.
final class AuthStateNotifierProvider
    extends $NotifierProvider<AuthStateNotifier, AuthState> {
  /// Unified auth state notifier (Epic 20 v2 §3).
  ///
  /// Single source of truth for `currentUser + tier + sessionStatus`.
  /// Replaces the sealed `AppAuthState` hierarchy. Cloud-born and
  /// local-born accounts differ only by backend — the UI reads the
  /// same shape from this notifier regardless.
  AuthStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateNotifierHash();

  @$internal
  @override
  AuthStateNotifier create() => AuthStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authStateNotifierHash() => r'a98cf12267665d88ccfc0954853a71a15acf13c4';

/// Unified auth state notifier (Epic 20 v2 §3).
///
/// Single source of truth for `currentUser + tier + sessionStatus`.
/// Replaces the sealed `AppAuthState` hierarchy. Cloud-born and
/// local-born accounts differ only by backend — the UI reads the
/// same shape from this notifier regardless.

abstract class _$AuthStateNotifier extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
