/// The `AccountFirebase` registry — Phase 1 Story A (per-account named
/// `FirebaseApp` lifecycle).
///
/// **This is the scope-defining subsystem of the whole Drift→Firestore
/// migration.** Every later phase resolves its Firestore/Auth handle
/// through this file. It is the single place that constructs, names, and
/// caches per-account Firebase handles (AD-2, AD-24):
///
/// - **AD-1** — each cloud-backed or Anonymous-Auth-backed device account
///   (≤[kMaxDeviceAccounts]) gets its own `Firebase.initializeApp(name:)`
///   with a private Auth + Firestore + persistent cache. The default app
///   (bootstrapped separately in `lib/app/bootstrap/firebase_bootstrap.dart`)
///   is reserved for pre-auth/registry concerns only — this registry never
///   calls `Firebase.app()`/`Firebase.initializeApp()` with no `name`, and
///   never hands out the default app as a data path.
/// - **AD-2** — no bare `FirebaseFirestore.instance` / `FirebaseAuth.instance`.
///   Every handle in this file is obtained via `instanceFor(app:)` against a
///   named [FirebaseApp] this registry itself created or found.
/// - **AD-18** — `Settings` (persistence + a bounded `cacheSizeBytes`) is
///   pinned via the `.settings` setter immediately after obtaining the
///   `FirebaseFirestore` handle and before any other call on it.
/// - **AD-24** — the named-app key is the **stable device-registry account
///   UUID** (`DeviceAccounts.accountId`), never the live Firebase uid and
///   never `firebaseUid`. This keeps the app + its on-disk cache directory
///   stable across an anonymous-uid reset (AD-19); the Firestore-*path* uid
///   is a separate, persisted field this registry does not own.
///
/// Mirrors the topology `integration_test/firestore_multi_app_isolation_test.dart`
/// (Story 2.1) proved works on API 28 + 34: `Firebase.initializeApp(name:)`
/// → `FirebaseFirestore.instanceFor(app:)` → `.settings =` →
/// `FirebaseAuth.instanceFor(app:)`.
///
/// ## Testability without a device
///
/// Real `Firebase.initializeApp` needs a platform binding this file cannot
/// assume in a unit test. Every native SDK entry point this class touches
/// is therefore injectable — [FirebaseAppInitializer], [FirestoreResolver],
/// [FirebaseAuthResolver], [AppCheckResolver], [AppDeleter],
/// [FirebaseAppsLister] — with production defaults that call the real SDK.
/// A unit test supplies fakes/mocks for all five and never touches a
/// platform channel; `mocktail`'s `class MockFirebaseApp extends Mock
/// implements FirebaseApp {}` pattern (already used by
/// `test/core/sync/firestore_instance_provider_test.dart`) works here too,
/// since `Mock` overrides `noSuchMethod` and never calls the real
/// constructor.
///
/// No `cloud_firestore`/`firebase_auth`/`firebase_core` symbol here is
/// re-exported to `lib/features/**` — callers receive [AccountFirebaseHandles]
/// from [AccountFirebase.resolve] and nothing else (AD-23 dependency
/// direction; the `make audit` check 102/102 dependency-direction gate).
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

/// Bounded per-account Firestore on-disk persistence cache size (AD-18;
/// migration-plan Phase 1 risk register (c): "per-account cache disk cost
/// ×5 → set bounded `cacheSizeBytes`").
///
/// **Arithmetic.** The Firestore SDK's own default, if `cacheSizeBytes` is
/// left unset, is 40 MB per app instance (`Settings.cacheSizeBytes` doc:
/// "The default value is 40 MB"); at [kMaxDeviceAccounts] (5) named apps
/// that is already 200 MB worst case with zero deliberate choice made. This
/// registry sets an explicit, smaller bound instead: **20 MiB per
/// account**, i.e. `5 * 20 MiB = 100 MiB` worst-case total across the
/// bounded account count — half of what merely leaving the SDK default in
/// place would cost, and nowhere near [Settings.CACHE_SIZE_UNLIMITED]
/// (`-1`, forbidden by AD-18). 20 MiB is comfortably above the SDK's
/// enforced floor (`cacheSizeBytes` must be `null`, `-1`, or in
/// `[1 MiB, 100 MiB]` — see `cloud_firestore_platform_interface`'s
/// `Settings.assertEquals`-adjacent range check) and gives an order of
/// magnitude of headroom over the migration plan's own heavy-user
/// reference point (Phase 5 exit criterion: "a representative
/// heavy/long-tenured account (E-4's ~2,300-doc user)" — a few thousand
/// small JSON documents plus indexes is low single-digit MB, not tens of
/// MB). The bound is intentionally conservative rather than tuned tight:
/// Phase 1's job is proving the registry lifecycle, not right-sizing cache
/// economics; this number can move (via a future story, not a silent edit
/// here) once real device telemetry exists.
const int kAccountFirestoreCacheSizeBytes = 20 * 1024 * 1024;

/// Prefix every named app created by this registry carries, ahead of the
/// sanitized account id (AD-1: `'account_<deviceRegistryAccountUuid>'`).
const String kAccountAppNamePrefix = 'account_';

/// Characters considered safe, unescaped, inside a Firebase app name minted
/// by this registry. `DeviceAccounts.accountId` is minted as a
/// `Uuid().v4()` string today (lowercase hex + hyphens only — see
/// `lib/features/account/onboarding/presentation/screens/signup_screen.dart`),
/// which already satisfies this set. [AccountFirebase.appNameForAccount]
/// still sanitizes defensively rather than trusting that invariant blindly
/// — the id also ends up embedded verbatim in an on-disk Firestore
/// persistence filename (see the Story 2.1 smoke test's
/// `firestore.<appName>.<projectId>.%28default%29` observation), so a
/// stray path-unsafe character (`/`, `.`, whitespace, …) would corrupt a
/// filename rather than merely fail a Firebase validation call.
final RegExp _unsafeAppNameChar = RegExp('[^A-Za-z0-9_-]');

/// Immutable bundle of the handles [AccountFirebase.resolve] returns for
/// one device account.
///
/// [appCheck] is nullable: resolving/activating App Check on a secondary
/// named app is attempted best-effort (mirrors
/// `lib/app/bootstrap/firebase_bootstrap.dart`'s non-fatal treatment of the
/// default app) and is `null` if unavailable rather than blocking the
/// account's Firestore/Auth handles, which the app can function without App
/// Check attestation (rules-only enforcement, unenforced App Check today —
/// AD-12).
final class AccountFirebaseHandles {
  const AccountFirebaseHandles({
    required this.app,
    required this.firestore,
    required this.auth,
    this.appCheck,
  });

  /// The named [FirebaseApp] this account's handles are scoped to. Its
  /// [FirebaseApp.name] is [AccountFirebase.appNameForAccount] applied to
  /// the account id — never the live Firebase uid (AD-24).
  final FirebaseApp app;

  /// This account's private Firestore instance. [Settings] (persistence +
  /// [kAccountFirestoreCacheSizeBytes]) is already pinned by the time this
  /// bundle is returned (AD-18) — callers never need to set `.settings`
  /// themselves, and must not (a second assignment can silently reset
  /// fields omitted from it).
  final FirebaseFirestore firestore;

  /// This account's private Auth instance.
  final FirebaseAuth auth;

  /// This account's private App Check instance, or `null` if resolution/
  /// activation was not possible on this run (see class doc).
  final FirebaseAppCheck? appCheck;
}

/// Abstracts `Firebase.initializeApp` so tests can supply a platform-binding
/// -free fake. Production default: the real static method.
typedef FirebaseAppInitializer =
    Future<FirebaseApp> Function({
      required String name,
      required FirebaseOptions options,
    });

/// Abstracts `Firebase.apps` (the list of already-initialized native apps)
/// so [AccountFirebase.resolve] can defensively reuse an app that already
/// exists natively (e.g. a Dart-side registry object recreated mid-process,
/// such as across a hot restart, while the native app survives) instead of
/// calling `initializeApp` a second time with the same name, which the SDK
/// rejects (`[core/duplicate-app]`).
typedef FirebaseAppsLister = List<FirebaseApp> Function();

/// Abstracts `FirebaseFirestore.instanceFor(app:)`.
typedef FirestoreResolver = FirebaseFirestore Function(FirebaseApp app);

/// Abstracts `FirebaseAuth.instanceFor(app:)`.
typedef FirebaseAuthResolver = FirebaseAuth Function(FirebaseApp app);

/// Abstracts `FirebaseAppCheck.instanceFor(app:)`.
typedef AppCheckResolver = FirebaseAppCheck Function(FirebaseApp app);

/// Abstracts activating App Check on a resolved [FirebaseAppCheck] handle
/// (debug provider under `kDebugMode`, Play Integrity/App Attest
/// otherwise — mirrors `firebase_bootstrap.dart`'s default-app activation
/// exactly). Never throws by contract: callers (this registry) still wrap
/// the call defensively, matching the bootstrap file's own belt-and-braces
/// non-fatal treatment.
typedef AppCheckActivator = Future<void> Function(FirebaseAppCheck appCheck);

/// Abstracts `FirebaseApp.delete()`.
typedef AppDeleter = Future<void> Function(FirebaseApp app);

FirebaseFirestore _defaultResolveFirestore(FirebaseApp app) =>
    FirebaseFirestore.instanceFor(app: app);

FirebaseAuth _defaultResolveAuth(FirebaseApp app) =>
    FirebaseAuth.instanceFor(app: app);

FirebaseAppCheck _defaultResolveAppCheck(FirebaseApp app) =>
    FirebaseAppCheck.instanceFor(app: app);

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

/// Owns the lifecycle of one named [FirebaseApp] (+ private Firestore/Auth/
/// App Check handles) per device account. See the library doc comment for
/// the AD-1/AD-2/AD-18/AD-24 rules this class exists to enforce.
///
/// **Concurrency-safe idempotent resolve.** [resolve] memoizes both settled
/// handles and in-flight resolutions, so two overlapping callers resolving
/// the same account id — e.g. two widgets rebuilding during startup — await
/// the SAME underlying `initializeApp` call rather than racing a second one
/// (which the SDK would reject with `[core/duplicate-app]`).
///
/// **Bounded, not silently evicting.** Resolving a NEW account id once
/// [maxAccounts] accounts are already active throws
/// [MaxAccountsReachedException] — the same exception
/// `DeviceRegistryDatabase.addAccount` throws for the same real-world limit
/// (≤5 device accounts), reused here rather than duplicating a second
/// "too many accounts" type, per the migration-plan Phase 1 requirement
/// "Exceeding it must fail loudly, not silently evict."
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
  }) : _options = options,
       _initializeApp = initializeApp ?? Firebase.initializeApp,
       _listApps = listApps ?? (() => Firebase.apps),
       _resolveFirestore = resolveFirestore ?? _defaultResolveFirestore,
       _resolveAuth = resolveAuth ?? _defaultResolveAuth,
       _resolveAppCheck = resolveAppCheck ?? _defaultResolveAppCheck,
       _activateAppCheck = activateAppCheck ?? _defaultActivateAppCheck,
       _deleteApp = deleteApp ?? _defaultDeleteApp,
       _logger = logger ?? AppLogger.instance,
       _enableAppCheck = enableAppCheck {
    if (maxAccounts <= 0) {
      throw ArgumentError.value(maxAccounts, 'maxAccounts', 'must be positive');
    }
  }

  /// The [FirebaseOptions] every named app is created with — always
  /// `DefaultFirebaseOptions.currentPlatform` in production. Fixed for the
  /// lifetime of this registry: every account shares the same Firebase
  /// project (AD-1's topology is N named apps against the same
  /// project/database, differing only by app name + Auth identity).
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

  final Map<String, AccountFirebaseHandles> _handles = {};
  final Map<String, Future<AccountFirebaseHandles>> _pending = {};

  /// Derives this registry's named-app identity for [accountId] (AD-1,
  /// AD-24): `'account_<sanitized accountId>'`. Pure — no Firebase call, no
  /// registry state. Every unsafe character (anything outside
  /// `[A-Za-z0-9_-]`) is replaced with `_` (see [_unsafeAppNameChar]'s doc
  /// for why this is defensive rather than load-bearing for today's UUID-v4
  /// account ids).
  static String appNameForAccount(String accountId) {
    if (accountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'must not be empty');
    }
    final sanitized = accountId.replaceAll(_unsafeAppNameChar, '_');
    return '$kAccountAppNamePrefix$sanitized';
  }

  /// The account ids currently holding a resolved (or resolving) handle
  /// bundle. Snapshot — mutating the returned set has no effect on the
  /// registry.
  Set<String> get activeAccountIds => {..._handles.keys, ..._pending.keys};

  /// Whether [accountId] currently has a settled handle bundle (does not
  /// count an in-flight [resolve] as active — see [activeAccountIds] for
  /// that).
  bool isActive(String accountId) => _handles.containsKey(accountId);

  /// Resolves (creating on first call, reusing thereafter) the named
  /// [FirebaseApp] + private Firestore/Auth/App Check handles for
  /// [accountId].
  ///
  /// **Idempotent.** A second call with the same [accountId] returns the
  /// exact same [AccountFirebaseHandles] instance and never calls
  /// `Firebase.initializeApp` again — this is the invariant the red-demo in
  /// this story exercises.
  ///
  /// **Settings-before-first-use (AD-18).** `.settings` is assigned on the
  /// freshly-resolved [FirebaseFirestore] instance before this method does
  /// anything else with it and before it is handed to the caller.
  ///
  /// Throws [MaxAccountsReachedException] if [accountId] is not already
  /// active and resolving it would exceed [maxAccounts].
  Future<AccountFirebaseHandles> resolve(String accountId) async {
    if (accountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'must not be empty');
    }

    final settled = _handles[accountId];
    if (settled != null) return settled;

    final inFlight = _pending[accountId];
    if (inFlight != null) return inFlight;

    if (_handles.length >= maxAccounts) {
      throw const MaxAccountsReachedException();
    }

    final future = _resolveNew(accountId);
    _pending[accountId] = future;
    try {
      final handles = await future;
      _handles[accountId] = handles;
      return handles;
    } finally {
      // The removed value is this same (already-settled, since we're past
      // `await future`) Future reference — discarding it here is not a
      // forgotten `await`, just dropping the now-stale pending-map entry.
      unawaited(_pending.remove(accountId));
    }
  }

  Future<AccountFirebaseHandles> _resolveNew(String accountId) async {
    final appName = appNameForAccount(accountId);

    final app = await _findOrInitializeApp(appName);

    // AD-18: `.settings` MUST be assigned immediately after obtaining the
    // handle and before any other call on it — this is that ordering,
    // enforced in exactly this one place.
    final firestore = _resolveFirestore(app);
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: kAccountFirestoreCacheSizeBytes,
    );

    final auth = _resolveAuth(app);
    final appCheck = _enableAppCheck
        ? await _tryResolveAndActivateAppCheck(app)
        : null;

    return AccountFirebaseHandles(
      app: app,
      firestore: firestore,
      auth: auth,
      appCheck: appCheck,
    );
  }

  /// Reuses a native app that already exists for [appName] (see
  /// [FirebaseAppsLister]'s doc) instead of re-initializing it; otherwise
  /// creates it fresh via [_initializeApp].
  Future<FirebaseApp> _findOrInitializeApp(String appName) async {
    for (final existing in _listApps()) {
      if (existing.name == appName) return existing;
    }
    return _initializeApp(name: appName, options: _options);
  }

  /// Best-effort App Check resolution + activation. Non-fatal by design —
  /// mirrors `firebase_bootstrap.dart`'s treatment of the default app: a
  /// failure here must not block this account's Firestore/Auth handles
  /// (App Check is currently rules-unenforced — AD-12 — so its absence
  /// degrades attestation, not availability).
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

  /// Tears down [accountId]'s named app (`app.delete()`) and releases its
  /// handles, making the registry safe to [resolve] that same account id
  /// again afterwards (a fresh `initializeApp` call, not a stale cache
  /// hit).
  ///
  /// Safe to call on an account id with no active or in-flight handles — a
  /// no-op in that case, so callers do not need to guard with [isActive]
  /// first, and disposing twice in a row is safe (the second call is a
  /// no-op once the first has removed the entry).
  ///
  /// If [accountId] is currently resolving (an in-flight [resolve] call in
  /// progress from another caller), this awaits that resolution first so
  /// the app it just created is not deleted out from under it — then
  /// immediately tears it down.
  Future<void> dispose(String accountId) async {
    final inFlight = _pending[accountId];
    if (inFlight != null) {
      await inFlight;
    }

    final handles = _handles.remove(accountId);
    if (handles == null) return;

    await _deleteApp(handles.app);
  }

  /// Disposes every currently-active account. Convenience for full
  /// teardown (e.g. sign-out-all, test cleanup) — not itself atomic across
  /// accounts (each is torn down independently); if one [dispose] throws,
  /// the remainder are still attempted.
  Future<void> disposeAll() async {
    final ids = [..._handles.keys, ..._pending.keys];
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
