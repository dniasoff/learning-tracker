/// The `AccountFirebase` registry — one named [FirebaseApp], with its own
/// **authenticated** session, per device account.
///
/// This is the single place that constructs, names, authenticates, and
/// caches per-account Firebase handles. Every later phase (the repository
/// layer, Epic B) resolves its Firestore/Auth handle through this file:
///
/// - **Named app per account.** Each device account (≤[kMaxDeviceAccounts])
///   gets its own `Firebase.initializeApp(name:)`, with its own Firestore +
///   Auth instance. The default (unnamed) app is a separate concern this
///   registry never touches — it neither calls `Firebase.app()`/
///   `Firebase.initializeApp()` with no `name`, nor hands out the default
///   app as a data path.
/// - **The app's session is always authenticated.** This is the defect this
///   file fixes: a named `FirebaseApp` used to exist with nothing ever
///   signed in on its `FirebaseAuth` instance, so every Firestore read
///   against it carried `request.auth == null` and every rules-gated read
///   was denied. Every handle this registry now hands out — from
///   [resolve], [createAnonymousAccount], [signInCloudAccount] — already
///   has a signed-in [uid] by the time the caller sees it.
/// - No bare `FirebaseFirestore.instance` / `FirebaseAuth.instance`. Every
///   handle here comes from `instanceFor(app:)` against a named
///   [FirebaseApp] this registry itself created or found
///   (`tool/check_bare_firebase_instance_ratchet.dart` exempts this file by
///   path precisely because this is where that resolution legitimately
///   happens).
/// - `Settings` (persistence + a bounded [kAccountFirestoreCacheSizeBytes])
///   is pinned via the `.settings` setter immediately after obtaining the
///   `FirebaseFirestore` handle for an account, before any other call on
///   it, and exactly once per account for the lifetime of its native app
///   (re-assigning `.settings` on an already-used instance throws — see
///   [_sessionFor]).
/// - The named-app key is the **stable device-registry account UUID**
///   (`DeviceAccounts.accountId`), never the live Firebase uid. This keeps
///   the app + its on-disk cache directory stable across an anonymous-uid
///   reset; the Firestore-*path* uid is [AccountFirebaseHandles.uid], a
///   separate field this registry hands out but does not persist itself.
///
/// ## Account lifecycle
///
/// Creating an account is a distinct, explicit, network-requiring action —
/// [createAnonymousAccount] (fresh device-only account) or
/// [signInCloudAccount] (sign-up/sign-in with a credential). [resolve] is
/// deliberately NOT a third way to create one: it re-attaches to a session
/// one of those two already established (in this process or a previous
/// one) and throws [AccountNotAuthenticatedException] if there is none.
/// This split matters because creation needs the network once
/// (`signInAnonymously`/`signInWithCredential` are RPCs) while re-attaching
/// to an already-authenticated app does not — Firebase Auth persists the
/// signed-in user per named app, and Firestore serves reads from its local
/// cache, so a previously-created account works fully offline.
///
/// [linkCredential] is the anonymous-to-cloud upgrade: `linkWithCredential`
/// is documented by the SDK to attach the new credential to the *existing*
/// signed-in user, so [uid] — and therefore every Firestore path already
/// written under it — never changes. There is no data migration step.
///
/// [signOut] clears an account's Auth session without tearing its app down
/// (the native app + Firestore cache stay alive; the Dart-side
/// authenticated-handle cache is dropped so a stale, signed-out handle can
/// never be handed back by [resolve]). [dispose] is the full teardown: it
/// additionally terminates the Firestore instance and deletes the native
/// app, freeing the account's slot against [maxAccounts].
///
/// - **App Check is activated per named app, mirroring the default app.**
///   `lib/app/bootstrap/firebase_bootstrap.dart` activates App Check on the
///   default app (`FirebaseAppCheck.instance.activate(...)`) before any
///   Firestore/Auth/Storage use on it, because enforcement is live in
///   production (a real 2026-07-29 outage: enforcement-on + Play Integrity
///   disabled denied all Play-build Firestore traffic — see
///   `SyncErrorCode.appCheck`, `sync_orchestrator.dart`). A named app has its
///   own attestation identity — `FirebaseAppCheck.instance` only covers the
///   default app — so this registry activates App Check on EVERY named app
///   too, via `FirebaseAppCheck.instanceFor(app:)`, with the exact same
///   provider selection and non-fatal/timeout semantics as bootstrap (see
///   [_tryResolveAndActivateAppCheck]).
///
/// ## Testability without a device
///
/// Real `Firebase.initializeApp` needs a platform binding this file cannot
/// assume in a unit test. Every native SDK entry point this class touches
/// is injectable — [FirebaseAppInitializer], [FirestoreResolver],
/// [FirebaseAuthResolver], [FirebaseAppsLister], [AppCheckResolver],
/// [AppCheckActivator], [AppDeleter] — with production defaults that call
/// the real SDK. A unit test supplies fakes/mocks for all of these and never
/// touches a platform channel; `mocktail`'s `class MockFirebaseApp extends
/// Mock implements FirebaseApp {}` pattern works here too, since `Mock`
/// overrides `noSuchMethod` and never calls the real constructor.
/// `FirebaseAuth` itself is not sealed, so every auth call this file makes
/// (`currentUser`, `authStateChanges()`, `signInAnonymously()`,
/// `signInWithCredential()`, `User.linkWithCredential()`, `signOut()`) is
/// exercised by stubbing the SAME mock [FirebaseAuthResolver] hands back —
/// no separate auth seam is needed.
///
/// [AccountSessionHook] (the `onSessionCreated` constructor parameter) is a
/// separate, production-`null`-by-default seam for a DIFFERENT problem: an
/// integration test driving the real SDK against the Firestore/Auth
/// EMULATORS still needs `useFirestoreEmulator`/`useAuthEmulator` called on
/// the real app/firestore/auth instances before anything signs in — no
/// amount of injecting fakes helps there, since the whole point is to
/// exercise the real SDK. See its doc for why this is exactly (and only)
/// the ordering slot that need.
///
/// No `cloud_firestore`/`firebase_auth`/`firebase_core` symbol here is
/// re-exported to `lib/features/**` — callers receive
/// [AccountFirebaseHandles] and nothing else.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:learning_tracker/core/database/registry/device_registry_database.dart'
    show MaxAccountsReachedException, kMaxDeviceAccounts;
import 'package:learning_tracker/core/logging/logger.dart';

/// Bounded per-account Firestore on-disk persistence cache size.
///
/// The Firestore SDK's own default, if `cacheSizeBytes` is left unset, is
/// 40 MB per app instance; at [kMaxDeviceAccounts] (5) named apps that is
/// 200 MB worst case with zero deliberate choice made. This registry sets
/// an explicit, smaller bound instead: 20 MiB per account (5 × 20 MiB =
/// 100 MiB worst-case total), comfortably above the SDK's enforced floor
/// (`cacheSizeBytes` must be `null`, `-1`, or in `[1 MiB, 100 MiB]`) and
/// nowhere near [Settings.CACHE_SIZE_UNLIMITED] (`-1`, forbidden here).
const int kAccountFirestoreCacheSizeBytes = 20 * 1024 * 1024;

/// Prefix every named app created by this registry carries, ahead of the
/// sanitized account id: `'account_<deviceRegistryAccountUuid>'`.
const String kAccountAppNamePrefix = 'account_';

/// Characters considered safe, unescaped, inside a Firebase app name minted
/// by this registry. `DeviceAccounts.accountId` is minted as a `Uuid().v4()`
/// string (lowercase hex + hyphens only), which already satisfies this set;
/// [AccountFirebase.appNameForAccount] still sanitizes defensively rather
/// than trusting that invariant blindly, since the id also ends up embedded
/// verbatim in an on-disk Firestore persistence filename — a stray
/// path-unsafe character (`/`, `.`, whitespace, …) would corrupt a filename
/// rather than merely fail a Firebase validation call.
final RegExp _unsafeAppNameChar = RegExp('[^A-Za-z0-9_-]');

/// Thrown by [AccountFirebase.resolve] when [accountId] has no
/// authenticated session to re-attach to — i.e. it was never created via
/// [AccountFirebase.createAnonymousAccount] / [AccountFirebase
/// .signInCloudAccount], in this process or a previous one. [resolve]
/// never signs in by itself; this is the loud failure instead of silently
/// handing back an unauthenticated (and therefore Firestore-rules-denied)
/// handle.
class AccountNotAuthenticatedException implements Exception {
  const AccountNotAuthenticatedException(this.accountId);

  /// The device-registry account id [AccountFirebase.resolve] was asked
  /// for.
  final String accountId;

  @override
  String toString() =>
      'AccountNotAuthenticatedException: account "$accountId" has no '
      'authenticated Firebase session — call createAnonymousAccount or '
      'signInCloudAccount before resolve.';
}

/// Immutable bundle of the handles this registry hands out for one device
/// account. Always authenticated: [uid] is the signed-in user's id at the
/// moment this bundle was produced, and is the Firestore-*path* uid for
/// this account.
///
/// **Not immutable end-to-end.** [isDisposed] is a mutable marker
/// [AccountFirebase] flips the moment it starts tearing this bundle's app
/// down (see [AccountFirebase.dispose]). This exists because
/// `cloud_firestore`'s `FirebaseFirestore.instanceFor` caches instances in
/// its own static map with no `registerService` hook into
/// `FirebaseApp.delete()` (unlike `firebase_auth`, which does register and
/// therefore self-invalidates on delete) — so [firestore] on an
/// already-disposed bundle would otherwise look and act exactly like a
/// live handle to any caller that kept a reference to it past
/// [AccountFirebase.dispose]. [isDisposed] lets such a holder detect that
/// asymmetry. [AccountFirebase.signOut] does NOT set this marker — the
/// account's app/Firestore cache stay alive across a sign-out, only its
/// Auth session is cleared.
final class AccountFirebaseHandles {
  AccountFirebaseHandles({
    required this.app,
    required this.firestore,
    required this.auth,
    required this.uid,
    this.appCheck,
  });

  /// The named [FirebaseApp] this account's handles are scoped to. Its
  /// [FirebaseApp.name] is [AccountFirebase.appNameForAccount] applied to
  /// the account id — never the live Firebase uid.
  final FirebaseApp app;

  /// This account's private Firestore instance. [Settings] (persistence +
  /// [kAccountFirestoreCacheSizeBytes]) is already pinned by the time this
  /// bundle is returned — callers never need to set `.settings`
  /// themselves, and must not (a second assignment throws).
  final FirebaseFirestore firestore;

  /// This account's private, already-signed-in Auth instance.
  final FirebaseAuth auth;

  /// The signed-in user's uid at the moment this bundle was produced — the
  /// Firestore-path uid for this account.
  final String uid;

  /// This account's private App Check instance, or `null` if resolution/
  /// activation was not possible on this run (see
  /// [AccountFirebase._tryResolveAndActivateAppCheck] — best-effort,
  /// non-fatal, mirroring `firebase_bootstrap.dart`'s treatment of the
  /// default app). A `null` here means this account's requests carry no
  /// attestation token; under App Check enforcement (live in production —
  /// see the library doc) that degrades to Firestore denying its requests,
  /// not to this registry failing account creation.
  final FirebaseAppCheck? appCheck;

  bool _disposed = false;

  /// Whether [AccountFirebase.dispose] has already torn this bundle's
  /// native app down.
  bool get isDisposed => _disposed;

  void _markDisposed() {
    _disposed = true;
  }
}

/// Abstracts `Firebase.initializeApp` so tests can supply a platform-binding
/// -free fake. Production default: the real static method.
typedef FirebaseAppInitializer =
    Future<FirebaseApp> Function({
      required String name,
      required FirebaseOptions options,
    });

/// Abstracts `Firebase.apps` (the list of already-initialized native apps)
/// so [AccountFirebase] can defensively reuse an app that already exists
/// natively (e.g. a Dart-side registry object recreated mid-process, such
/// as across a hot restart, while the native app survives) instead of
/// calling `initializeApp` a second time with the same name, which the SDK
/// rejects (`[core/duplicate-app]`).
typedef FirebaseAppsLister = List<FirebaseApp> Function();

/// Abstracts `FirebaseFirestore.instanceFor(app:)`.
typedef FirestoreResolver = FirebaseFirestore Function(FirebaseApp app);

/// Abstracts `FirebaseAuth.instanceFor(app:)`.
typedef FirebaseAuthResolver = FirebaseAuth Function(FirebaseApp app);

/// Abstracts `FirebaseApp.delete()`.
typedef AppDeleter = Future<void> Function(FirebaseApp app);

/// Abstracts `FirebaseAppCheck.instanceFor(app:)`.
typedef AppCheckResolver = FirebaseAppCheck Function(FirebaseApp app);

/// Abstracts activating App Check on a resolved [FirebaseAppCheck] handle
/// (debug provider under `kDebugMode`, Play Integrity/App Attest
/// otherwise — mirrors `firebase_bootstrap.dart`'s default-app activation
/// exactly). Never throws by contract: callers (this registry) still wrap
/// the call defensively, matching the bootstrap file's own belt-and-braces
/// non-fatal treatment.
typedef AppCheckActivator = Future<void> Function(FirebaseAppCheck appCheck);

/// Runs once per account, right after its named [FirebaseApp]/
/// [FirebaseFirestore]/[FirebaseAuth] instances exist and App Check has been
/// (best-effort) activated, but strictly BEFORE any sign-in call — see the
/// library doc's "Testability without a device" section for what this seam
/// is for and why it exists separately from the fake/mock injection seams.
/// `null` (the production default) means no hook runs. The one real caller
/// today is `integration_test/account_firebase_*.dart`, which uses it to
/// call `useFirestoreEmulator`/`useAuthEmulator` on the real SDK instances
/// before `createAnonymousAccount`/`signInCloudAccount` signs in — the SDK
/// requires that ordering (emulator redirection must precede the first
/// operation on an instance), and no fake/mock seam can substitute for it
/// when the test is deliberately driving the real SDK.
typedef AccountSessionHook =
    Future<void> Function(
      FirebaseApp app,
      FirebaseFirestore firestore,
      FirebaseAuth auth,
    );

FirebaseFirestore _defaultResolveFirestore(FirebaseApp app) =>
    FirebaseFirestore.instanceFor(app: app);

FirebaseAuth _defaultResolveAuth(FirebaseApp app) =>
    FirebaseAuth.instanceFor(app: app);

FirebaseAppCheck _defaultResolveAppCheck(FirebaseApp app) =>
    FirebaseAppCheck.instanceFor(app: app);

/// Mirrors `firebase_bootstrap.dart`'s default-app activation call
/// exactly — same provider selection, same 10s timeout (guards against a
/// corrupted Firebase Installation ID hanging `activate()` indefinitely
/// instead of throwing).
Future<void> _defaultActivateAppCheck(FirebaseAppCheck appCheck) => appCheck
    .activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    )
    .timeout(const Duration(seconds: 10));

Future<void> _defaultDeleteApp(FirebaseApp app) => app.delete();

/// The wiring for one device account: its named [FirebaseApp], Firestore
/// instance (settings already pinned), Auth instance, and (best-effort)
/// App Check instance. Cached separately from [AccountFirebaseHandles] so a
/// [AccountFirebase.signOut] can drop the authenticated bundle without
/// re-touching (and illegally re-assigning `.settings` on) the still-live
/// Firestore instance underneath it.
class _AppSession {
  _AppSession({
    required this.app,
    required this.firestore,
    required this.auth,
    this.appCheck,
  });

  final FirebaseApp app;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseAppCheck? appCheck;
}

/// Owns the lifecycle of one named [FirebaseApp] + authenticated Firestore/
/// Auth session per device account. See the library doc comment for the
/// rules this class exists to enforce.
///
/// **Concurrency-safe idempotent resolution.** Every method that can
/// establish a NEW session for an account id shares the same native-app
/// session, while [_obtain] deduplicates in-flight work by both account id
/// and intent. Reattach-only [resolve] must not adopt an authenticating
/// caller's work (or vice versa): the two operations have different
/// authentication contracts, even though they share the app/session setup.
///
/// **Bounded, not silently evicting.** Establishing a session for a NEW
/// account id once [maxAccounts] accounts are already active throws
/// [MaxAccountsReachedException] — the same exception
/// `DeviceRegistryDatabase.addAccount` throws for the same real-world limit
/// (≤5 device accounts), reused here rather than duplicating a second "too
/// many accounts" type.
class AccountFirebase {
  AccountFirebase({
    required FirebaseOptions options,
    this.maxAccounts = kMaxDeviceAccounts,
    FirebaseAppInitializer? initializeApp,
    FirebaseAppsLister? listApps,
    FirestoreResolver? resolveFirestore,
    FirebaseAuthResolver? resolveAuth,
    AppCheckResolver? resolveAppCheck,
    AppCheckActivator? activateAppCheck,
    AppDeleter? deleteApp,
    AppLogger? logger,
    bool enableAppCheck = true,
    AccountSessionHook? onSessionCreated,
  }) : _options = options,
       _initializeApp = initializeApp ?? Firebase.initializeApp,
       _listApps = listApps ?? (() => Firebase.apps),
       _resolveFirestore = resolveFirestore ?? _defaultResolveFirestore,
       _resolveAuth = resolveAuth ?? _defaultResolveAuth,
       _resolveAppCheck = resolveAppCheck ?? _defaultResolveAppCheck,
       _activateAppCheck = activateAppCheck ?? _defaultActivateAppCheck,
       _deleteApp = deleteApp ?? _defaultDeleteApp,
       _logger = logger ?? AppLogger.instance,
       _enableAppCheck = enableAppCheck,
       _onSessionCreated = onSessionCreated {
    if (maxAccounts <= 0) {
      throw ArgumentError.value(maxAccounts, 'maxAccounts', 'must be positive');
    }
  }

  /// The [FirebaseOptions] every named app is created with — always
  /// `DefaultFirebaseOptions.currentPlatform` in production. Fixed for the
  /// lifetime of this registry: every account shares the same Firebase
  /// project, differing only by app name + Auth identity.
  final FirebaseOptions _options;

  /// The bound this registry enforces (defaults to [kMaxDeviceAccounts]).
  final int maxAccounts;

  final FirebaseAppInitializer _initializeApp;
  final FirebaseAppsLister _listApps;
  final FirestoreResolver _resolveFirestore;
  final FirebaseAuthResolver _resolveAuth;
  final AppCheckResolver _resolveAppCheck;
  final AppCheckActivator _activateAppCheck;
  final AppDeleter _deleteApp;
  final AppLogger _logger;
  final bool _enableAppCheck;
  final AccountSessionHook? _onSessionCreated;

  /// App + Firestore (settings pinned) + Auth wiring, keyed by account id.
  /// Populated once per account and never re-created by [signOut] — only
  /// [dispose] removes an entry.
  final Map<String, _AppSession> _sessions = {};

  /// The last-produced authenticated bundle per account id. Cleared by
  /// [signOut] (the session survives; the bundle does not) and by
  /// [dispose].
  final Map<String, AccountFirebaseHandles> _handles = {};

  /// In-flight first-time session establishments, keyed by account id.
  /// In-flight establishment keyed by account id and authentication intent.
  /// A reattach-only resolve may fail because no user is signed in; that
  /// failure must never be returned to a concurrent authenticating caller.
  final Map<(String, bool), Future<AccountFirebaseHandles>> _pending = {};

  /// Accounts currently being torn down by [dispose] — recorded before the
  /// native `app.delete()` call starts and cleared once it (and the
  /// `firestore.terminate()` that precedes it) finishes. [_obtain] consults
  /// this so a fast dispose→re-establish of the SAME account id cannot hand
  /// back an app the SDK still lists but is mid-way through deleting
  /// natively.
  final Map<String, Future<void>> _disposing = {};

  /// Derives this registry's named-app identity for [accountId]:
  /// `'account_<sanitized accountId>'`. Pure — no Firebase call, no
  /// registry state.
  static String appNameForAccount(String accountId) {
    if (accountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'must not be empty');
    }
    final sanitized = accountId.replaceAll(_unsafeAppNameChar, '_');
    return '$kAccountAppNamePrefix$sanitized';
  }

  /// The account ids currently holding a live session (settled or
  /// in-flight). Snapshot — mutating the returned set has no effect on the
  /// registry. Counts an account still active after [signOut] (its app is
  /// still alive, still occupying a slot) — only [dispose] frees one.
  Set<String> get activeAccountIds => {
    ..._sessions.keys,
    ..._pending.keys.map((key) => key.$1),
  };

  /// Whether [accountId] currently has an authenticated handle bundle
  /// cached (`false` immediately after [signOut], even though the
  /// underlying session is still active — see [activeAccountIds]).
  bool isActive(String accountId) => _handles.containsKey(accountId);

  /// Re-attaches to [accountId]'s already-authenticated session: reuses the
  /// account's named [FirebaseApp] (creating it if this process has not
  /// seen it yet — that part is local, no network) and waits for its
  /// already-signed-in user, never signing one in itself.
  ///
  /// Throws [AccountNotAuthenticatedException] if [accountId] has never
  /// been authenticated (no persisted session to restore) — call
  /// [createAnonymousAccount] or [signInCloudAccount] first.
  Future<AccountFirebaseHandles> resolve(String accountId) {
    return _obtain(accountId, (auth) async {
      final user = auth.currentUser ?? await auth.authStateChanges().first;
      if (user == null) {
        throw AccountNotAuthenticatedException(accountId);
      }
      return user;
    }, authenticating: false);
  }

  /// Creates (or re-attaches to) [accountId] as a device-only anonymous
  /// account: finds-or-initializes its named app (local), then signs in
  /// anonymously on that app's Auth instance if it is not already signed
  /// in. **Requires the network** the first time (`signInAnonymously` is an
  /// RPC); a call for an already-authenticated account is a no-op re-read
  /// of the existing session and needs none.
  ///
  /// A no-network failure propagates unwrapped (the owner-confirmed
  /// contract: "creation requires network once... allowed to fail without
  /// a network, and the caller surfaces that") — this registry does not
  /// buffer or stage a not-yet-created account for later retry. The
  /// account's named app IS still created (that part is local and cannot
  /// fail for network reasons), so a retry of this same call reuses it
  /// rather than leaking a second one.
  Future<AccountFirebaseHandles> createAnonymousAccount(String accountId) {
    return _obtain(accountId, (auth) async {
      final existing = auth.currentUser;
      if (existing != null) return existing;
      final credential = await auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw StateError(
          'createAnonymousAccount($accountId): signInAnonymously() '
          'returned a null user.',
        );
      }
      return user;
    }, authenticating: true);
  }

  /// Signs in [accountId] with [credential] on **that account's own named
  /// app** (never the default app) — the cloud sign-up/sign-in path.
  Future<AccountFirebaseHandles> signInCloudAccount(
    String accountId,
    AuthCredential credential,
  ) {
    return _obtain(accountId, (auth) async {
      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw StateError(
          'signInCloudAccount($accountId): signInWithCredential() '
          'returned a null user.',
        );
      }
      return user;
    }, authenticating: true);
  }

  /// Convenience wrapper for [signInCloudAccount] with an email/password
  /// pair — constructs the [EmailAuthProvider] credential internally so
  /// callers outside `lib/data/firestore/` and `lib/core/auth/` never need
  /// to import `firebase_auth` themselves (layering Rule 3).
  Future<AccountFirebaseHandles> signInCloudAccountWithEmail(
    String accountId, {
    required String email,
    required String password,
  }) {
    return signInCloudAccount(
      accountId,
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Convenience wrapper for [signInCloudAccount] with a Google [idToken] —
  /// same rationale as [signInCloudAccountWithEmail].
  Future<AccountFirebaseHandles> signInCloudAccountWithGoogleIdToken(
    String accountId, {
    required String idToken,
  }) {
    return signInCloudAccount(
      accountId,
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// Upgrade-to-Cloud: links [credential] onto [accountId]'s **currently
  /// signed-in** user via `User.linkWithCredential`.
  ///
  /// `linkWithCredential` is documented by the SDK to attach the new
  /// credential to the existing signed-in user rather than creating a new
  /// one — the returned user's uid is the SAME as the one signed in before
  /// this call. That is the whole point of this method: there is no data
  /// migration and no Firestore path re-homing, because the uid never
  /// changes.
  ///
  /// Throws [StateError] if [accountId] has no currently-resolved,
  /// signed-in session to link from — call [resolve] or
  /// [createAnonymousAccount] first.
  Future<AccountFirebaseHandles> linkCredential(
    String accountId,
    AuthCredential credential,
  ) async {
    final handles = _handles[accountId];
    if (handles == null) {
      throw StateError(
        'linkCredential($accountId): account is not currently resolved — '
        'call resolve or createAnonymousAccount first.',
      );
    }
    final currentUser = handles.auth.currentUser;
    if (currentUser == null) {
      throw StateError(
        'linkCredential($accountId): no signed-in user on this account\'s '
        'Auth session to link from.',
      );
    }

    final linked = await currentUser.linkWithCredential(credential);
    final linkedUser = linked.user;
    if (linkedUser == null) {
      throw StateError(
        'linkCredential($accountId): linkWithCredential() returned a null '
        'user.',
      );
    }

    final updated = AccountFirebaseHandles(
      app: handles.app,
      firestore: handles.firestore,
      auth: handles.auth,
      uid: linkedUser.uid,
    );
    _handles[accountId] = updated;
    return updated;
  }

  /// Signs [accountId] out of its Auth session. The named app and its
  /// Firestore instance (and on-disk cache) are left alive — only the
  /// authenticated-handle cache is dropped, so a later [resolve] cannot
  /// hand back a stale, now-signed-out bundle. Safe to call on an account
  /// with no active session (a no-op).
  Future<void> signOut(String accountId) async {
    final handles = _handles.remove(accountId);
    if (handles == null) return;
    await handles.auth.signOut();
  }

  /// Shared memoized-establishment path for [resolve]/
  /// [createAnonymousAccount]/[signInCloudAccount]. [authenticate] is given
  /// the account's (possibly freshly-created) [FirebaseAuth] instance and
  /// must return its signed-in [User] or throw.
  Future<AccountFirebaseHandles> _obtain(
    String accountId,
    Future<User> Function(FirebaseAuth auth) authenticate, {
    required bool authenticating,
  }) async {
    if (accountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'must not be empty');
    }

    final settled = _handles[accountId];
    if (settled != null) return settled;

    final pendingKey = (accountId, authenticating);
    final inFlight = _pending[pendingKey];
    if (inFlight != null) return inFlight;

    final disposing = _disposing[accountId];
    if (disposing != null) {
      await disposing;
      // Re-run every guard (including this one) against the post-disposal
      // state — a concurrent caller may have already started a fresh
      // establishment/dispose for this same accountId while this call was
      // waiting.
      return _obtain(accountId, authenticate, authenticating: authenticating);
    }

    // A session already exists for this account (e.g. re-authenticating
    // after signOut, or retrying a previously network-failed creation) —
    // it already occupies a slot, so the bound must not double-charge it.
    if (!_sessions.containsKey(accountId) &&
        activeAccountIds.length >= maxAccounts) {
      throw const MaxAccountsReachedException();
    }

    final future = _establish(accountId, authenticate);
    _pending[pendingKey] = future;
    try {
      final handles = await future;
      _handles[accountId] = handles;
      return handles;
    } finally {
      unawaited(_pending.remove(pendingKey));
    }
  }

  Future<AccountFirebaseHandles> _establish(
    String accountId,
    Future<User> Function(FirebaseAuth auth) authenticate,
  ) async {
    final session = await _sessionFor(accountId);
    final user = await authenticate(session.auth);
    return AccountFirebaseHandles(
      app: session.app,
      firestore: session.firestore,
      auth: session.auth,
      uid: user.uid,
      appCheck: session.appCheck,
    );
  }

  /// Finds-or-creates [accountId]'s app/Firestore/Auth/App-Check wiring,
  /// pinning Firestore `.settings` exactly once (immediately after
  /// obtaining the handle and before any other call on it). Reusing a
  /// cached [_AppSession] on a later call (e.g. after [signOut]) is what
  /// keeps this a single-pin operation — the Firestore SDK throws if
  /// `.settings` is assigned a second time on an instance that has already
  /// been used, and it is also why App Check is activated (and
  /// [_onSessionCreated] invoked) here exactly once rather than on every
  /// call.
  ///
  /// **Ordering, mirroring `firebase_bootstrap.dart`'s default-app
  /// sequence:** find-or-init the app (local) → activate App Check (before
  /// any Firestore/Auth use, so every request from this app carries an
  /// attestation token from the start) → resolve Firestore + pin settings
  /// (AD-18) → resolve Auth → run [_onSessionCreated] (test-only emulator
  /// redirection, strictly before this method's caller performs the first
  /// sign-in).
  Future<_AppSession> _sessionFor(String accountId) async {
    final existing = _sessions[accountId];
    if (existing != null) return existing;

    final appName = appNameForAccount(accountId);
    final app = await _findOrInitializeApp(appName);

    final appCheck = _enableAppCheck
        ? await _tryResolveAndActivateAppCheck(app)
        : null;

    final firestore = _resolveFirestore(app);
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: kAccountFirestoreCacheSizeBytes,
    );
    final auth = _resolveAuth(app);

    final hook = _onSessionCreated;
    if (hook != null) {
      await hook(app, firestore, auth);
    }

    final session = _AppSession(
      app: app,
      firestore: firestore,
      auth: auth,
      appCheck: appCheck,
    );
    _sessions[accountId] = session;
    return session;
  }

  /// Best-effort App Check resolution + activation. Non-fatal by design —
  /// mirrors `firebase_bootstrap.dart`'s treatment of the default app: a
  /// failure here must not block this account's Firestore/Auth handles
  /// (App Check enforcement denies the REQUEST, not account creation
  /// itself — the caller finds out the same way any other rules-denied
  /// Firestore call surfaces, via `SyncErrorCode.appCheck`).
  Future<FirebaseAppCheck?> _tryResolveAndActivateAppCheck(
    FirebaseApp app,
  ) async {
    try {
      final appCheck = _resolveAppCheck(app);
      await _activateAppCheck(appCheck);
      return appCheck;
    } catch (e, stack) {
      _logger.warning(
        event: 'account_firebase_app_check_activation_failed',
        exception: e,
        stackTrace: stack,
        fields: {'app_name': app.name},
      );
      return null;
    }
  }

  /// Reuses a native app that already exists for [appName] instead of
  /// re-initializing it; otherwise creates it fresh via [_initializeApp].
  Future<FirebaseApp> _findOrInitializeApp(String appName) async {
    for (final existing in _listApps()) {
      if (existing.name == appName) return existing;
    }
    return _initializeApp(name: appName, options: _options);
  }

  /// Tears down [accountId]'s named app (`app.delete()`) and releases every
  /// cached handle, making the registry safe to establish a session for
  /// that same account id again afterwards (a fresh `initializeApp` call
  /// against a fresh on-disk cache, not a stale in-memory hit).
  ///
  /// Safe to call on an account id with no active or in-flight session — a
  /// no-op — and safe to call twice in a row.
  ///
  /// If [accountId]'s first session establishment is still in flight, this
  /// awaits it first so the app it is creating is not deleted out from
  /// under it (swallowing a failure from that await — if establishment
  /// itself failed, there may be nothing left to tear down beyond the
  /// locally-created app, which the code below still removes).
  Future<void> dispose(String accountId) async {
    final inFlight = _pending.entries
        .where((entry) => entry.key.$1 == accountId)
        .map((entry) => entry.value)
        .toList();
    for (final future in inFlight) {
      try {
        await future;
      } catch (_) {
        // Establishment failed (e.g. no network for signInAnonymously);
        // fall through to clean up whatever it DID create locally.
      }
    }

    final handles = _handles.remove(accountId);
    final session = _sessions.remove(accountId);
    if (session == null) return;

    handles?._markDisposed();
    final teardown = _teardown(session);
    _disposing[accountId] = teardown;
    try {
      await teardown;
    } finally {
      unawaited(_disposing.remove(accountId));
    }
  }

  /// Releases [session]'s native resources. `app.delete()` alone does not
  /// release the [FirebaseFirestore] handle — `cloud_firestore` caches
  /// `instanceFor` results in a static map with no `registerService` hook
  /// into `FirebaseApp.delete()` (unlike `firebase_auth`, which does
  /// register and is therefore disposed automatically). Left alone, a
  /// disposed account's Firestore handle would keep working against a
  /// deleted app while its Auth handle throws, and a live `snapshots()`
  /// subscription would keep running against a deleted app. `terminate()`
  /// closes both, so it runs BEFORE `app.delete()`.
  Future<void> _teardown(_AppSession session) async {
    await session.firestore.terminate();
    await _deleteApp(session.app);
  }

  /// Disposes every currently-active account. Convenience for full
  /// teardown (e.g. sign-out-all, test cleanup) — not itself atomic across
  /// accounts (each is torn down independently); if one [dispose] throws,
  /// the remainder are still attempted.
  Future<void> disposeAll() async {
    final ids = {..._sessions.keys, ..._pending.keys.map((key) => key.$1)};
    final errors = <Object>[];
    for (final id in ids) {
      try {
        await dispose(id);
      } catch (e) {
        errors.add(e);
      }
    }
    if (errors.isNotEmpty) {
      throw StateError(
        'disposeAll: ${errors.length} account(s) failed to dispose cleanly: '
        '$errors',
      );
    }
  }
}
