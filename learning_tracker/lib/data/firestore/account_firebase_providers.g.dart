// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_firebase_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The single [AccountFirebase] registry instance for this app session
/// (AD-2: "Exactly one place (`AccountFirebase` registry) constructs and
/// caches handles").
///
/// `keepAlive` — the registry owns per-account [FirebaseApp][fa] lifecycle
/// itself (see `account_firebase.dart`'s class doc: "idempotent resolve...
/// bounded, not silently evicting"); this provider must never be rebuilt on
/// a widget rebuild, or every named app it has already created would be
/// orphaned (a fresh `AccountFirebase()` has an empty handle cache, even
/// though the native `FirebaseApp`s from the old instance are still alive
/// and now unreachable — this is the "must not create/destroy apps on
/// widget rebuilds" invariant the story asks for).
///
/// [fa]: https://pub.dev/documentation/firebase_core/latest/firebase_core/FirebaseApp-class.html
///
/// **`maxAccounts` is [kMaxDeviceAccounts] + 1, not [kMaxDeviceAccounts] —
/// deliberately, a Phase 1 Story D finding.** `AccountFirebase.resolve`'s
/// bound check and Riverpod's `autoDispose` family-member teardown are two
/// independently-scheduled things: when [activeAccountFirebaseProvider]
/// moves from account A to account B, the family member for A does not lose
/// its listener and get disposed (which is what runs `ref.onDispose` →
/// `registry.dispose(A)`) synchronously with B's resolve — Riverpod
/// schedules that teardown via its own `ProviderScheduler`, which can run
/// strictly after B's `resolve()` call already evaluated the bound check.
/// Confirmed by a deterministic unit test
/// (`test/data/firestore/account_switch_lifecycle_test.dart`, the "FINDING"
/// test in its "the ≤5 bound interacts correctly with switching" group): at
/// a bound
/// exactly equal to the number of accounts already resolved, a back-to-back
/// switch (no yield to the event loop between the two `setAccountId` calls)
/// spuriously throws [MaxAccountsReachedException] even though A truly is
/// being released — reproduced even with an INSTANT (non-artificially-slow)
/// `app.delete()`, so it is not merely a "slow native call" edge case. One
/// account of headroom absorbs exactly this transient A-still-counted/
/// B-just-requested overlap without weakening the real, DB-enforced ≤5
/// **owned**-account cap ([kMaxDeviceAccounts] itself, `DeviceRegistryDatabase
/// .addAccount`) — that cap is untouched; this is purely a concurrently-
/// resolved-named-apps cushion in the in-memory registry. Steady state
/// (after the scheduled teardown actually runs) still settles back to
/// ≤[kMaxDeviceAccounts] active apps, verified by the same test file's
/// sequential/cyclic-switch coverage.

@ProviderFor(accountFirebaseRegistry)
final accountFirebaseRegistryProvider = AccountFirebaseRegistryProvider._();

/// The single [AccountFirebase] registry instance for this app session
/// (AD-2: "Exactly one place (`AccountFirebase` registry) constructs and
/// caches handles").
///
/// `keepAlive` — the registry owns per-account [FirebaseApp][fa] lifecycle
/// itself (see `account_firebase.dart`'s class doc: "idempotent resolve...
/// bounded, not silently evicting"); this provider must never be rebuilt on
/// a widget rebuild, or every named app it has already created would be
/// orphaned (a fresh `AccountFirebase()` has an empty handle cache, even
/// though the native `FirebaseApp`s from the old instance are still alive
/// and now unreachable — this is the "must not create/destroy apps on
/// widget rebuilds" invariant the story asks for).
///
/// [fa]: https://pub.dev/documentation/firebase_core/latest/firebase_core/FirebaseApp-class.html
///
/// **`maxAccounts` is [kMaxDeviceAccounts] + 1, not [kMaxDeviceAccounts] —
/// deliberately, a Phase 1 Story D finding.** `AccountFirebase.resolve`'s
/// bound check and Riverpod's `autoDispose` family-member teardown are two
/// independently-scheduled things: when [activeAccountFirebaseProvider]
/// moves from account A to account B, the family member for A does not lose
/// its listener and get disposed (which is what runs `ref.onDispose` →
/// `registry.dispose(A)`) synchronously with B's resolve — Riverpod
/// schedules that teardown via its own `ProviderScheduler`, which can run
/// strictly after B's `resolve()` call already evaluated the bound check.
/// Confirmed by a deterministic unit test
/// (`test/data/firestore/account_switch_lifecycle_test.dart`, the "FINDING"
/// test in its "the ≤5 bound interacts correctly with switching" group): at
/// a bound
/// exactly equal to the number of accounts already resolved, a back-to-back
/// switch (no yield to the event loop between the two `setAccountId` calls)
/// spuriously throws [MaxAccountsReachedException] even though A truly is
/// being released — reproduced even with an INSTANT (non-artificially-slow)
/// `app.delete()`, so it is not merely a "slow native call" edge case. One
/// account of headroom absorbs exactly this transient A-still-counted/
/// B-just-requested overlap without weakening the real, DB-enforced ≤5
/// **owned**-account cap ([kMaxDeviceAccounts] itself, `DeviceRegistryDatabase
/// .addAccount`) — that cap is untouched; this is purely a concurrently-
/// resolved-named-apps cushion in the in-memory registry. Steady state
/// (after the scheduled teardown actually runs) still settles back to
/// ≤[kMaxDeviceAccounts] active apps, verified by the same test file's
/// sequential/cyclic-switch coverage.

final class AccountFirebaseRegistryProvider
    extends
        $FunctionalProvider<AccountFirebase, AccountFirebase, AccountFirebase>
    with $Provider<AccountFirebase> {
  /// The single [AccountFirebase] registry instance for this app session
  /// (AD-2: "Exactly one place (`AccountFirebase` registry) constructs and
  /// caches handles").
  ///
  /// `keepAlive` — the registry owns per-account [FirebaseApp][fa] lifecycle
  /// itself (see `account_firebase.dart`'s class doc: "idempotent resolve...
  /// bounded, not silently evicting"); this provider must never be rebuilt on
  /// a widget rebuild, or every named app it has already created would be
  /// orphaned (a fresh `AccountFirebase()` has an empty handle cache, even
  /// though the native `FirebaseApp`s from the old instance are still alive
  /// and now unreachable — this is the "must not create/destroy apps on
  /// widget rebuilds" invariant the story asks for).
  ///
  /// [fa]: https://pub.dev/documentation/firebase_core/latest/firebase_core/FirebaseApp-class.html
  ///
  /// **`maxAccounts` is [kMaxDeviceAccounts] + 1, not [kMaxDeviceAccounts] —
  /// deliberately, a Phase 1 Story D finding.** `AccountFirebase.resolve`'s
  /// bound check and Riverpod's `autoDispose` family-member teardown are two
  /// independently-scheduled things: when [activeAccountFirebaseProvider]
  /// moves from account A to account B, the family member for A does not lose
  /// its listener and get disposed (which is what runs `ref.onDispose` →
  /// `registry.dispose(A)`) synchronously with B's resolve — Riverpod
  /// schedules that teardown via its own `ProviderScheduler`, which can run
  /// strictly after B's `resolve()` call already evaluated the bound check.
  /// Confirmed by a deterministic unit test
  /// (`test/data/firestore/account_switch_lifecycle_test.dart`, the "FINDING"
  /// test in its "the ≤5 bound interacts correctly with switching" group): at
  /// a bound
  /// exactly equal to the number of accounts already resolved, a back-to-back
  /// switch (no yield to the event loop between the two `setAccountId` calls)
  /// spuriously throws [MaxAccountsReachedException] even though A truly is
  /// being released — reproduced even with an INSTANT (non-artificially-slow)
  /// `app.delete()`, so it is not merely a "slow native call" edge case. One
  /// account of headroom absorbs exactly this transient A-still-counted/
  /// B-just-requested overlap without weakening the real, DB-enforced ≤5
  /// **owned**-account cap ([kMaxDeviceAccounts] itself, `DeviceRegistryDatabase
  /// .addAccount`) — that cap is untouched; this is purely a concurrently-
  /// resolved-named-apps cushion in the in-memory registry. Steady state
  /// (after the scheduled teardown actually runs) still settles back to
  /// ≤[kMaxDeviceAccounts] active apps, verified by the same test file's
  /// sequential/cyclic-switch coverage.
  AccountFirebaseRegistryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountFirebaseRegistryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountFirebaseRegistryHash();

  @$internal
  @override
  $ProviderElement<AccountFirebase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountFirebase create(Ref ref) {
    return accountFirebaseRegistry(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountFirebase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountFirebase>(value),
    );
  }
}

String _$accountFirebaseRegistryHash() =>
    r'5db23c936e9d27ae9395b67b884bb045c6f15249';

/// Resolves [accountId]'s [AccountFirebaseHandles] — the plan's
/// `accountFirebase(activeAccountId)` (migration-plan Phase 1: "Wire handle
/// resolution (`accountFirebase(activeAccountId)`)").
///
/// **Flag ON (default).** Routes through [accountFirebaseRegistryProvider],
/// i.e. `AccountFirebase.resolve` — a real per-account named `FirebaseApp`.
/// [AccountFirebase.resolve] is itself idempotent and memoized, so
/// re-watching this provider (a widget rebuild, e.g.) never re-creates or
/// tears down the app: it returns the same cached handles.
///
/// **Flag OFF (rollback).** Never touches the registry or
/// `Firebase.initializeApp(name:)` — returns [_legacyHandles], a shim over
/// the pre-Phase-1 default-app singletons, so the fallback path is
/// genuinely reachable rather than a dead branch (see
/// `test/data/firestore/account_firebase_providers_test.dart`'s red-demo).
///
/// **Disposal on account switch.** `@riverpod` with a parameter generates
/// an `autoDispose` family. Once nothing watches
/// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
/// e.g. [activeAccountFirebaseProvider] switches to watching a different
/// id — Riverpod schedules this provider instance for disposal, which
/// tears down that (and only that) account's named app via
/// [AccountFirebase.dispose]. The registry singleton itself, and every
/// OTHER account's handles it holds, are untouched.
///
/// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
/// below — this ordering is load-bearing (defect #1 fix).** `Ref.onDispose`
/// throws `UnmountedRefException` if the provider is already disposed
/// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
/// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
/// real native `initializeApp` call — hundreds of milliseconds on-device —
/// so a caller that switches accounts again before it settles (e.g. rapid
/// A→B) disposes THIS provider instance mid-`await`. If `onDispose` were
/// registered only after the `await` (the pre-fix ordering), that
/// registration call would itself throw in exactly that window — and
/// because the throw happens AFTER `resolve` already completed and cached
/// the handles in the registry, nothing would ever call
/// [AccountFirebase.dispose] for this account: its named app + persistent
/// cache would be pinned for the rest of the process. Registering the
/// teardown first means it exists no matter when disposal happens; the
/// closure only closes over `registry`/`accountId` (never `ref`), so it
/// stays safe to invoke even after `ref` itself is unmounted, and the
/// `_disposeCalledOnce` guard makes it safe to invoke a second time from
/// the `!ref.mounted` branch below without double-disposing (itself also
/// safe per [AccountFirebase.dispose]'s own idempotency, but kept explicit
/// here rather than relied upon implicitly).

@ProviderFor(accountFirebase)
final accountFirebaseProvider = AccountFirebaseFamily._();

/// Resolves [accountId]'s [AccountFirebaseHandles] — the plan's
/// `accountFirebase(activeAccountId)` (migration-plan Phase 1: "Wire handle
/// resolution (`accountFirebase(activeAccountId)`)").
///
/// **Flag ON (default).** Routes through [accountFirebaseRegistryProvider],
/// i.e. `AccountFirebase.resolve` — a real per-account named `FirebaseApp`.
/// [AccountFirebase.resolve] is itself idempotent and memoized, so
/// re-watching this provider (a widget rebuild, e.g.) never re-creates or
/// tears down the app: it returns the same cached handles.
///
/// **Flag OFF (rollback).** Never touches the registry or
/// `Firebase.initializeApp(name:)` — returns [_legacyHandles], a shim over
/// the pre-Phase-1 default-app singletons, so the fallback path is
/// genuinely reachable rather than a dead branch (see
/// `test/data/firestore/account_firebase_providers_test.dart`'s red-demo).
///
/// **Disposal on account switch.** `@riverpod` with a parameter generates
/// an `autoDispose` family. Once nothing watches
/// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
/// e.g. [activeAccountFirebaseProvider] switches to watching a different
/// id — Riverpod schedules this provider instance for disposal, which
/// tears down that (and only that) account's named app via
/// [AccountFirebase.dispose]. The registry singleton itself, and every
/// OTHER account's handles it holds, are untouched.
///
/// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
/// below — this ordering is load-bearing (defect #1 fix).** `Ref.onDispose`
/// throws `UnmountedRefException` if the provider is already disposed
/// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
/// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
/// real native `initializeApp` call — hundreds of milliseconds on-device —
/// so a caller that switches accounts again before it settles (e.g. rapid
/// A→B) disposes THIS provider instance mid-`await`. If `onDispose` were
/// registered only after the `await` (the pre-fix ordering), that
/// registration call would itself throw in exactly that window — and
/// because the throw happens AFTER `resolve` already completed and cached
/// the handles in the registry, nothing would ever call
/// [AccountFirebase.dispose] for this account: its named app + persistent
/// cache would be pinned for the rest of the process. Registering the
/// teardown first means it exists no matter when disposal happens; the
/// closure only closes over `registry`/`accountId` (never `ref`), so it
/// stays safe to invoke even after `ref` itself is unmounted, and the
/// `_disposeCalledOnce` guard makes it safe to invoke a second time from
/// the `!ref.mounted` branch below without double-disposing (itself also
/// safe per [AccountFirebase.dispose]'s own idempotency, but kept explicit
/// here rather than relied upon implicitly).

final class AccountFirebaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountFirebaseHandles>,
          AccountFirebaseHandles,
          FutureOr<AccountFirebaseHandles>
        >
    with
        $FutureModifier<AccountFirebaseHandles>,
        $FutureProvider<AccountFirebaseHandles> {
  /// Resolves [accountId]'s [AccountFirebaseHandles] — the plan's
  /// `accountFirebase(activeAccountId)` (migration-plan Phase 1: "Wire handle
  /// resolution (`accountFirebase(activeAccountId)`)").
  ///
  /// **Flag ON (default).** Routes through [accountFirebaseRegistryProvider],
  /// i.e. `AccountFirebase.resolve` — a real per-account named `FirebaseApp`.
  /// [AccountFirebase.resolve] is itself idempotent and memoized, so
  /// re-watching this provider (a widget rebuild, e.g.) never re-creates or
  /// tears down the app: it returns the same cached handles.
  ///
  /// **Flag OFF (rollback).** Never touches the registry or
  /// `Firebase.initializeApp(name:)` — returns [_legacyHandles], a shim over
  /// the pre-Phase-1 default-app singletons, so the fallback path is
  /// genuinely reachable rather than a dead branch (see
  /// `test/data/firestore/account_firebase_providers_test.dart`'s red-demo).
  ///
  /// **Disposal on account switch.** `@riverpod` with a parameter generates
  /// an `autoDispose` family. Once nothing watches
  /// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
  /// e.g. [activeAccountFirebaseProvider] switches to watching a different
  /// id — Riverpod schedules this provider instance for disposal, which
  /// tears down that (and only that) account's named app via
  /// [AccountFirebase.dispose]. The registry singleton itself, and every
  /// OTHER account's handles it holds, are untouched.
  ///
  /// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
  /// below — this ordering is load-bearing (defect #1 fix).** `Ref.onDispose`
  /// throws `UnmountedRefException` if the provider is already disposed
  /// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
  /// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
  /// real native `initializeApp` call — hundreds of milliseconds on-device —
  /// so a caller that switches accounts again before it settles (e.g. rapid
  /// A→B) disposes THIS provider instance mid-`await`. If `onDispose` were
  /// registered only after the `await` (the pre-fix ordering), that
  /// registration call would itself throw in exactly that window — and
  /// because the throw happens AFTER `resolve` already completed and cached
  /// the handles in the registry, nothing would ever call
  /// [AccountFirebase.dispose] for this account: its named app + persistent
  /// cache would be pinned for the rest of the process. Registering the
  /// teardown first means it exists no matter when disposal happens; the
  /// closure only closes over `registry`/`accountId` (never `ref`), so it
  /// stays safe to invoke even after `ref` itself is unmounted, and the
  /// `_disposeCalledOnce` guard makes it safe to invoke a second time from
  /// the `!ref.mounted` branch below without double-disposing (itself also
  /// safe per [AccountFirebase.dispose]'s own idempotency, but kept explicit
  /// here rather than relied upon implicitly).
  AccountFirebaseProvider._({
    required AccountFirebaseFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountFirebaseProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$accountFirebaseHash();

  @override
  String toString() {
    return r'accountFirebaseProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<AccountFirebaseHandles> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AccountFirebaseHandles> create(Ref ref) {
    final argument = this.argument as String;
    return accountFirebase(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AccountFirebaseProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$accountFirebaseHash() => r'e8d3111f8892aed29096a20f9c87581f5d19dd56';

/// Resolves [accountId]'s [AccountFirebaseHandles] — the plan's
/// `accountFirebase(activeAccountId)` (migration-plan Phase 1: "Wire handle
/// resolution (`accountFirebase(activeAccountId)`)").
///
/// **Flag ON (default).** Routes through [accountFirebaseRegistryProvider],
/// i.e. `AccountFirebase.resolve` — a real per-account named `FirebaseApp`.
/// [AccountFirebase.resolve] is itself idempotent and memoized, so
/// re-watching this provider (a widget rebuild, e.g.) never re-creates or
/// tears down the app: it returns the same cached handles.
///
/// **Flag OFF (rollback).** Never touches the registry or
/// `Firebase.initializeApp(name:)` — returns [_legacyHandles], a shim over
/// the pre-Phase-1 default-app singletons, so the fallback path is
/// genuinely reachable rather than a dead branch (see
/// `test/data/firestore/account_firebase_providers_test.dart`'s red-demo).
///
/// **Disposal on account switch.** `@riverpod` with a parameter generates
/// an `autoDispose` family. Once nothing watches
/// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
/// e.g. [activeAccountFirebaseProvider] switches to watching a different
/// id — Riverpod schedules this provider instance for disposal, which
/// tears down that (and only that) account's named app via
/// [AccountFirebase.dispose]. The registry singleton itself, and every
/// OTHER account's handles it holds, are untouched.
///
/// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
/// below — this ordering is load-bearing (defect #1 fix).** `Ref.onDispose`
/// throws `UnmountedRefException` if the provider is already disposed
/// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
/// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
/// real native `initializeApp` call — hundreds of milliseconds on-device —
/// so a caller that switches accounts again before it settles (e.g. rapid
/// A→B) disposes THIS provider instance mid-`await`. If `onDispose` were
/// registered only after the `await` (the pre-fix ordering), that
/// registration call would itself throw in exactly that window — and
/// because the throw happens AFTER `resolve` already completed and cached
/// the handles in the registry, nothing would ever call
/// [AccountFirebase.dispose] for this account: its named app + persistent
/// cache would be pinned for the rest of the process. Registering the
/// teardown first means it exists no matter when disposal happens; the
/// closure only closes over `registry`/`accountId` (never `ref`), so it
/// stays safe to invoke even after `ref` itself is unmounted, and the
/// `_disposeCalledOnce` guard makes it safe to invoke a second time from
/// the `!ref.mounted` branch below without double-disposing (itself also
/// safe per [AccountFirebase.dispose]'s own idempotency, but kept explicit
/// here rather than relied upon implicitly).

final class AccountFirebaseFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AccountFirebaseHandles>, String> {
  AccountFirebaseFamily._()
    : super(
        retry: null,
        name: r'accountFirebaseProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves [accountId]'s [AccountFirebaseHandles] — the plan's
  /// `accountFirebase(activeAccountId)` (migration-plan Phase 1: "Wire handle
  /// resolution (`accountFirebase(activeAccountId)`)").
  ///
  /// **Flag ON (default).** Routes through [accountFirebaseRegistryProvider],
  /// i.e. `AccountFirebase.resolve` — a real per-account named `FirebaseApp`.
  /// [AccountFirebase.resolve] is itself idempotent and memoized, so
  /// re-watching this provider (a widget rebuild, e.g.) never re-creates or
  /// tears down the app: it returns the same cached handles.
  ///
  /// **Flag OFF (rollback).** Never touches the registry or
  /// `Firebase.initializeApp(name:)` — returns [_legacyHandles], a shim over
  /// the pre-Phase-1 default-app singletons, so the fallback path is
  /// genuinely reachable rather than a dead branch (see
  /// `test/data/firestore/account_firebase_providers_test.dart`'s red-demo).
  ///
  /// **Disposal on account switch.** `@riverpod` with a parameter generates
  /// an `autoDispose` family. Once nothing watches
  /// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
  /// e.g. [activeAccountFirebaseProvider] switches to watching a different
  /// id — Riverpod schedules this provider instance for disposal, which
  /// tears down that (and only that) account's named app via
  /// [AccountFirebase.dispose]. The registry singleton itself, and every
  /// OTHER account's handles it holds, are untouched.
  ///
  /// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
  /// below — this ordering is load-bearing (defect #1 fix).** `Ref.onDispose`
  /// throws `UnmountedRefException` if the provider is already disposed
  /// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
  /// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
  /// real native `initializeApp` call — hundreds of milliseconds on-device —
  /// so a caller that switches accounts again before it settles (e.g. rapid
  /// A→B) disposes THIS provider instance mid-`await`. If `onDispose` were
  /// registered only after the `await` (the pre-fix ordering), that
  /// registration call would itself throw in exactly that window — and
  /// because the throw happens AFTER `resolve` already completed and cached
  /// the handles in the registry, nothing would ever call
  /// [AccountFirebase.dispose] for this account: its named app + persistent
  /// cache would be pinned for the rest of the process. Registering the
  /// teardown first means it exists no matter when disposal happens; the
  /// closure only closes over `registry`/`accountId` (never `ref`), so it
  /// stays safe to invoke even after `ref` itself is unmounted, and the
  /// `_disposeCalledOnce` guard makes it safe to invoke a second time from
  /// the `!ref.mounted` branch below without double-disposing (itself also
  /// safe per [AccountFirebase.dispose]'s own idempotency, but kept explicit
  /// here rather than relied upon implicitly).

  AccountFirebaseProvider call(String accountId) =>
      AccountFirebaseProvider._(argument: accountId, from: this);

  @override
  String toString() => r'accountFirebaseProvider';
}

/// Convenience provider: [accountFirebaseProvider] for whichever account
/// [activeAccountIdProvider] currently names, or `null` if no account is
/// active yet (fresh install / signed out). Phase 2/3 repository code
/// watches this instead of threading an explicit account id through every
/// call site.

@ProviderFor(activeAccountFirebase)
final activeAccountFirebaseProvider = ActiveAccountFirebaseProvider._();

/// Convenience provider: [accountFirebaseProvider] for whichever account
/// [activeAccountIdProvider] currently names, or `null` if no account is
/// active yet (fresh install / signed out). Phase 2/3 repository code
/// watches this instead of threading an explicit account id through every
/// call site.

final class ActiveAccountFirebaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AccountFirebaseHandles?>,
          AccountFirebaseHandles?,
          FutureOr<AccountFirebaseHandles?>
        >
    with
        $FutureModifier<AccountFirebaseHandles?>,
        $FutureProvider<AccountFirebaseHandles?> {
  /// Convenience provider: [accountFirebaseProvider] for whichever account
  /// [activeAccountIdProvider] currently names, or `null` if no account is
  /// active yet (fresh install / signed out). Phase 2/3 repository code
  /// watches this instead of threading an explicit account id through every
  /// call site.
  ActiveAccountFirebaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAccountFirebaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAccountFirebaseHash();

  @$internal
  @override
  $FutureProviderElement<AccountFirebaseHandles?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AccountFirebaseHandles?> create(Ref ref) {
    return activeAccountFirebase(ref);
  }
}

String _$activeAccountFirebaseHash() =>
    r'6a18371641ee7bfe274e290bbf61e952804ff87b';

/// The device account id the app is currently operating as (AD-24: the
/// stable device-registry account UUID, never the live Firebase uid).
///
/// Mirrors [AccountDbFileName] (`core/providers/database_provider.dart`) —
/// this codebase's existing pattern for "the active account" as a
/// settable, `keepAlive` Riverpod notifier, rather than an ad hoc re-read
/// on every access. The value this notifier is meant to carry is the SAME
/// id [SessionPersistenceService.resolveActiveAccountId] /
/// [DeviceRegistryDatabase.getLastActiveAccountId] already resolve today
/// (`app/bootstrap/account_bootstrap.dart` computes this id at startup
/// already — currently only to look up a `dbFileName`, since no Riverpod
/// consumer of the bare account id existed before this story).
///
/// **Not wired into `main.dart`/`account_bootstrap.dart` by this story.**
/// Phase 1 "ships to users: nothing yet" (no repository reads through the
/// registry until Phase 2/3 — migration plan), so there is no real
/// consumer yet that needs a live value; wiring a `ProviderScope` override
/// at bootstrap (mirroring [AccountDbFileName]'s) and threading
/// [setAccountId] into the same sign-in/switch/sign-out call sites that
/// already call `accountDbFileNameProvider.notifier.setFileName(...)` is
/// the natural Phase 2/3 follow-up, once a real caller needs it. The
/// notifier exists now so [accountFirebaseProvider]'s family key has a
/// documented, testable source rather than an invented one.

@ProviderFor(ActiveAccountId)
final activeAccountIdProvider = ActiveAccountIdProvider._();

/// The device account id the app is currently operating as (AD-24: the
/// stable device-registry account UUID, never the live Firebase uid).
///
/// Mirrors [AccountDbFileName] (`core/providers/database_provider.dart`) —
/// this codebase's existing pattern for "the active account" as a
/// settable, `keepAlive` Riverpod notifier, rather than an ad hoc re-read
/// on every access. The value this notifier is meant to carry is the SAME
/// id [SessionPersistenceService.resolveActiveAccountId] /
/// [DeviceRegistryDatabase.getLastActiveAccountId] already resolve today
/// (`app/bootstrap/account_bootstrap.dart` computes this id at startup
/// already — currently only to look up a `dbFileName`, since no Riverpod
/// consumer of the bare account id existed before this story).
///
/// **Not wired into `main.dart`/`account_bootstrap.dart` by this story.**
/// Phase 1 "ships to users: nothing yet" (no repository reads through the
/// registry until Phase 2/3 — migration plan), so there is no real
/// consumer yet that needs a live value; wiring a `ProviderScope` override
/// at bootstrap (mirroring [AccountDbFileName]'s) and threading
/// [setAccountId] into the same sign-in/switch/sign-out call sites that
/// already call `accountDbFileNameProvider.notifier.setFileName(...)` is
/// the natural Phase 2/3 follow-up, once a real caller needs it. The
/// notifier exists now so [accountFirebaseProvider]'s family key has a
/// documented, testable source rather than an invented one.
final class ActiveAccountIdProvider
    extends $NotifierProvider<ActiveAccountId, String?> {
  /// The device account id the app is currently operating as (AD-24: the
  /// stable device-registry account UUID, never the live Firebase uid).
  ///
  /// Mirrors [AccountDbFileName] (`core/providers/database_provider.dart`) —
  /// this codebase's existing pattern for "the active account" as a
  /// settable, `keepAlive` Riverpod notifier, rather than an ad hoc re-read
  /// on every access. The value this notifier is meant to carry is the SAME
  /// id [SessionPersistenceService.resolveActiveAccountId] /
  /// [DeviceRegistryDatabase.getLastActiveAccountId] already resolve today
  /// (`app/bootstrap/account_bootstrap.dart` computes this id at startup
  /// already — currently only to look up a `dbFileName`, since no Riverpod
  /// consumer of the bare account id existed before this story).
  ///
  /// **Not wired into `main.dart`/`account_bootstrap.dart` by this story.**
  /// Phase 1 "ships to users: nothing yet" (no repository reads through the
  /// registry until Phase 2/3 — migration plan), so there is no real
  /// consumer yet that needs a live value; wiring a `ProviderScope` override
  /// at bootstrap (mirroring [AccountDbFileName]'s) and threading
  /// [setAccountId] into the same sign-in/switch/sign-out call sites that
  /// already call `accountDbFileNameProvider.notifier.setFileName(...)` is
  /// the natural Phase 2/3 follow-up, once a real caller needs it. The
  /// notifier exists now so [accountFirebaseProvider]'s family key has a
  /// documented, testable source rather than an invented one.
  ActiveAccountIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAccountIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAccountIdHash();

  @$internal
  @override
  ActiveAccountId create() => ActiveAccountId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeAccountIdHash() => r'c0adeb0923a66e1a249cf3b8c2b04c4dcbb45d84';

/// The device account id the app is currently operating as (AD-24: the
/// stable device-registry account UUID, never the live Firebase uid).
///
/// Mirrors [AccountDbFileName] (`core/providers/database_provider.dart`) —
/// this codebase's existing pattern for "the active account" as a
/// settable, `keepAlive` Riverpod notifier, rather than an ad hoc re-read
/// on every access. The value this notifier is meant to carry is the SAME
/// id [SessionPersistenceService.resolveActiveAccountId] /
/// [DeviceRegistryDatabase.getLastActiveAccountId] already resolve today
/// (`app/bootstrap/account_bootstrap.dart` computes this id at startup
/// already — currently only to look up a `dbFileName`, since no Riverpod
/// consumer of the bare account id existed before this story).
///
/// **Not wired into `main.dart`/`account_bootstrap.dart` by this story.**
/// Phase 1 "ships to users: nothing yet" (no repository reads through the
/// registry until Phase 2/3 — migration plan), so there is no real
/// consumer yet that needs a live value; wiring a `ProviderScope` override
/// at bootstrap (mirroring [AccountDbFileName]'s) and threading
/// [setAccountId] into the same sign-in/switch/sign-out call sites that
/// already call `accountDbFileNameProvider.notifier.setFileName(...)` is
/// the natural Phase 2/3 follow-up, once a real caller needs it. The
/// notifier exists now so [accountFirebaseProvider]'s family key has a
/// documented, testable source rather than an invented one.

abstract class _$ActiveAccountId extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
