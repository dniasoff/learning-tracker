/// The minimal "which device account is active right now" seam that
/// repositories (Epic B) resolve their Firestore handle through.
///
/// `account_firebase_providers.dart`'s doc comment explains why the
/// previous `activeAccountIdProvider`/`activeAccountFirebaseProvider` layer
/// was deleted: it assumed [AccountFirebase.resolve] silently created an
/// account on first call, which it no longer does. This file is the
/// replacement, built the same minimal way — a settable notifier plus a
/// resolution provider, nothing more.
///
/// **Not yet wired.** Nothing in production calls [ActiveAccountId.set] yet.
/// The real call sites — bootstrap (restore the last-active account on
/// cold start), sign-in/sign-up (activate the freshly-authenticated
/// account), and account-switch (deactivate the old one, activate the
/// new) — belong to Epic C, which does not exist yet. Until then,
/// [activeAccountIdProvider] stays at its default (`null`) for the whole
/// app session, and [activeAccountFirebaseProvider] resolves to `null`
/// alongside it. Neither of those is a bug — it means "nobody has called
/// `.set(...)` yet", which today is unconditionally true. Do not read this
/// file's existence as proof anything is actually wired up.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart';

/// Holds the device-registry account id of the "active" account, or `null`
/// when no account is active.
///
/// Deliberately dumb: this notifier only records *which* account id is
/// active. It never creates, authenticates, signs out, or disposes
/// anything itself — that is [AccountFirebase]'s job (via
/// [accountFirebaseRegistryProvider]). The caller that decides an account
/// should become active is responsible for having already established its
/// session with [AccountFirebase.createAnonymousAccount] /
/// [AccountFirebase.signInCloudAccount] first; [set]ting an id here for an
/// account with no authenticated session just means
/// [activeAccountFirebaseProvider] will surface
/// [AccountNotAuthenticatedException] the next time it resolves.
class ActiveAccountId extends Notifier<String?> {
  @override
  String? build() => null;

  /// Sets the active account id, or clears it with `null` (e.g. on
  /// sign-out / account removal).
  void set(String? accountId) => state = accountId;
}

/// The active account id — `null` until some caller calls
/// `ref.read(activeAccountIdProvider.notifier).set(accountId)`. See the
/// library doc comment: nothing does that yet.
final activeAccountIdProvider = NotifierProvider<ActiveAccountId, String?>(
  ActiveAccountId.new,
);

/// Resolves [activeAccountIdProvider] to its authenticated
/// [AccountFirebaseHandles], or `null` when no account is active.
///
/// Re-attaches via [AccountFirebase.resolve] — this provider never creates
/// or signs in an account itself, so it throws
/// [AccountNotAuthenticatedException] (surfaced as this [FutureProvider]'s
/// `AsyncError`) if [activeAccountIdProvider] names an account id that has
/// no authenticated session to re-attach to. In practice that should never
/// happen once Epic C's call sites only ever `set()` an id right after
/// establishing that account's session — until Epic C exists, this
/// provider simply has nothing to resolve ([activeAccountIdProvider] stays
/// `null`).
final activeAccountFirebaseProvider = FutureProvider<AccountFirebaseHandles?>((
  ref,
) async {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  final registry = ref.watch(accountFirebaseRegistryProvider);
  return registry.resolve(accountId);
});
