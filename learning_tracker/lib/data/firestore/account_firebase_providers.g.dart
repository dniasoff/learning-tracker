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
/// **Process-teardown hook.** `ref.onDispose` here runs [AccountFirebase
/// .disposeAll] (fire-and-forget — `onDispose` callbacks are synchronous;
/// there is nothing further for this provider to await once the container
/// itself is going away) whenever this provider's own `Ref` is disposed.
/// For a `keepAlive` provider that is exactly (and only) "the enclosing
/// `ProviderContainer` was disposed" — i.e. graceful process/test teardown,
/// never a mere account switch or a single account's removal (both of
/// those are handled per-account by [disposeAccountFirebase] /
/// [accountFirebase]'s own `ref.onDispose`, not by this one). There is no
/// equivalent hook on a hard process kill (the common case on
/// mobile — the OS simply reclaims memory, no Dart code runs), so this is
/// "best-effort on the paths that do run cleanup" (tests, hot-restart,
/// any future graceful-shutdown flow), not a substitute for the per-account
/// disposal paths.
///
/// [fa]: https://pub.dev/documentation/firebase_core/latest/firebase_core/FirebaseApp-class.html
///
/// **`maxAccounts` is [kMaxDeviceAccounts] + 1, not [kMaxDeviceAccounts].**
/// This originated as a Phase 1 Story D finding tied to the OLD
/// autoDispose-per-switch design: `AccountFirebase.resolve`'s bound check
/// and Riverpod's `autoDispose` family-member teardown used to be two
/// independently-scheduled things, so a back-to-back switch could spuriously
/// throw [MaxAccountsReachedException] even though the account being left
/// was truly being released (Riverpod's own scheduler, not the caller,
/// decided when that teardown actually ran). **That race no longer exists**
/// now that [accountFirebase] is itself `keepAlive`: switching the active
/// account never disposes anything (see [accountFirebase]'s doc), so there
/// is nothing left to race against on a mere switch. The only remaining
/// disposal path is the explicit one, [disposeAccountFirebase], which calls
/// `registry.dispose(accountId)` directly and synchronously (up to its own
/// first `await`) rather than going through Riverpod's scheduler — so a
/// concurrent caller resolving a brand-new account no longer needs to wait
/// out an opaque scheduling delay either. The one residual scenario the
/// headroom still covers: [disposeAccountFirebase] called for an account
/// whose FIRST resolve is still in flight (`_pending`, not yet `_handles`)
/// — `AccountFirebase.dispose` awaits that in-flight resolve before it can
/// remove the entry, so [activeAccountIds] briefly still counts it during
/// that await. This is a narrower window than the old switch-race (removing
/// an account that has never finished its first resolve is an edge case,
/// not the common "user switches accounts" path), so **the cushion is very
/// likely removable now** — kept as-is per this story's instructions rather
/// than unilaterally dropped; see `test/data/firestore/
/// account_switch_lifecycle_test.dart`'s "the ≤5 bound interacts correctly"
/// group for the updated characterization and the coordinator note on this.
/// The DB-enforced ≤5 **owned**-account cap ([kMaxDeviceAccounts] itself,
/// `DeviceRegistryDatabase.addAccount`) is untouched either way; this is
/// purely a concurrently-resolved-named-apps cushion in the in-memory
/// registry.

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
/// **Process-teardown hook.** `ref.onDispose` here runs [AccountFirebase
/// .disposeAll] (fire-and-forget — `onDispose` callbacks are synchronous;
/// there is nothing further for this provider to await once the container
/// itself is going away) whenever this provider's own `Ref` is disposed.
/// For a `keepAlive` provider that is exactly (and only) "the enclosing
/// `ProviderContainer` was disposed" — i.e. graceful process/test teardown,
/// never a mere account switch or a single account's removal (both of
/// those are handled per-account by [disposeAccountFirebase] /
/// [accountFirebase]'s own `ref.onDispose`, not by this one). There is no
/// equivalent hook on a hard process kill (the common case on
/// mobile — the OS simply reclaims memory, no Dart code runs), so this is
/// "best-effort on the paths that do run cleanup" (tests, hot-restart,
/// any future graceful-shutdown flow), not a substitute for the per-account
/// disposal paths.
///
/// [fa]: https://pub.dev/documentation/firebase_core/latest/firebase_core/FirebaseApp-class.html
///
/// **`maxAccounts` is [kMaxDeviceAccounts] + 1, not [kMaxDeviceAccounts].**
/// This originated as a Phase 1 Story D finding tied to the OLD
/// autoDispose-per-switch design: `AccountFirebase.resolve`'s bound check
/// and Riverpod's `autoDispose` family-member teardown used to be two
/// independently-scheduled things, so a back-to-back switch could spuriously
/// throw [MaxAccountsReachedException] even though the account being left
/// was truly being released (Riverpod's own scheduler, not the caller,
/// decided when that teardown actually ran). **That race no longer exists**
/// now that [accountFirebase] is itself `keepAlive`: switching the active
/// account never disposes anything (see [accountFirebase]'s doc), so there
/// is nothing left to race against on a mere switch. The only remaining
/// disposal path is the explicit one, [disposeAccountFirebase], which calls
/// `registry.dispose(accountId)` directly and synchronously (up to its own
/// first `await`) rather than going through Riverpod's scheduler — so a
/// concurrent caller resolving a brand-new account no longer needs to wait
/// out an opaque scheduling delay either. The one residual scenario the
/// headroom still covers: [disposeAccountFirebase] called for an account
/// whose FIRST resolve is still in flight (`_pending`, not yet `_handles`)
/// — `AccountFirebase.dispose` awaits that in-flight resolve before it can
/// remove the entry, so [activeAccountIds] briefly still counts it during
/// that await. This is a narrower window than the old switch-race (removing
/// an account that has never finished its first resolve is an edge case,
/// not the common "user switches accounts" path), so **the cushion is very
/// likely removable now** — kept as-is per this story's instructions rather
/// than unilaterally dropped; see `test/data/firestore/
/// account_switch_lifecycle_test.dart`'s "the ≤5 bound interacts correctly"
/// group for the updated characterization and the coordinator note on this.
/// The DB-enforced ≤5 **owned**-account cap ([kMaxDeviceAccounts] itself,
/// `DeviceRegistryDatabase.addAccount`) is untouched either way; this is
/// purely a concurrently-resolved-named-apps cushion in the in-memory
/// registry.

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
  /// **Process-teardown hook.** `ref.onDispose` here runs [AccountFirebase
  /// .disposeAll] (fire-and-forget — `onDispose` callbacks are synchronous;
  /// there is nothing further for this provider to await once the container
  /// itself is going away) whenever this provider's own `Ref` is disposed.
  /// For a `keepAlive` provider that is exactly (and only) "the enclosing
  /// `ProviderContainer` was disposed" — i.e. graceful process/test teardown,
  /// never a mere account switch or a single account's removal (both of
  /// those are handled per-account by [disposeAccountFirebase] /
  /// [accountFirebase]'s own `ref.onDispose`, not by this one). There is no
  /// equivalent hook on a hard process kill (the common case on
  /// mobile — the OS simply reclaims memory, no Dart code runs), so this is
  /// "best-effort on the paths that do run cleanup" (tests, hot-restart,
  /// any future graceful-shutdown flow), not a substitute for the per-account
  /// disposal paths.
  ///
  /// [fa]: https://pub.dev/documentation/firebase_core/latest/firebase_core/FirebaseApp-class.html
  ///
  /// **`maxAccounts` is [kMaxDeviceAccounts] + 1, not [kMaxDeviceAccounts].**
  /// This originated as a Phase 1 Story D finding tied to the OLD
  /// autoDispose-per-switch design: `AccountFirebase.resolve`'s bound check
  /// and Riverpod's `autoDispose` family-member teardown used to be two
  /// independently-scheduled things, so a back-to-back switch could spuriously
  /// throw [MaxAccountsReachedException] even though the account being left
  /// was truly being released (Riverpod's own scheduler, not the caller,
  /// decided when that teardown actually ran). **That race no longer exists**
  /// now that [accountFirebase] is itself `keepAlive`: switching the active
  /// account never disposes anything (see [accountFirebase]'s doc), so there
  /// is nothing left to race against on a mere switch. The only remaining
  /// disposal path is the explicit one, [disposeAccountFirebase], which calls
  /// `registry.dispose(accountId)` directly and synchronously (up to its own
  /// first `await`) rather than going through Riverpod's scheduler — so a
  /// concurrent caller resolving a brand-new account no longer needs to wait
  /// out an opaque scheduling delay either. The one residual scenario the
  /// headroom still covers: [disposeAccountFirebase] called for an account
  /// whose FIRST resolve is still in flight (`_pending`, not yet `_handles`)
  /// — `AccountFirebase.dispose` awaits that in-flight resolve before it can
  /// remove the entry, so [activeAccountIds] briefly still counts it during
  /// that await. This is a narrower window than the old switch-race (removing
  /// an account that has never finished its first resolve is an edge case,
  /// not the common "user switches accounts" path), so **the cushion is very
  /// likely removable now** — kept as-is per this story's instructions rather
  /// than unilaterally dropped; see `test/data/firestore/
  /// account_switch_lifecycle_test.dart`'s "the ≤5 bound interacts correctly"
  /// group for the updated characterization and the coordinator note on this.
  /// The DB-enforced ≤5 **owned**-account cap ([kMaxDeviceAccounts] itself,
  /// `DeviceRegistryDatabase.addAccount`) is untouched either way; this is
  /// purely a concurrently-resolved-named-apps cushion in the in-memory
  /// registry.
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
    r'c375eb92a33abde002428ad2c240a953fdb24c55';

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
/// **`keepAlive` — switching the active account must NOT dispose the
/// previous account's app.** This provider used to be a plain `@riverpod`
/// (`autoDispose`) family: once nothing watched
/// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
/// e.g. [activeAccountFirebaseProvider] moved on to a different id —
/// Riverpod scheduled this provider instance for disposal, tearing the
/// account's named app down via [AccountFirebase.dispose]. That is now
/// deliberately NOT what happens on a switch: **`cloud_firestore 6.4.1`
/// caches `FirebaseFirestore.instanceFor` in a process-lifetime `static` map
/// with no eviction hook** (`firestore.dart`'s `_cachedInstances`), so a
/// same-process dispose→re-resolve of the SAME account (exactly what A→B→A
/// switching used to do) hands `_resolveNew`'s `.settings =` call the SAME,
/// now-`terminate()`d, cached instance — which throws `FirebaseException`
/// per `terminate()`'s own contract. Rather than work around the SDK, this
/// provider removes the need to dispose-then-re-resolve at all: once an
/// account is resolved, it (and every OTHER already-resolved account) stays
/// resolved across any number of switches, for the lifetime of the process
/// or until [disposeAccountFirebase] is called explicitly for it (below).
/// The ≤5-account cap ([kMaxDeviceAccounts]) already bounds the worst case
/// at [kMaxDeviceAccounts] `+ 1` (headroom) live apps × 20 MiB
/// ([kAccountFirestoreCacheSizeBytes]) — see
/// [accountFirebaseRegistryProvider]'s doc for that budget.
///
/// **Disposal now happens ONLY via explicit removal or process teardown.**
/// [disposeAccountFirebase] (below) is the seam a genuine account-removal
/// flow calls — never a mere switch. [accountFirebaseRegistryProvider]'s own
/// `ref.onDispose` additionally tears every still-active account down if
/// the whole container is ever disposed (tests, hot-restart).
///
/// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
/// below — this ordering is load-bearing (defect #1 fix) and stays fully
/// reachable under `keepAlive`.** `Ref.onDispose` throws
/// `UnmountedRefException` if the provider is already disposed
/// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
/// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
/// real native `initializeApp` call — hundreds of milliseconds on-device —
/// so a caller that explicitly removes this account (via
/// [disposeAccountFirebase], which invalidates this provider) before that
/// settles disposes THIS provider instance mid-`await`; a `keepAlive`
/// provider is exactly as disposable via explicit `ref.invalidate`/
/// `container.invalidate` as an `autoDispose` one is via losing its last
/// listener — `keepAlive` only removes the LISTENER-COUNT-triggered
/// teardown path, not disposal itself. If `onDispose` were registered only
/// after the `await` (the pre-fix ordering), that registration call would
/// itself throw in exactly that window — and because the throw happens
/// AFTER `resolve` already completed and cached the handles in the
/// registry, nothing would ever call [AccountFirebase.dispose] for this
/// account: its named app + persistent cache would be pinned for the rest
/// of the process. Registering the teardown first means it exists no matter
/// when disposal happens; the closure only closes over `registry`/
/// `accountId` (never `ref`), so it stays safe to invoke even after `ref`
/// itself is unmounted, and the `_disposeCalledOnce` guard makes it safe to
/// invoke a second time from the `!ref.mounted` branch below without
/// double-disposing (itself also safe per [AccountFirebase.dispose]'s own
/// idempotency, but kept explicit here rather than relied upon implicitly).

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
/// **`keepAlive` — switching the active account must NOT dispose the
/// previous account's app.** This provider used to be a plain `@riverpod`
/// (`autoDispose`) family: once nothing watched
/// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
/// e.g. [activeAccountFirebaseProvider] moved on to a different id —
/// Riverpod scheduled this provider instance for disposal, tearing the
/// account's named app down via [AccountFirebase.dispose]. That is now
/// deliberately NOT what happens on a switch: **`cloud_firestore 6.4.1`
/// caches `FirebaseFirestore.instanceFor` in a process-lifetime `static` map
/// with no eviction hook** (`firestore.dart`'s `_cachedInstances`), so a
/// same-process dispose→re-resolve of the SAME account (exactly what A→B→A
/// switching used to do) hands `_resolveNew`'s `.settings =` call the SAME,
/// now-`terminate()`d, cached instance — which throws `FirebaseException`
/// per `terminate()`'s own contract. Rather than work around the SDK, this
/// provider removes the need to dispose-then-re-resolve at all: once an
/// account is resolved, it (and every OTHER already-resolved account) stays
/// resolved across any number of switches, for the lifetime of the process
/// or until [disposeAccountFirebase] is called explicitly for it (below).
/// The ≤5-account cap ([kMaxDeviceAccounts]) already bounds the worst case
/// at [kMaxDeviceAccounts] `+ 1` (headroom) live apps × 20 MiB
/// ([kAccountFirestoreCacheSizeBytes]) — see
/// [accountFirebaseRegistryProvider]'s doc for that budget.
///
/// **Disposal now happens ONLY via explicit removal or process teardown.**
/// [disposeAccountFirebase] (below) is the seam a genuine account-removal
/// flow calls — never a mere switch. [accountFirebaseRegistryProvider]'s own
/// `ref.onDispose` additionally tears every still-active account down if
/// the whole container is ever disposed (tests, hot-restart).
///
/// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
/// below — this ordering is load-bearing (defect #1 fix) and stays fully
/// reachable under `keepAlive`.** `Ref.onDispose` throws
/// `UnmountedRefException` if the provider is already disposed
/// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
/// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
/// real native `initializeApp` call — hundreds of milliseconds on-device —
/// so a caller that explicitly removes this account (via
/// [disposeAccountFirebase], which invalidates this provider) before that
/// settles disposes THIS provider instance mid-`await`; a `keepAlive`
/// provider is exactly as disposable via explicit `ref.invalidate`/
/// `container.invalidate` as an `autoDispose` one is via losing its last
/// listener — `keepAlive` only removes the LISTENER-COUNT-triggered
/// teardown path, not disposal itself. If `onDispose` were registered only
/// after the `await` (the pre-fix ordering), that registration call would
/// itself throw in exactly that window — and because the throw happens
/// AFTER `resolve` already completed and cached the handles in the
/// registry, nothing would ever call [AccountFirebase.dispose] for this
/// account: its named app + persistent cache would be pinned for the rest
/// of the process. Registering the teardown first means it exists no matter
/// when disposal happens; the closure only closes over `registry`/
/// `accountId` (never `ref`), so it stays safe to invoke even after `ref`
/// itself is unmounted, and the `_disposeCalledOnce` guard makes it safe to
/// invoke a second time from the `!ref.mounted` branch below without
/// double-disposing (itself also safe per [AccountFirebase.dispose]'s own
/// idempotency, but kept explicit here rather than relied upon implicitly).

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
  /// **`keepAlive` — switching the active account must NOT dispose the
  /// previous account's app.** This provider used to be a plain `@riverpod`
  /// (`autoDispose`) family: once nothing watched
  /// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
  /// e.g. [activeAccountFirebaseProvider] moved on to a different id —
  /// Riverpod scheduled this provider instance for disposal, tearing the
  /// account's named app down via [AccountFirebase.dispose]. That is now
  /// deliberately NOT what happens on a switch: **`cloud_firestore 6.4.1`
  /// caches `FirebaseFirestore.instanceFor` in a process-lifetime `static` map
  /// with no eviction hook** (`firestore.dart`'s `_cachedInstances`), so a
  /// same-process dispose→re-resolve of the SAME account (exactly what A→B→A
  /// switching used to do) hands `_resolveNew`'s `.settings =` call the SAME,
  /// now-`terminate()`d, cached instance — which throws `FirebaseException`
  /// per `terminate()`'s own contract. Rather than work around the SDK, this
  /// provider removes the need to dispose-then-re-resolve at all: once an
  /// account is resolved, it (and every OTHER already-resolved account) stays
  /// resolved across any number of switches, for the lifetime of the process
  /// or until [disposeAccountFirebase] is called explicitly for it (below).
  /// The ≤5-account cap ([kMaxDeviceAccounts]) already bounds the worst case
  /// at [kMaxDeviceAccounts] `+ 1` (headroom) live apps × 20 MiB
  /// ([kAccountFirestoreCacheSizeBytes]) — see
  /// [accountFirebaseRegistryProvider]'s doc for that budget.
  ///
  /// **Disposal now happens ONLY via explicit removal or process teardown.**
  /// [disposeAccountFirebase] (below) is the seam a genuine account-removal
  /// flow calls — never a mere switch. [accountFirebaseRegistryProvider]'s own
  /// `ref.onDispose` additionally tears every still-active account down if
  /// the whole container is ever disposed (tests, hot-restart).
  ///
  /// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
  /// below — this ordering is load-bearing (defect #1 fix) and stays fully
  /// reachable under `keepAlive`.** `Ref.onDispose` throws
  /// `UnmountedRefException` if the provider is already disposed
  /// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
  /// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
  /// real native `initializeApp` call — hundreds of milliseconds on-device —
  /// so a caller that explicitly removes this account (via
  /// [disposeAccountFirebase], which invalidates this provider) before that
  /// settles disposes THIS provider instance mid-`await`; a `keepAlive`
  /// provider is exactly as disposable via explicit `ref.invalidate`/
  /// `container.invalidate` as an `autoDispose` one is via losing its last
  /// listener — `keepAlive` only removes the LISTENER-COUNT-triggered
  /// teardown path, not disposal itself. If `onDispose` were registered only
  /// after the `await` (the pre-fix ordering), that registration call would
  /// itself throw in exactly that window — and because the throw happens
  /// AFTER `resolve` already completed and cached the handles in the
  /// registry, nothing would ever call [AccountFirebase.dispose] for this
  /// account: its named app + persistent cache would be pinned for the rest
  /// of the process. Registering the teardown first means it exists no matter
  /// when disposal happens; the closure only closes over `registry`/
  /// `accountId` (never `ref`), so it stays safe to invoke even after `ref`
  /// itself is unmounted, and the `_disposeCalledOnce` guard makes it safe to
  /// invoke a second time from the `!ref.mounted` branch below without
  /// double-disposing (itself also safe per [AccountFirebase.dispose]'s own
  /// idempotency, but kept explicit here rather than relied upon implicitly).
  AccountFirebaseProvider._({
    required AccountFirebaseFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'accountFirebaseProvider',
         isAutoDispose: false,
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

String _$accountFirebaseHash() => r'96dc0f59beb65bf94cd91f14838f40309e96423f';

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
/// **`keepAlive` — switching the active account must NOT dispose the
/// previous account's app.** This provider used to be a plain `@riverpod`
/// (`autoDispose`) family: once nothing watched
/// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
/// e.g. [activeAccountFirebaseProvider] moved on to a different id —
/// Riverpod scheduled this provider instance for disposal, tearing the
/// account's named app down via [AccountFirebase.dispose]. That is now
/// deliberately NOT what happens on a switch: **`cloud_firestore 6.4.1`
/// caches `FirebaseFirestore.instanceFor` in a process-lifetime `static` map
/// with no eviction hook** (`firestore.dart`'s `_cachedInstances`), so a
/// same-process dispose→re-resolve of the SAME account (exactly what A→B→A
/// switching used to do) hands `_resolveNew`'s `.settings =` call the SAME,
/// now-`terminate()`d, cached instance — which throws `FirebaseException`
/// per `terminate()`'s own contract. Rather than work around the SDK, this
/// provider removes the need to dispose-then-re-resolve at all: once an
/// account is resolved, it (and every OTHER already-resolved account) stays
/// resolved across any number of switches, for the lifetime of the process
/// or until [disposeAccountFirebase] is called explicitly for it (below).
/// The ≤5-account cap ([kMaxDeviceAccounts]) already bounds the worst case
/// at [kMaxDeviceAccounts] `+ 1` (headroom) live apps × 20 MiB
/// ([kAccountFirestoreCacheSizeBytes]) — see
/// [accountFirebaseRegistryProvider]'s doc for that budget.
///
/// **Disposal now happens ONLY via explicit removal or process teardown.**
/// [disposeAccountFirebase] (below) is the seam a genuine account-removal
/// flow calls — never a mere switch. [accountFirebaseRegistryProvider]'s own
/// `ref.onDispose` additionally tears every still-active account down if
/// the whole container is ever disposed (tests, hot-restart).
///
/// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
/// below — this ordering is load-bearing (defect #1 fix) and stays fully
/// reachable under `keepAlive`.** `Ref.onDispose` throws
/// `UnmountedRefException` if the provider is already disposed
/// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
/// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
/// real native `initializeApp` call — hundreds of milliseconds on-device —
/// so a caller that explicitly removes this account (via
/// [disposeAccountFirebase], which invalidates this provider) before that
/// settles disposes THIS provider instance mid-`await`; a `keepAlive`
/// provider is exactly as disposable via explicit `ref.invalidate`/
/// `container.invalidate` as an `autoDispose` one is via losing its last
/// listener — `keepAlive` only removes the LISTENER-COUNT-triggered
/// teardown path, not disposal itself. If `onDispose` were registered only
/// after the `await` (the pre-fix ordering), that registration call would
/// itself throw in exactly that window — and because the throw happens
/// AFTER `resolve` already completed and cached the handles in the
/// registry, nothing would ever call [AccountFirebase.dispose] for this
/// account: its named app + persistent cache would be pinned for the rest
/// of the process. Registering the teardown first means it exists no matter
/// when disposal happens; the closure only closes over `registry`/
/// `accountId` (never `ref`), so it stays safe to invoke even after `ref`
/// itself is unmounted, and the `_disposeCalledOnce` guard makes it safe to
/// invoke a second time from the `!ref.mounted` branch below without
/// double-disposing (itself also safe per [AccountFirebase.dispose]'s own
/// idempotency, but kept explicit here rather than relied upon implicitly).

final class AccountFirebaseFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<AccountFirebaseHandles>, String> {
  AccountFirebaseFamily._()
    : super(
        retry: null,
        name: r'accountFirebaseProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
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
  /// **`keepAlive` — switching the active account must NOT dispose the
  /// previous account's app.** This provider used to be a plain `@riverpod`
  /// (`autoDispose`) family: once nothing watched
  /// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
  /// e.g. [activeAccountFirebaseProvider] moved on to a different id —
  /// Riverpod scheduled this provider instance for disposal, tearing the
  /// account's named app down via [AccountFirebase.dispose]. That is now
  /// deliberately NOT what happens on a switch: **`cloud_firestore 6.4.1`
  /// caches `FirebaseFirestore.instanceFor` in a process-lifetime `static` map
  /// with no eviction hook** (`firestore.dart`'s `_cachedInstances`), so a
  /// same-process dispose→re-resolve of the SAME account (exactly what A→B→A
  /// switching used to do) hands `_resolveNew`'s `.settings =` call the SAME,
  /// now-`terminate()`d, cached instance — which throws `FirebaseException`
  /// per `terminate()`'s own contract. Rather than work around the SDK, this
  /// provider removes the need to dispose-then-re-resolve at all: once an
  /// account is resolved, it (and every OTHER already-resolved account) stays
  /// resolved across any number of switches, for the lifetime of the process
  /// or until [disposeAccountFirebase] is called explicitly for it (below).
  /// The ≤5-account cap ([kMaxDeviceAccounts]) already bounds the worst case
  /// at [kMaxDeviceAccounts] `+ 1` (headroom) live apps × 20 MiB
  /// ([kAccountFirestoreCacheSizeBytes]) — see
  /// [accountFirebaseRegistryProvider]'s doc for that budget.
  ///
  /// **Disposal now happens ONLY via explicit removal or process teardown.**
  /// [disposeAccountFirebase] (below) is the seam a genuine account-removal
  /// flow calls — never a mere switch. [accountFirebaseRegistryProvider]'s own
  /// `ref.onDispose` additionally tears every still-active account down if
  /// the whole container is ever disposed (tests, hot-restart).
  ///
  /// **`ref.onDispose` is registered BEFORE the `await registry.resolve(...)`
  /// below — this ordering is load-bearing (defect #1 fix) and stays fully
  /// reachable under `keepAlive`.** `Ref.onDispose` throws
  /// `UnmountedRefException` if the provider is already disposed
  /// (`!ref.mounted`) by the time it is called (riverpod's own `Ref.onDispose`
  /// doc: "check `ref.mounted` after async gaps"). `registry.resolve` awaits a
  /// real native `initializeApp` call — hundreds of milliseconds on-device —
  /// so a caller that explicitly removes this account (via
  /// [disposeAccountFirebase], which invalidates this provider) before that
  /// settles disposes THIS provider instance mid-`await`; a `keepAlive`
  /// provider is exactly as disposable via explicit `ref.invalidate`/
  /// `container.invalidate` as an `autoDispose` one is via losing its last
  /// listener — `keepAlive` only removes the LISTENER-COUNT-triggered
  /// teardown path, not disposal itself. If `onDispose` were registered only
  /// after the `await` (the pre-fix ordering), that registration call would
  /// itself throw in exactly that window — and because the throw happens
  /// AFTER `resolve` already completed and cached the handles in the
  /// registry, nothing would ever call [AccountFirebase.dispose] for this
  /// account: its named app + persistent cache would be pinned for the rest
  /// of the process. Registering the teardown first means it exists no matter
  /// when disposal happens; the closure only closes over `registry`/
  /// `accountId` (never `ref`), so it stays safe to invoke even after `ref`
  /// itself is unmounted, and the `_disposeCalledOnce` guard makes it safe to
  /// invoke a second time from the `!ref.mounted` branch below without
  /// double-disposing (itself also safe per [AccountFirebase.dispose]'s own
  /// idempotency, but kept explicit here rather than relied upon implicitly).

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
