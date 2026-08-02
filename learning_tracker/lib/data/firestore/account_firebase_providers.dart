/// Riverpod resolution layer for the `AccountFirebase` registry
/// (`account_firebase.dart`, Phase 1 Story A) — Phase 1 Story C.
///
/// This is the seam every future caller (Phase 2+ repositories) resolves a
/// Firestore/Auth handle through, per AD-2: "no service, repository, or
/// feature may touch a bare `FirebaseFirestore.instance`/
/// `FirebaseAuth.instance`. All access resolves through the active
/// account's handle: `accountFirebase(activeAccountId).firestore`."
/// [accountFirebaseProvider] is that call.
///
/// ## Why `lib/data/firestore/`, not `lib/core/sync/providers/`
///
/// `account_firebase.dart` (the registry this file wraps) already lives
/// here per the Structural Seed target tree (ARCHITECTURE-SPINE.md), and
/// Story 2.6's Firebase-confinement gate (`tool/
/// check_firebase_confinement.dart`) allow-lists `lib/data/firestore/`
/// alongside the legacy `lib/core/sync/`+`lib/core/auth/` — so importing
/// [firebaseFirestoreProvider]/[firebaseAuthInstanceProvider] (both
/// Firebase-typed) from those two directories into this file is within the
/// same confined ring, not a new leak. `core/sync/providers/` itself stays
/// reserved for the sync ENGINE (listeners, merge, outbox) — a handle-
/// resolution seam is not that, and Story P1-D (listener/lifecycle) is
/// landing files in that directory in parallel with this story.
///
/// ## Feature flag (migration-plan Phase 1 "Rollback")
///
/// [accountFirebaseRegistryEnabledProvider] governs whether
/// [accountFirebaseProvider] resolves via the real per-account
/// `AccountFirebase` registry (ON, the default) or degrades to
/// [_legacyHandles] — a shim wrapping the pre-Phase-1 default-app
/// singletons ([firebaseFirestoreProvider], [firebaseAuthInstanceProvider])
/// that never calls `Firebase.initializeApp(name:)` at all (OFF). Per the
/// plan: "Feature-flag the subsystem; fall back to the single-instance path
/// (still present until Phase 6). No data written through it yet, so
/// rollback is flag-flip." No repository reads through either path yet —
/// Phase 1 "Ships to users: Nothing yet" — this story wires the resolution
/// layer itself, not its (Phase 2/3) callers.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart'
    show firebaseAuthInstanceProvider;
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show kMaxDeviceAccounts;
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart'
    show firebaseFirestoreProvider;
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/firebase_options.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_firebase_providers.g.dart';

/// Feature flag: Phase 1 per-account registry path (`true`, default) vs.
/// the legacy single-default-app path (`false`) — see the library doc.
///
/// A plain (non-code-gen) `Provider<bool>`, matching the rest of `core/
/// sync/providers`' boolean-gate style — a test or a rollback override is a
/// one-line `accountFirebaseRegistryEnabledProvider.overrideWithValue(false)`.
final accountFirebaseRegistryEnabledProvider = Provider<bool>((ref) => true);

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
@Riverpod(keepAlive: true)
AccountFirebase accountFirebaseRegistry(Ref ref) {
  final registry = AccountFirebase(
    options: DefaultFirebaseOptions.currentPlatform,
    maxAccounts: kMaxDeviceAccounts + 1,
  );
  ref.onDispose(() => unawaited(registry.disposeAll()));
  return registry;
}

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
@Riverpod(keepAlive: true)
Future<AccountFirebaseHandles> accountFirebase(
  Ref ref,
  String accountId,
) async {
  if (!ref.watch(accountFirebaseRegistryEnabledProvider)) {
    return _legacyHandles(ref);
  }

  final registry = ref.watch(accountFirebaseRegistryProvider);

  var disposeCalledOnce = false;
  void disposeOnce() {
    if (disposeCalledOnce) return;
    disposeCalledOnce = true;
    unawaited(registry.dispose(accountId));
  }

  // MUST be registered before the `await` below — see the doc comment.
  ref.onDispose(disposeOnce);

  final handles = await registry.resolve(accountId);

  if (!ref.mounted) {
    // This provider instance was disposed while `resolve` was still in
    // flight. `disposeOnce` above already ran (from `ref.onDispose`) and
    // is tearing the account down (it awaits the same in-flight resolve
    // internally — see `AccountFirebase.dispose`'s doc — so it cannot
    // delete an app out from under this call); calling it again here is a
    // no-op guard, not a second real teardown. Never hand back a "live"
    // bundle nobody will use once this provider is gone.
    disposeOnce();
    throw StateError(
      'accountFirebase($accountId): provider was disposed while resolve() '
      'was still in flight; the resolved handles were torn down instead '
      'of being returned.',
    );
  }

  return handles;
}

/// Explicit account-**removal** disposal hook — the only supported way to
/// tear an account's [AccountFirebase] handles down before process exit,
/// now that [accountFirebase] is `keepAlive` (a mere account switch never
/// disposes; see that provider's doc).
///
/// Call this when [accountId] is genuinely removed from the device — e.g.
/// from the same call site that calls `DeviceRegistryDatabase.removeAccount
/// (accountId)` (`lib/core/database/registry/device_registry_database.dart`)
/// via `AccountLifecycleService.removeCloudFromDevice` /
/// `.deleteLocalAccount` / `.deleteCloudAccount`
/// (`lib/features/account/domain/services/account_lifecycle_service.dart`)
/// — never on a plain account-switch. **Not yet wired into those call
/// sites by this story**: `AccountLifecycleService` is a plain, non-Riverpod
/// class constructed ad hoc in presentation code (`account_picker_screen
/// .dart`, `account_actions.dart`) with no `Ref`/`ProviderContainer` access
/// today, and this story's scope is the resolution layer
/// (`account_firebase_providers.dart`) — threading a
/// `Future<void> Function(String)?` removal callback through
/// `AccountLifecycleService`'s three methods (invoked right after each
/// one's own `_registry.removeAccount(accountId)` call) and passing
/// `(id) => disposeAccountFirebase(ref, id)` from its three construction
/// sites is the natural follow-up, tracked separately rather than guessed
/// at here unreviewed.
///
/// **Two steps, in order:**
/// 1. `ref.invalidate(accountFirebaseProvider(accountId))` — disposes the
///    Riverpod-cached family member (if one exists), running the same
///    `ref.onDispose` → `disposeOnce` → `registry.dispose(accountId)` path
///    documented on [accountFirebase] (every review-fix guard on that path —
///    `!ref.mounted`, `disposeOnce`'s idempotency — applies exactly as
///    documented there). This also ensures a later `accountFirebase
///    (accountId)` re-read (should the same id ever be reused, which
///    today's UUID-v4 account ids never do — see `account_firebase.dart`'s
///    `_resolveNew` doc for why a same-process revisit is an explicit,
///    documented Phase 1 gap) triggers a fresh resolve rather than handing
///    back a stale `isDisposed` bundle from the invalidated cache entry.
/// 2. `await registry.dispose(accountId)` — called directly (not merely
///    relied upon via step 1's fire-and-forget `unawaited(...)` inside
///    `disposeOnce`) so THIS function's caller gets a `Future` that only
///    completes once `terminate()` + `app.delete()` have actually finished
///    (defect #3's ordering, unchanged). `AccountFirebase.dispose` is
///    documented idempotent/safe to call concurrently with itself for the
///    same [accountId] (the second caller's `_handles.remove` is a no-op),
///    so this is safe regardless of whether step 1 already triggered an
///    equivalent call.
Future<void> disposeAccountFirebase(Ref ref, String accountId) async {
  ref.invalidate(accountFirebaseProvider(accountId));
  await ref.read(accountFirebaseRegistryProvider).dispose(accountId);
}

/// Convenience provider: [accountFirebaseProvider] for whichever account
/// [activeAccountIdProvider] currently names, or `null` if no account is
/// active yet (fresh install / signed out). Phase 2/3 repository code
/// watches this instead of threading an explicit account id through every
/// call site.
@Riverpod(keepAlive: true)
Future<AccountFirebaseHandles?> activeAccountFirebase(Ref ref) async {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountFirebaseProvider(accountId).future);
}

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
@Riverpod(keepAlive: true)
class ActiveAccountId extends _$ActiveAccountId {
  @override
  String? build() => null;

  /// Sets the active account id (mirrors [AccountDbFileName.setFileName]).
  void setAccountId(String? accountId) => state = accountId;
}

/// The flag-off / rollback shim: wraps the pre-Phase-1 default-app
/// singletons in an [AccountFirebaseHandles] bundle so a flag-off caller of
/// [accountFirebaseProvider] gets a functionally equivalent object without
/// ever touching [AccountFirebase] / `Firebase.initializeApp(name:)`.
///
/// Reuses [firebaseFirestoreProvider] and [firebaseAuthInstanceProvider] —
/// the SAME two call sites the AD-2/AD-28 bare-instance ratchet (`tool/
/// check_bare_firebase_instance_ratchet.dart`) still tracks as legitimate
/// pre-Phase-1 sites — rather than typing a third, independent
/// `FirebaseFirestore.instance`/`FirebaseAuth.instance` literal here. Uses
/// `ref.read`, not `ref.watch`: this shim is evaluated once per
/// [accountFirebase] call and the legacy singletons never change identity
/// during a session, so there is nothing to react to — watching would only
/// add a spurious rebuild trigger if either provider's identity ever did
/// change (e.g. under a test override swapped mid-test).
///
/// `appCheck` is left `null` — the default app's App Check activation
/// (`app/bootstrap/firebase_bootstrap.dart`) is a separate, already-running
/// concern this shim does not duplicate.
AccountFirebaseHandles _legacyHandles(Ref ref) {
  final firestore = ref.read(firebaseFirestoreProvider);
  final auth = ref.read(firebaseAuthInstanceProvider);
  return AccountFirebaseHandles(
    app: firestore.app,
    firestore: firestore,
    auth: auth,
  );
}
