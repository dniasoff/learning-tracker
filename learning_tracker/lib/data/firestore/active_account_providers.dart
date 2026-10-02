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
/// **Wired into production.** [ActiveAccountId.set] is called from
/// `lib/app/bootstrap/bootstrap.dart` (restore the last-active account on
/// cold start), and from the sign-in/sign-up/account-switch flows —
/// `signup_screen.dart`, `account_picker_screen.dart`,
/// `sign_in_controller.dart`, and `account_actions.dart`.
/// [activeAccountIdProvider] therefore holds a real account id for the
/// whole app session once one of those has run, and
/// [activeAccountFirebaseProvider] resolves its handles alongside it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/path_uid_resolver_provider.dart';
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
  void set(String? accountId) {
    final isSameAccount = state == accountId;
    state = accountId;
    if (isSameAccount && accountId != null) {
      // A prior cold-start resolve may have failed before authentication was
      // established. Re-setting the same id after sign-in must clear that
      // cached AsyncError so dependants retry against the now-authenticated
      // AccountFirebase session. Bump a separate provider rather than
      // invalidating this notifier's dependent directly: invalidating
      // activeAccountFirebaseProvider from here creates a Riverpod cycle.
      ref.read(_activeAccountResolutionGenerationProvider.notifier).bump();
    }
  }
}

/// The active account id — `null` until some caller calls
/// `ref.read(activeAccountIdProvider.notifier).set(accountId)`. See the
/// library doc comment for the production call sites that now do.
final activeAccountIdProvider = NotifierProvider<ActiveAccountId, String?>(
  ActiveAccountId.new,
);

/// Generation used to refresh the active-account resolution after a caller
/// re-establishes the same account session. This provider is deliberately
/// independent of [activeAccountIdProvider], so changing it cannot create a
/// dependency cycle while [ActiveAccountId.set] is running.
class _ActiveAccountResolutionGeneration extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _activeAccountResolutionGenerationProvider =
    NotifierProvider<_ActiveAccountResolutionGeneration, int>(
      _ActiveAccountResolutionGeneration.new,
    );

/// Resolves [activeAccountIdProvider] to its authenticated
/// [AccountFirebaseHandles], or `null` when no account is active.
///
/// Re-attaches via [AccountFirebase.resolve] — this provider never creates
/// or signs in an account itself, so it throws
/// [AccountNotAuthenticatedException] (surfaced as this [FutureProvider]'s
/// `AsyncError`) if [activeAccountIdProvider] names an account id that has
/// no authenticated session to re-attach to. In practice that should not
/// happen: every production `.set()` call site (see the library doc
/// comment) only ever activates an id right after establishing that
/// account's session.
///
/// **`retry: (retryCount, error) => null` — auto-retry deliberately
/// disabled (T-43).** Riverpod's per-provider default (`retry` unset here
/// falls back to `ProviderContainer.defaultRetry`) treats every plain
/// `Exception` a `FutureProvider`'s build throws — sync or async — as
/// transient: 10 attempts, 200ms doubling to a 6.4s cap, and `.future`
/// (what every caller of this provider actually awaits) does not settle
/// until all retries exhaust, because Riverpod exposes the interim state as
/// `AsyncLoading(..., retrying: true)`, not a terminal `AsyncError` — only
/// the terminal state completes `.future`'s `Completer`
/// (`package:riverpod`'s `element.dart`, `onLoading` vs `onError`).
/// [AccountNotAuthenticatedException] is a structural mismatch — this
/// [accountId] was never authenticated — not a transient failure; retrying
/// with the identical id can never succeed on its own, only a fresh
/// sign-in/sign-up call (which activates a DIFFERENT id) fixes it.
/// Reproduced directly: without this override, a resolution failure here
/// left `FirestoreProfileRepositoryAdapter`'s shared Firestore-repo
/// resolution point (`_resolveFirestoreProfileRepo` as of P2-23; the same
/// `await` lived directly inside `_ensureFirestoreProfile` at the time of
/// this reproduction — reached from `createProfile`/`ensureDefaultProfile`,
/// both documented offline-first and non-blocking) hung awaiting `.future`,
/// timing out `profile_repository_impl_test.dart`'s "does not propagate
/// out of createProfile" test at 2 minutes instead of completing — see
/// `docs/planning/firestore-cutover-log.md`'s `T-43` entries for the full
/// trace.
///
/// **Path uid (AD-24, DNI-520).** The bundle handed out is
/// [AccountFirebaseHandles.withPathUid]: its `uid` — the `{uid}` every
/// repository puts in `users/{uid}/…` — is the account's PERSISTED path uid
/// from [PathUidResolver.pathUidFor], never the live named-app user's uid
/// (that one stays available as `authUid`, for identity checks). Session
/// flows reconcile the persisted uid before activating an account; an
/// account row that still has none (a legacy row activated before that
/// existed) gets its one-time initial bind here. A persisted uid that
/// differs from the live one is kept (never silently replaced from live
/// auth) and logged.
final activeAccountFirebaseProvider = FutureProvider<AccountFirebaseHandles?>((
  ref,
) async {
  ref.watch(_activeAccountResolutionGenerationProvider);
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  final registry = ref.watch(accountFirebaseRegistryProvider);
  final pathUids = ref.watch(pathUidResolverProvider);
  final handles = await registry.resolve(accountId);
  final pathUid = await persistedPathUidFor(
    pathUids,
    accountId: accountId,
    liveUid: handles.authUid,
  );
  return handles.withPathUid(pathUid);
}, retry: (retryCount, error) => null);

/// The persisted Firestore-path uid for [accountId] (AD-24 rule 2), binding
/// it to [liveUid] only when the registry row has none yet (an initial bind,
/// never a remap). Throws `UnknownDeviceAccountException` when the account
/// has no registry row.
Future<String> persistedPathUidFor(
  PathUidResolver pathUids, {
  required String accountId,
  required String liveUid,
}) async {
  final persisted = await pathUids.pathUidFor(accountId);
  if (persisted == null || persisted.isEmpty) {
    final bound = await pathUids.reconcileLiveUid(
      accountId: accountId,
      liveUid: liveUid,
    );
    return bound.newUid;
  }
  if (persisted != liveUid) {
    AppLogger.instance.warning(
      event: 'active_account_path_uid_differs_from_live_uid',
      fields: {'accountId': accountId},
    );
  }
  return persisted;
}
