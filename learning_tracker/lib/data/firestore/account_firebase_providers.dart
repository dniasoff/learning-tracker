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
@Riverpod(keepAlive: true)
AccountFirebase accountFirebaseRegistry(Ref ref) {
  return AccountFirebase(
    options: DefaultFirebaseOptions.currentPlatform,
    maxAccounts: kMaxDeviceAccounts + 1,
  );
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
/// **Disposal on account switch.** `@riverpod` with a parameter generates
/// an `autoDispose` family. Once nothing watches
/// `accountFirebaseProvider(accountId)` for a given [accountId] anymore —
/// e.g. [activeAccountFirebaseProvider] switches to watching a different
/// id — Riverpod schedules this provider instance for disposal, which
/// tears down that (and only that) account's named app via
/// [AccountFirebase.dispose]. The registry singleton itself, and every
/// OTHER account's handles it holds, are untouched.
@riverpod
Future<AccountFirebaseHandles> accountFirebase(
  Ref ref,
  String accountId,
) async {
  if (!ref.watch(accountFirebaseRegistryEnabledProvider)) {
    return _legacyHandles(ref);
  }

  final registry = ref.watch(accountFirebaseRegistryProvider);
  final handles = await registry.resolve(accountId);
  ref.onDispose(() {
    unawaited(registry.dispose(accountId));
  });
  return handles;
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
