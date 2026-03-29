# Local-First Auth Abstraction Layer — Technical Design

**Status:** Draft
**Date:** 2026-03-29
**Scope:** Remove Firebase Auth as a hard dependency; allow the app to function fully offline from first launch with no account required.

---

## Executive Summary

The app currently requires Firebase Auth to function. `AuthGuard` blocks all protected routes by awaiting `authStateChanges().first` (hangs offline). `GoogleSignIn.initialize()` is called at startup without try/catch (crashes offline). Every protected route is gated by `authGuard`. The goal is to make the app work from first launch with zero network, deferring account creation to an opt-in action in Settings.

The core idea: introduce a **two-tier identity model** — a mandatory local identity (UUID) that exists from first launch, and an optional Firebase identity that layers on top when the user chooses to create an account. The app always has an identity; it just may not be a Firebase one.

---

## 1. Local Profile System

### 1.1 Local UUID Generation

Generate a v4 UUID on first launch using the `uuid` package (already a transitive dependency via Drift). Store it in SharedPreferences under the key `local_device_uid`.

```
Key:   'local_device_uid'
Value: '550e8400-e29b-41d4-a716-446655440000'   (v4 UUID string)
```

**Why SharedPreferences, not the DB?**
- The UUID must be available *before* the database is opened (it seeds the first `UserProfiles` row).
- SharedPreferences is synchronous-read after the first async load (already loaded by `WidgetsFlutterBinding.ensureInitialized()`).
- The DB stores the same value in `UserProfiles.firebaseUid` as the canonical record, but SharedPreferences is the bootstrap source.

**Generation logic (pseudocode):**
```
localUid = prefs.getString('local_device_uid');
if (localUid == null) {
  localUid = Uuid().v4();
  prefs.setString('local_device_uid', localUid);
}
```

This runs once, at first launch. The value is stable for the lifetime of the app installation.

### 1.2 UserProfiles Table Changes

**Current schema:**
```dart
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firebaseUid => text().unique()();  // NOT NULL
  TextColumn get displayName => text()();
  TextColumn get userMode => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
```

**New schema:**
```dart
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localUid => text().unique()();          // NEW: always set, v4 UUID
  TextColumn get firebaseUid => text().nullable()();     // CHANGED: nullable
  TextColumn get displayName => text()();
  TextColumn get userMode => text()();
  BoolColumn get hasAccount => boolean().withDefault(const Constant(false))(); // NEW
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
```

**Key decisions:**
- `localUid` is the primary stable identifier. It is set at profile creation and never changes.
- `firebaseUid` becomes nullable. It is set when the user links a Firebase account.
- `hasAccount` is a denormalized convenience flag. It avoids `firebaseUid != null` checks scattered through the codebase. It is the single source of truth for "does this user have a cloud account?"
- The `unique()` constraint on `firebaseUid` remains but now allows multiple nulls (SQLite allows multiple NULL values in UNIQUE columns).

**Migration (Drift schema version bump):**
1. Add `localUid TEXT NOT NULL` with a default of `''` (for existing rows).
2. Make `firebaseUid` nullable.
3. Add `hasAccount BOOLEAN NOT NULL DEFAULT 0`.
4. Run a data migration: for every existing row where `firebaseUid` is non-empty, copy `firebaseUid` into `localUid` (preserving identity) and set `hasAccount = true`. This means existing users keep their existing UID as their local UID — no data remapping needed.
5. For any row where `localUid` is still `''` after step 4 (should not happen in practice), generate a fresh UUID.

### 1.3 Profiles Table

No change needed. `Profiles.accountId` references `UserProfiles.id` (the auto-increment integer PK), not the UID directly. The FK relationship is stable regardless of whether the UID is local or Firebase.

### 1.4 Impact on Firestore Paths

Current Firestore paths: `users/{firebaseUid}/profiles/{profileId}/...`

The `localUid` is never used as a Firestore path component. When sync is active (user has an account), `FirestoreDataSource._userDoc` continues to use `FirebaseAuth.instance.currentUser.uid` — the Firebase UID. The `localUid` is a local-only concept.

---

## 2. Auth Abstraction Layer

### 2.1 AuthState Model

Replace the raw `Stream<User?>` with a richer, app-owned auth state.

```dart
/// Represents the app's authentication state, independent of Firebase.
sealed class AppAuthState {
  String get displayUid;       // localUid (always available)
  String get displayName;
  bool get hasCloudAccount;
  String? get firebaseUid;     // null if local-only
}

class LocalAuthState implements AppAuthState {
  final String localUid;
  final String displayName;

  @override String get displayUid => localUid;
  @override bool get hasCloudAccount => false;
  @override String? get firebaseUid => null;
}

class CloudAuthState implements AppAuthState {
  final String localUid;
  final String firebaseUid;
  final String displayName;
  final String email;
  final List<String> providers;  // ['password', 'google.com']

  @override String get displayUid => localUid;
  @override bool get hasCloudAccount => true;
}
```

### 2.2 AuthStateService

A new Riverpod `keepAlive` provider that is the single source of truth for auth state across the app.

```dart
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AppAuthState build() {
    // On startup, read from UserProfiles DB (or SharedPreferences for bootstrap)
    // Returns LocalAuthState immediately — no network dependency
    return _resolveInitialState();
  }

  /// Called when user creates/links a Firebase account.
  void promoteToCloud(User firebaseUser) { ... }

  /// Called on sign-out.
  void demoteToLocal() { ... }
}
```

**Resolution order on startup:**
1. Read `local_device_uid` from SharedPreferences (instant, sync).
2. Check `UserProfiles` table for a row with matching `localUid`.
3. If row exists and `hasAccount == true`, attempt to read `FirebaseAuth.instance.currentUser` (synchronous property, no network call). If non-null, emit `CloudAuthState`. If null (Firebase SDK not ready or token expired), emit `LocalAuthState` — the user is still "local" for this session and sync is dormant until Firebase re-authenticates.
4. If no row or `hasAccount == false`, emit `LocalAuthState`.

**Key property:** This method makes zero network calls. The app is usable in under 500ms.

### 2.3 How Providers Switch on Account Creation

When the user creates a Firebase account (from Settings):

1. `AuthRepository.signUp()` or `signInWithGoogle()` completes successfully.
2. Caller invokes `ref.read(authStateNotifierProvider.notifier).promoteToCloud(firebaseUser)`.
3. `promoteToCloud` runs the UID migration (section 5) in a DB transaction.
4. State changes from `LocalAuthState` to `CloudAuthState`.
5. All providers watching `authStateNotifierProvider` rebuild.
6. `SyncEngine` activates (section 6).
7. `SyncLifecycleObserver` attaches listeners.

The reverse flow (sign-out) calls `demoteToLocal()`, which flips `hasAccount` back to false and clears `firebaseUid`. Sync detaches. Local data remains intact.

### 2.4 Existing AuthRepository — Keep or Replace?

**Keep it.** `AuthRepository` is a Firebase-specific interface for *authentication operations* (sign in, sign up, link providers). It is not used for auth *state*. The existing 16 methods remain valid and are only called when the user explicitly performs auth actions. No abstraction layer needed here — just ensure it is only accessed when the user has chosen to sign in.

The change: `AuthRepository` is no longer injected into guards or lifecycle observers. Only the account-creation and settings screens use it.

---

## 3. AuthGuard Redesign

### 3.1 Current Problem

```dart
// HANGS if Firebase unreachable:
final user = await _firebaseAuth.authStateChanges().first;
```

### 3.2 New Design: Replace AuthGuard with LocalAuthGuard

```dart
class LocalAuthGuard extends AutoRouteGuard {
  LocalAuthGuard({required Ref ref}) : _ref = ref;
  final Ref _ref;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final authState = _ref.read(authStateNotifierProvider);

    // Any auth state (local or cloud) is sufficient to proceed
    if (authState is LocalAuthState || authState is CloudAuthState) {
      resolver.next();
    } else {
      // Only reach here if no local profile exists (first launch before onboarding)
      unawaited(router.replace(const AppIntroRoute()));
      resolver.next(false);
    }
  }
}
```

**Key properties:**
- Zero network calls. Synchronous read from Riverpod state.
- Never hangs. The `authStateNotifierProvider` always resolves synchronously from the DB/SharedPreferences bootstrap.
- No Firebase dependency. Does not import `firebase_auth`.

### 3.3 Route Guard Updates

All routes currently guarded by `authGuard` switch to `localAuthGuard`. The semantic meaning changes from "has a Firebase account" to "has completed onboarding (has a local profile)."

In `AppRouter`:
```dart
// Before:
guards: [authGuard, restoreGuard, profileGuard],

// After:
guards: [localAuthGuard, restoreGuard, profileGuard],
```

The `restoreGuard` and `profileGuard` remain unchanged — they check local DB state, not Firebase.

### 3.4 Where Firebase Auth Checks Remain

Only in:
- `SyncEngine` / `SyncLifecycleObserver` — checks `hasCloudAccount` before activating.
- Account management screens in Settings (change password, link providers, delete account).
- `DeviceRestoreScreen` — requires Firebase to pull from Firestore.

---

## 4. Startup Sequence Redesign

### 4.1 Current Startup (Blocking)

```
1. WidgetsFlutterBinding.ensureInitialized()          ~50ms
2. Firebase.initializeApp()                            ~200ms (can hang offline)
3. GoogleSignIn.instance.initialize()                  ~100ms (CRASHES offline)
4. Logger init                                         ~10ms
5. ProviderContainer creation                          ~5ms
6. NotificationInitializer.initialize()                ~150ms
7. runApp()                                            ~50ms
                                              TOTAL:   ~565ms best-case
                                                       INFINITE worst-case (offline)
```

### 4.2 New Startup (Non-Blocking)

```
1. WidgetsFlutterBinding.ensureInitialized()          ~50ms
2. SharedPreferences.getInstance()                     ~20ms  (for local UID)
3. Ensure local UID exists (generate if first launch)  ~5ms
4. Logger init                                         ~10ms
5. ProviderContainer creation                          ~5ms
6. runApp()                                            ~50ms
                                              TOTAL:   ~140ms  (GUARANTEED, no network)

--- After first frame (background, non-blocking) ---
7. Firebase.initializeApp()                            try/catch, fire-and-forget
8. NotificationInitializer.initialize()                try/catch, fire-and-forget
```

### 4.3 Firebase Deferred Initialization

```dart
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Bootstrap local identity (instant, no network)
    final prefs = await SharedPreferences.getInstance();
    var localUid = prefs.getString('local_device_uid');
    if (localUid == null) {
      localUid = const Uuid().v4();
      await prefs.setString('local_device_uid', localUid);
    }

    final talker = AppLogger.init();
    AppLogger.setupFlutterErrorHandlers();
    talker.info('App starting (local UID: ${localUid.substring(0, 8)}...)');

    final container = ProviderContainer(observers: [...]);

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const LearningTrackerApp(),
      ),
    );

    // 2. Deferred Firebase init (background, non-blocking)
    _initFirebaseInBackground(talker, container);

    // 3. Deferred notification init (background, non-blocking)
    _initNotificationsInBackground(talker, container);
  }, ...);
}

Future<void> _initFirebaseInBackground(Talker talker, ProviderContainer container) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    talker.info('Firebase initialized (background)');

    // If user has an account and Firebase restored auth, promote state
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      container.read(authStateNotifierProvider.notifier)
        .promoteToCloud(currentUser);
    }
  } on FirebaseException catch (_) {
    // Already initialized (hot restart) — OK
  } catch (e, stack) {
    talker.warning('Firebase init failed (non-fatal, offline mode active)', e, stack);
  }
}
```

### 4.4 GoogleSignIn — Fully Deferred

`GoogleSignIn.instance.initialize()` moves out of `main()` entirely. It is called **on-demand**, the first time the user taps "Sign in with Google":

```dart
Future<UserCredential> signInWithGoogle() async {
  // Lazy init — only when user actively chooses Google
  await GoogleSignIn.instance.initialize();
  final googleUser = await _googleSignIn.authenticate();
  ...
}
```

Wrap in try/catch. If it fails (no network), show a user-facing error: "Google Sign-In requires an internet connection."

### 4.5 Time to Usable App

| Metric | Before | After |
|--------|--------|-------|
| Time to first frame | ~565ms+ | ~140ms |
| Offline first launch | CRASH | Works perfectly |
| Time to interactive (dashboard) | ~1s+ (after auth) | ~300ms |

---

## 5. UID Migration (Local to Firebase)

### 5.1 When It Happens

The user has been using the app for days/weeks with a local UUID. They go to Settings > Create Account and sign up with email or Google. The migration runs immediately after successful Firebase auth.

### 5.2 What Changes

The `UserProfiles` row is updated:
- `firebaseUid` is set to the Firebase UID.
- `hasAccount` is set to `true`.
- `localUid` is **unchanged** (it remains the stable local identifier forever).

**No other table needs UID migration.** Here is why:

### 5.3 Table Audit — UID/AccountId References

| Table | FK Column | References | Migration Needed? |
|-------|-----------|------------|-------------------|
| `UserProfiles` | `localUid`, `firebaseUid` | (self) | YES — set `firebaseUid`, `hasAccount` |
| `Profiles` | `accountId` | `UserProfiles.id` (integer PK) | NO — integer PK is stable |
| `Completions` | `profileId` | `Profiles.id` | NO |
| `Bookmarks` | `profileId` | `Profiles.id` | NO |
| `Streaks` | `profileId` | `Profiles.id` | NO |
| `Goals` | `profileId` | `Profiles.id` | NO |
| `Rewards` | `profileId` | `Profiles.id` | NO |
| `ActiveCurricula` | `profileId` | `Profiles.id` | NO |
| `CurriculumScopes` | `profileId` | `Profiles.id` | NO |
| `CurriculumTracks` | `profileId` | `Profiles.id` | NO |
| `StageDefinitions` | `profileId` | `Profiles.id` | NO |
| `PointConfigs` | `profileId` | `Profiles.id` | NO |
| `StudyDayConfigs` | `profileId` | `Profiles.id` | NO |
| `LearningOrder` | `profileId` | `Profiles.id` | NO |
| `LearningLedger` | `profileId` | `Profiles.id` | NO |
| `ProfilePrograms` | `profileId` | `Profiles.id` | NO |
| `RewardPools` | `profileId` | `Profiles.id` | NO |
| `RewardPoolItems` | (pool FK) | `RewardPools.id` | NO |
| `TestScores` | `profileId` | `Profiles.id` | NO |
| `SyncQueue` | (none) | payload contains operation data | NO (payload uses profileId integers) |

**The entire schema chains through integer PKs, not UIDs.** The only place `firebaseUid` appears as a column is `UserProfiles`. This makes the migration trivially simple.

### 5.4 Migration Transaction

```dart
Future<void> migrateToCloudAccount(String firebaseUid) async {
  await _database.transaction(() async {
    final localUid = _prefs.getString('local_device_uid')!;
    final userProfile = await _database.userProfileDao
        .getUserProfileByLocalUid(localUid);

    if (userProfile == null) {
      throw StateError('No local profile found for migration');
    }

    // Single row update — atomic by definition
    await _database.userProfileDao.linkFirebaseAccount(
      id: userProfile.id,
      firebaseUid: firebaseUid,
    );
  });
}
```

The transaction scope is a single UPDATE on one row. Atomicity is trivially guaranteed.

### 5.5 Post-Migration: Initial Sync Push

After migration completes, the app must push all local data to Firestore for the first time:

1. `SyncEngine.initialize()` is called (or re-initialized).
2. `pullOnLaunch()` runs — empty remote, no changes pulled.
3. All local data (completions, bookmarks, streaks, goals, etc.) is pushed to Firestore under `users/{firebaseUid}/profiles/{profileId}/...`.
4. This is effectively a "first sync" and may take a few seconds for large datasets.

Design note: The existing `OfflineQueue` mechanism can handle this. Queue a "full sync" operation that iterates each collection and pushes. Alternatively, treat it as a special `pushAllOnFirstLink()` method on `SyncEngine`.

---

## 6. SyncEngine Conditional Activation

### 6.1 Current Behavior

`SyncEngine` is always created and always calls `initialize()` (which calls `pullOnLaunch()`, which calls Firestore). `SyncLifecycleObserver` attaches listeners if `FirebaseAuth.instance.currentUser != null`.

### 6.2 New Behavior: Dormant by Default

**SyncEngine creation becomes conditional:**

```dart
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final authState = ref.watch(authStateNotifierProvider);

  // No cloud account → no sync engine
  if (!authState.hasCloudAccount) return null;

  // Cloud account but Firebase not ready → no sync engine yet
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) return null;

  // Create and initialize
  final engine = SyncEngine(...);
  engine.initialize().catchError((...) { ... });
  ref.onDispose(() => engine.dispose());
  return engine;
});
```

**Return type changes to `SyncEngine?`.** All consumers must null-check.

### 6.3 SyncLifecycleObserver Changes

```dart
class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = ref.read(syncEngineProvider);
      engine?.attachListeners();  // null-safe — no-op if no engine
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return;  // Local-only user, nothing to do

    switch (state) {
      case AppLifecycleState.resumed:
        engine.attachListeners();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.detachListeners();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }
}
```

**Key removal:** No more `FirebaseAuth.instance.currentUser` checks in the widget. The engine's existence (or non-existence) is the single gating mechanism.

### 6.4 Offline Queue for Local-Only Users

**Decision: Disabled (no-op).**

The offline queue only makes sense when there is a Firestore destination. For local-only users:
- Local writes go directly to SQLite (as they do today).
- No queue entries are created.
- When the user later creates an account, the "first sync push" (section 5.5) handles uploading all existing data.

This is simpler than queuing operations that may not be flushed for weeks. The queue would grow unboundedly and the payloads might become stale.

### 6.5 Activation on Account Creation

When `promoteToCloud()` is called:
1. `authStateNotifierProvider` emits `CloudAuthState`.
2. `syncEngineProvider` rebuilds (it watches `authStateNotifierProvider`).
3. New `SyncEngine` is created with valid Firebase credentials.
4. `initialize()` runs, which calls `pullOnLaunch()` (empty remote on first link).
5. `pushAllOnFirstLink()` pushes all local data.
6. `SyncLifecycleObserver` picks up the new engine on the next frame and attaches listeners.

---

## 7. Onboarding Changes

### 7.1 Current Flow

```
AppIntro (4 pages) → Welcome → AccountCreation → ModeSelection → Onboarding
                              ↘ SignIn ↗
```

The `Welcome` screen has two CTAs: "Get Started" (→ AccountCreation) and "Already have an account? Sign in". Account creation is mandatory before any app usage.

### 7.2 New Flow

```
AppIntro (4 pages) → Onboarding (local profile)
                         ↓
                     Dashboard
```

The `Welcome` and `AccountCreation` screens are **removed from the onboarding flow**. They become accessible only from Settings > Account.

**Detailed new onboarding flow:**

1. **AppIntro** — unchanged (4 marketing pages).
2. Last page "Get Started" navigates directly to `OnboardingScreen`.
3. **OnboardingScreen Phase 1: Profile Creation** — creates a `UserProfiles` row with `localUid`, `firebaseUid = null`, `hasAccount = false`. Creates a `Profiles` row linked to it.
4. **OnboardingScreen Phase 2: Language Selection** — unchanged.
5. **OnboardingScreen Phase 3+: AddTrackFlow** — unchanged.
6. **Done** — navigate to Dashboard.

### 7.3 Onboarding Code Changes

In `_createProfile()` (onboarding_screen.dart):

**Current code (Firebase-dependent):**
```dart
final user = ref.read(firebaseAuthProvider).currentUser;
if (user != null) {
  final profileService = ref.read(userProfileServiceProvider);
  await profileService.setUserMode(
    firebaseUid: user.uid,
    displayName: name,
    mode: _profileMode == 'child' ? UserMode.child : UserMode.adult,
  );
}
```

**New code (local-only):**
```dart
final localUid = ref.read(localUidProvider);  // reads from SharedPreferences
final profileService = ref.read(userProfileServiceProvider);
await profileService.setUserMode(
  localUid: localUid,
  displayName: name,
  mode: _profileMode == 'child' ? UserMode.child : UserMode.adult,
);
```

The `UserProfileService.setUserMode` method changes signature: accepts `localUid` instead of `firebaseUid`. The Firestore push becomes conditional on `hasCloudAccount`.

### 7.4 Where "Create Account" Moves

**Settings screen**, new section:

```
Account
  ├── [No Account] → "Create Account" button → AccountCreation screen
  ├── [Has Account] → Email: user@example.com
  │                    Linked: Google, Email
  │                    → Sign Out
  │                    → Delete Account
```

The `AccountCreationScreen` and `SignInScreen` continue to exist as screens. They are just no longer part of the onboarding flow. They are navigated to from Settings.

### 7.5 AppIntro Last-Page Navigation Change

In `app_intro_screen.dart`, the `_nextPage()` method:

**Current:** navigates to `WelcomeRoute`.
**New:** navigates to `OnboardingRoute`.

```dart
void _nextPage() {
  if (_currentPage < _pages.length - 1) {
    _pageController.nextPage(...);
  } else {
    context.router.replace(const OnboardingRoute());  // Changed from WelcomeRoute
  }
}

void _skip() {
  context.router.replace(const OnboardingRoute());  // Changed from WelcomeRoute
}
```

### 7.6 Routes to Unguard

The `OnboardingRoute`, `AccountCreationRoute`, and `WelcomeRoute` are already unguarded. No route changes needed for the onboarding flow itself.

The `ModeSelectionRoute` is also unguarded and currently sets the user mode via Firebase UID. It needs the same local-UID refactor as onboarding, or it can be folded into the onboarding profile-creation step (the adult/child segmented button already exists there).

---

## 8. ConnectivityService Improvements

### 8.1 Current Implementation

```dart
Future<bool> get isOnline async {
  try {
    final result = await InternetAddress.lookup('dns.google')
        .timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  }
}
```

**Problems:**
- 5-second timeout is too long. On airplane mode, every connectivity check blocks for 5 seconds.
- No caching. Every call repeats the DNS lookup.
- No platform connectivity check. The OS knows instantly if WiFi/cellular is connected.

### 8.2 New Design: Tiered Connectivity Check

```dart
class ConnectivityService {
  ConnectivityService({ConnectivityPlus? connectivity})
    : _connectivity = connectivity ?? ConnectivityPlus();

  final ConnectivityPlus _connectivity;

  // Cache
  bool? _lastKnownState;
  DateTime? _lastCheckTime;
  static const _cacheDuration = Duration(seconds: 30);

  StreamSubscription? _connectivitySubscription;

  /// Initialize platform connectivity listener.
  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen((result) {
      if (result == ConnectivityResult.none) {
        _lastKnownState = false;
        _lastCheckTime = DateTime.now();
      } else {
        // Platform says connected — but need DNS verification
        _lastKnownState = null;  // invalidate cache, force re-check
      }
    });
  }

  Future<bool> get isOnline async {
    // Tier 0: Cache hit (within 30 seconds)
    if (_lastKnownState != null && _lastCheckTime != null) {
      final age = DateTime.now().difference(_lastCheckTime!);
      if (age < _cacheDuration) return _lastKnownState!;
    }

    // Tier 1: Platform check (instant, <1ms)
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _lastKnownState = false;
      _lastCheckTime = DateTime.now();
      return false;
    }

    // Tier 2: DNS probe (only if platform says connected)
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 2));  // Reduced from 5s
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _lastKnownState = online;
      _lastCheckTime = DateTime.now();
      return online;
    } on SocketException {
      _lastKnownState = false;
      _lastCheckTime = DateTime.now();
      return false;
    } on TimeoutException {
      _lastKnownState = false;
      _lastCheckTime = DateTime.now();
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
```

### 8.3 Key Improvements

| Aspect | Before | After |
|--------|--------|-------|
| Airplane mode check | 5 seconds | <1ms (platform) |
| WiFi-no-internet check | 5 seconds | 2 seconds (reduced timeout) |
| Repeated checks (30s window) | 5 seconds each | 0ms (cache) |
| Network change detection | Polling only | Push via platform stream |

### 8.4 Dependency

Requires adding `connectivity_plus` to `pubspec.yaml`. This is a well-maintained Flutter Favorite package. The comment in `SyncEngine.setOnlineState()` already anticipates this:

> *"When `connectivity_plus` is added to pubspec.yaml, replace the DNS probe with its stream for instant network-change events."*

### 8.5 Fallback

If `connectivity_plus` is not desirable (e.g., plugin size concerns), the tiered approach still works with just the cache + reduced timeout:

```dart
// Without connectivity_plus, just cache + shorter timeout:
Future<bool> get isOnline async {
  if (_cachedAndFresh) return _lastKnownState!;

  try {
    final result = await InternetAddress.lookup('dns.google')
        .timeout(const Duration(seconds: 2));  // 2s instead of 5s
    ...
  }
}
```

This alone reduces worst-case from 5s to 2s and eliminates repeated checks within the cache window.

---

## Implementation Order

Recommended sequencing to minimize risk and allow incremental testing:

| Phase | Stories | Risk | Dependencies |
|-------|---------|------|--------------|
| **Phase 1** | DB migration (add `localUid`, nullable `firebaseUid`, `hasAccount`) | Low | None |
| **Phase 2** | `AuthStateNotifier` + `LocalAuthGuard` | Medium | Phase 1 |
| **Phase 3** | Startup sequence (defer Firebase, remove GoogleSignIn.initialize) | Medium | Phase 2 |
| **Phase 4** | Onboarding refactor (remove account creation step) | Low | Phase 2 |
| **Phase 5** | SyncEngine conditional activation | Medium | Phase 2 |
| **Phase 6** | UID migration + "Create Account" in Settings | Medium | Phase 1, 5 |
| **Phase 7** | ConnectivityService improvements | Low | None (independent) |

Phase 7 (ConnectivityService) can run in parallel with any other phase.

---

## Trade-offs and Alternatives Considered

### Why not Anonymous Firebase Auth?

Firebase supports anonymous authentication (`signInAnonymously()`), which would give a Firebase UID without requiring credentials. This was rejected because:

1. **Still requires network on first launch.** Anonymous auth calls Firebase servers. If offline, it fails — defeating the purpose.
2. **Quota and billing.** Anonymous accounts count toward Firebase Auth limits.
3. **Conversion complexity.** Converting anonymous to permanent accounts requires `linkWithCredential`, which has known edge cases around account collisions.
4. **Unnecessary dependency.** The app does not need a Firebase UID until sync is desired. A local UUID is simpler.

### Why not use a single UID field?

Could have made `firebaseUid` the single identifier and just populated it with a local UUID initially, then swapped it on account creation. Rejected because:

1. **Risky swap.** Changing the value of a UNIQUE column that may be referenced elsewhere is dangerous.
2. **Loss of provenance.** Cannot tell from the DB whether the UID is local or Firebase-originated.
3. **Firestore path confusion.** If the local UUID were used as a Firestore path temporarily, data would be orphaned after migration.

Two separate columns (`localUid` for local, `firebaseUid` for cloud) is clearer and safer.

### Why `hasAccount` instead of just checking `firebaseUid != null`?

A denormalized boolean is:
1. Faster to query (no null comparison).
2. More explicit in intent — `hasAccount` communicates meaning; `firebaseUid != null` requires reasoning about what it implies.
3. Easier to mock/test.

The trade-off is keeping it in sync, but it only changes in two places (`promoteToCloud` and `demoteToLocal`), both inside the same service.

---

## Open Questions

1. **Multi-device before account creation.** If the user installs on a second device before creating an account, each device gets a unique `localUid`. When they eventually create an account and sign in on both devices, data from device B's local UID is not automatically linked. The migration only covers the device where the account is created. Device B would need a "merge" flow or a fresh sync pull. This is an edge case but worth documenting.

2. **App uninstall/reinstall.** SharedPreferences and SQLite are cleared on uninstall. The local UUID is lost. If the user had no account, all data is lost. This is acceptable (and matches user expectations), but the UI should clearly communicate "Create an account to back up your data" in Settings.

3. **`completions_history` screen** and similar screens that read from `UserProfiles.firebaseUid` — need an audit pass to ensure they use `localUid` or the Riverpod auth state instead of direct DB reads of `firebaseUid`.
