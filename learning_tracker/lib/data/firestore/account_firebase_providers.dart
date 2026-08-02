/// Riverpod resolution layer for the [AccountFirebase] registry
/// (`account_firebase.dart`) — the seam later phases (Epic B: the
/// repository layer) read to reach an account's authenticated Firestore/
/// Auth handles: `ref.read(accountFirebaseRegistryProvider)
/// .resolve(accountId)` (or `.createAnonymousAccount`/`.signInCloudAccount`
/// for the two account-creation flows, `.linkCredential` for Upgrade-to-
/// Cloud, `.signOut`/`.dispose` for teardown).
///
/// ## Deliberately minimal
///
/// This file used to also carry a feature flag
/// (`accountFirebaseRegistryEnabledProvider`) with a legacy default-app
/// fallback shim, and a keepAlive-across-switch "active account"
/// convenience layer (`activeAccountIdProvider`/
/// `activeAccountFirebaseProvider`/`disposeAccountFirebase`). Both are
/// gone, deliberately:
///
/// - **The feature flag** existed so this subsystem could be rolled back
///   while it had no real callers ("rollback is flag-flip; no data written
///   through it yet"). There is no fallback left to roll back TO —
///   `AccountFirebase` is the only data path now — so the flag and its
///   `_legacyHandles` shim over the pre-registry default-app singletons
///   were dead weight kept alive for a rollback that will never happen.
/// - **The "active account" layer** assumed [AccountFirebase.resolve] was
///   the only entry point and that it silently created the account on
///   first call. Neither holds any more: creation is now a distinct,
///   explicit, network-requiring action
///   ([AccountFirebase.createAnonymousAccount]/
///   [AccountFirebase.signInCloudAccount]), and [AccountFirebase.resolve]
///   deliberately throws rather than create anything (see its doc). A
///   single `AsyncValue`-wrapping family provider can no longer paper over
///   "which of these actions should this account id trigger" — that choice
///   belongs to whichever concrete sign-in/signup/switch flow calls this
///   registry (Epic C), which does not exist yet. Building that Riverpod
///   shape now, before its callers exist, would be guessing.
///
/// Neither deletion removes capability: every caller of the old layer was
/// itself unwired (nothing in `lib/` outside this module and its own tests
/// referenced it), so nothing downstream loses anything by their removal.
///
/// **Update (Epic B):** a new, deliberately-minimal "active account"
/// replacement now exists in `active_account_providers.dart` —
/// [ActiveAccountId]/`activeAccountIdProvider`/
/// `activeAccountFirebaseProvider`. It does not assume [resolve] creates
/// anything (the defect above), and nothing writes to it in production yet
/// — see that file's doc comment before assuming it is wired into any real
/// flow.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show kMaxDeviceAccounts;
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/firebase_options.dart';

/// The single [AccountFirebase] registry instance for this app session —
/// "exactly one place constructs and caches per-account Firebase handles".
///
/// A plain (non-`autoDispose`) [Provider] is already Riverpod's "keep
/// alive" shape: this must never be rebuilt on a widget rebuild, or every
/// named app it has already created would be orphaned (a fresh
/// `AccountFirebase()` starts with an empty in-memory session cache, even
/// though the native `FirebaseApp`s the old instance created are still
/// alive and now unreachable through it).
///
/// `ref.onDispose` runs [AccountFirebase.disposeAll] (fire-and-forget —
/// `onDispose` callbacks are synchronous) when the enclosing
/// `ProviderContainer` itself is disposed: graceful process/test teardown,
/// never a mere account switch or a single account's removal (both of
/// those are the caller's job via [AccountFirebase.signOut]/
/// [AccountFirebase.dispose] directly, once Epic C wires a real switch/
/// removal flow). There is no equivalent hook for a hard process kill (the
/// common case on mobile — the OS simply reclaims memory, no Dart code
/// runs), so this is best-effort on the paths that do run cleanup, not a
/// substitute for per-account disposal.
///
/// **`maxAccounts` is [kMaxDeviceAccounts] exactly — no extra headroom.**
/// The previous `+ 1` cushion existed for a race tied to the now-deleted
/// keepAlive-across-switch layer: an outgoing account briefly still counted
/// against the bound while a new one resolved, because Riverpod's own
/// disposal scheduling — not the caller — decided when the old account's
/// teardown actually ran. That layer is gone: nothing in this file
/// resolves more than one account implicitly, so there is no
/// scheduler-driven double-count left to absorb. [AccountFirebase] itself
/// still has one narrower residual case ([AccountFirebase.dispose] called
/// for an account whose first [AccountFirebase.resolve]/
/// [AccountFirebase.createAnonymousAccount] is still in flight — see that
/// class's doc), which this bound does not special-case; if that ever
/// proves to matter in practice against a real caller, the fix is a
/// one-line bump here, not a structural change. The DB-enforced ≤5
/// **owned**-account cap ([kMaxDeviceAccounts] itself,
/// `DeviceRegistryDatabase.addAccount`) is untouched either way.
final accountFirebaseRegistryProvider = Provider<AccountFirebase>((ref) {
  final registry = AccountFirebase(
    options: DefaultFirebaseOptions.currentPlatform,
    maxAccounts: kMaxDeviceAccounts,
  );
  ref.onDispose(() => unawaited(registry.disposeAll()));
  return registry;
});
