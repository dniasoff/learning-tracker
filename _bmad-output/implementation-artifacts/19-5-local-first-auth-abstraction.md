# Story 19.5: Local-First Auth Abstraction Layer

Status: ready-for-dev

## Story

As a learner,
I want the app to work immediately from first launch with no account or internet required,
so that I can start tracking my learning instantly on any device, anywhere.

## Acceptance Criteria

**AC-1: Local profile on first launch**
**Given** the user launches the app for the first time with no internet
**When** the app starts
**Then** a local UUID is generated and stored in SharedPreferences
**And** the app reaches the onboarding screen within 300ms (no network calls in startup path)

**AC-2: Onboarding without Firebase**
**Given** the user is in the onboarding flow
**When** they create a profile (name + adult/child mode)
**Then** a `UserProfiles` row is created with `localUid` set, `firebaseUid = null`, `hasAccount = false`
**And** a `Profiles` row is linked to it via integer PK
**And** no Firebase calls are made

**AC-3: AuthGuard never blocks on network**
**Given** the user has completed onboarding (has a local profile)
**When** they navigate to any protected route
**Then** the `LocalAuthGuard` allows navigation synchronously (zero awaits, zero network calls)

**AC-4: AuthGuard redirects pre-onboarding**
**Given** the user has NOT completed onboarding (no local profile)
**When** they attempt to navigate to a protected route
**Then** they are redirected to `AppIntroRoute`

**AC-5: Firebase deferred to background**
**Given** the app is starting up
**When** `main()` runs
**Then** `Firebase.initializeApp()` runs AFTER `runApp()` in a background task
**And** `GoogleSignIn.instance.initialize()` is NOT called at startup at all

**AC-6: Sealed AppAuthState always resolves**
**Given** the `authStateNotifierProvider` is read
**When** the app is in any state (first launch, local-only, cloud-linked)
**Then** it returns a non-null `AppAuthState` synchronously (either `LocalAuthState` or `CloudAuthState`)
**And** no network call is made during resolution

**AC-7: SyncEngine dormant for local-only users**
**Given** the user has no cloud account (`hasAccount = false`)
**When** the app is running
**Then** `syncEngineProvider` returns `null`
**And** no Firestore calls are made
**And** `SyncLifecycleObserver` is a no-op

**AC-8: DB schema migration preserves existing data**
**Given** an existing user with data in `UserProfiles` (firebaseUid populated)
**When** the app upgrades to the new schema version
**Then** `localUid` is populated (copied from `firebaseUid` for existing users)
**And** `hasAccount` is set to `true`
**And** `firebaseUid` remains intact
**And** all FK references through integer PKs are unaffected

## Tasks / Subtasks

### T1: UserProfiles Schema Migration (AC: 8)

Add three columns to `UserProfiles` and run a data migration for existing rows.

- [ ] Edit `lib/core/database/tables/user_profiles.dart`:

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

- [ ] Bump schema version in `app_database.dart` and add migration step:
  1. Add column `localUid TEXT NOT NULL DEFAULT ''`
  2. Alter `firebaseUid` to nullable
  3. Add column `hasAccount BOOLEAN NOT NULL DEFAULT 0`
  4. Data migration: for each row where `firebaseUid` is non-empty, copy `firebaseUid` into `localUid` and set `hasAccount = 1`
  5. For any row where `localUid` is still `''` (should not happen), generate a fresh UUID

- [ ] Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Drift code

- [ ] Add `UserProfileDao.getUserProfileByLocalUid(String localUid)` method:
  ```dart
  Future<UserProfile?> getUserProfileByLocalUid(String localUid) =>
      (select(userProfiles)..where((t) => t.localUid.equals(localUid)))
          .getSingleOrNull();
  ```

- [ ] Add `UserProfileDao.linkFirebaseAccount({required int id, required String firebaseUid})`:
  ```dart
  Future<void> linkFirebaseAccount({
    required int id,
    required String firebaseUid,
  }) async {
    await (update(userProfiles)..where((t) => t.id.equals(id))).write(
      UserProfilesCompanion(
        firebaseUid: Value(firebaseUid),
        hasAccount: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  ```

- [ ] Update `UserProfileDao.upsertProfile` to accept `localUid` parameter and use it for the insert path. The existing `firebaseUid`-based lookup remains for sync/pull operations.

- [ ] Write migration test: create DB at old schema version, insert a row with `firebaseUid = 'firebase-abc'`, run migration, assert `localUid == 'firebase-abc'` and `hasAccount == true` and `firebaseUid == 'firebase-abc'`

### T2: Local UUID Bootstrap (AC: 1)

Generate a stable v4 UUID on first launch, stored in SharedPreferences.

- [ ] Create `lib/core/services/local_identity_service.dart`:
  ```dart
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:uuid/uuid.dart';

  const kLocalDeviceUid = 'local_device_uid';

  class LocalIdentityService {
    LocalIdentityService(this._prefs);

    final SharedPreferences _prefs;

    /// Returns the stable local UUID, generating one on first call.
    String ensureLocalUid() {
      var uid = _prefs.getString(kLocalDeviceUid);
      if (uid == null) {
        uid = const Uuid().v4();
        _prefs.setString(kLocalDeviceUid, uid);
      }
      return uid;
    }

    String? get localUid => _prefs.getString(kLocalDeviceUid);
  }
  ```

- [ ] Create `localUidProvider` (keepAlive Riverpod provider) that reads from SharedPreferences:
  ```dart
  @Riverpod(keepAlive: true)
  String localUid(Ref ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final uid = prefs.getString(kLocalDeviceUid);
    if (uid == null) {
      throw StateError('Local UID not initialized — call ensureLocalUid() in main()');
    }
    return uid;
  }
  ```

- [ ] Verify `uuid` package is available (it is a transitive dep via Drift). If not in direct deps, add to `pubspec.yaml`.

- [ ] Write unit test: first call generates UUID, second call returns same value, value survives SharedPreferences round-trip

### T3: AppAuthState Sealed Class + AuthStateNotifier (AC: 6)

Create the app-owned auth state model that replaces raw `Stream<User?>`.

- [ ] Create `lib/features/auth/domain/models/app_auth_state.dart`:
  ```dart
  sealed class AppAuthState {
    String get displayUid;
    String get displayName;
    bool get hasCloudAccount;
    String? get firebaseUid;
  }

  class LocalAuthState implements AppAuthState {
    const LocalAuthState({
      required this.localUid,
      required this.displayName,
    });

    final String localUid;
    @override final String displayName;

    @override String get displayUid => localUid;
    @override bool get hasCloudAccount => false;
    @override String? get firebaseUid => null;
  }

  class CloudAuthState implements AppAuthState {
    const CloudAuthState({
      required this.localUid,
      required this.firebaseUid,
      required this.displayName,
      required this.email,
      this.providers = const [],
    });

    final String localUid;
    @override final String firebaseUid;
    @override final String displayName;
    final String email;
    final List<String> providers;

    @override String get displayUid => localUid;
    @override bool get hasCloudAccount => true;
  }
  ```

- [ ] Create `lib/features/auth/presentation/providers/auth_state_provider.dart`:
  ```dart
  @Riverpod(keepAlive: true)
  class AuthStateNotifier extends _$AuthStateNotifier {
    @override
    AppAuthState build() {
      return _resolveInitialState();
    }

    AppAuthState _resolveInitialState() {
      final localUid = ref.read(localUidProvider);
      final db = ref.read(appDatabaseProvider);

      // Synchronous bootstrap: read from SharedPreferences (local UID is always available)
      // DB query is async but we use a FutureProvider pattern or pre-loaded state
      // For initial build, return LocalAuthState — upgrade to Cloud async if applicable
      return LocalAuthState(localUid: localUid, displayName: '');
    }

    /// Called after DB loads to set the full state (display name, cloud status).
    void resolveFromProfile(UserProfile profile) {
      if (profile.hasAccount && profile.firebaseUid != null) {
        // Check if Firebase restored auth (synchronous property, no network)
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          state = CloudAuthState(
            localUid: profile.localUid,
            firebaseUid: profile.firebaseUid!,
            displayName: profile.displayName,
            email: firebaseUser.email ?? '',
            providers: firebaseUser.providerData
                .map((p) => p.providerId)
                .toList(),
          );
          return;
        }
      }
      state = LocalAuthState(
        localUid: profile.localUid,
        displayName: profile.displayName,
      );
    }

    /// Called when user creates/links a Firebase account.
    void promoteToCloud(User firebaseUser, UserProfile updatedProfile) {
      state = CloudAuthState(
        localUid: updatedProfile.localUid,
        firebaseUid: firebaseUser.uid,
        displayName: updatedProfile.displayName,
        email: firebaseUser.email ?? '',
        providers: firebaseUser.providerData
            .map((p) => p.providerId)
            .toList(),
      );
    }

    /// Called on sign-out.
    void demoteToLocal() {
      final current = state;
      state = LocalAuthState(
        localUid: current.displayUid,
        displayName: current.displayName,
      );
    }
  }
  ```

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`

- [ ] Write unit tests:
  - Initial state is `LocalAuthState` with correct `localUid`
  - `resolveFromProfile` with `hasAccount = true` + Firebase currentUser non-null -> `CloudAuthState`
  - `resolveFromProfile` with `hasAccount = true` + Firebase currentUser null -> `LocalAuthState` (offline)
  - `resolveFromProfile` with `hasAccount = false` -> `LocalAuthState`
  - `promoteToCloud` transitions from `LocalAuthState` to `CloudAuthState`
  - `demoteToLocal` transitions from `CloudAuthState` to `LocalAuthState`

### T4: LocalAuthGuard — Replace AuthGuard (AC: 3, 4)

Replace the Firebase-dependent `AuthGuard` with a synchronous local-only guard.

- [ ] Create `lib/core/navigation/guards/local_auth_guard.dart`:
  ```dart
  import 'dart:async';

  import 'package:auto_route/auto_route.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:learning_tracker/core/navigation/app_router.dart';
  import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';

  /// Route guard that checks for a local profile (no network required).
  ///
  /// Any auth state (local or cloud) is sufficient to proceed.
  /// Only redirects to AppIntro if no profile exists (pre-onboarding).
  class LocalAuthGuard extends AutoRouteGuard {
    LocalAuthGuard({required Ref ref}) : _ref = ref;
    final Ref _ref;

    @override
    void onNavigation(NavigationResolver resolver, StackRouter router) {
      final authState = _ref.read(authStateNotifierProvider);

      // Any valid state means the user has a profile — let them through
      if (authState.displayUid.isNotEmpty) {
        resolver.next();
      } else {
        // No local profile yet — redirect to onboarding
        unawaited(router.replace(const AppIntroRoute()));
        resolver.next(false);
      }
    }
  }
  ```

  **Key difference from current `AuthGuard`:**
  - Current: `await _firebaseAuth.authStateChanges().first` — async, hangs offline
  - New: `_ref.read(authStateNotifierProvider)` — synchronous, zero network

- [ ] Update `lib/core/navigation/app_router.dart`:
  - Change constructor parameter from `AuthGuard authGuard` to `LocalAuthGuard localAuthGuard`
  - Replace all `guards: [authGuard, ...]` with `guards: [localAuthGuard, ...]`
  - There are **30+ routes** currently guarded by `authGuard` that all switch to `localAuthGuard`
  - The semantic meaning changes from "has Firebase account" to "has completed onboarding"

- [ ] Update `lib/core/navigation/router_provider.dart`:

  **Current:**
  ```dart
  authGuard: AuthGuard(firebaseAuth: FirebaseAuth.instance),
  ```

  **New:**
  ```dart
  localAuthGuard: LocalAuthGuard(ref: ref),
  ```

  This removes the `FirebaseAuth` import from `router_provider.dart`.

- [ ] Verify `auth_guard.dart` is no longer imported anywhere. Do NOT delete the file yet (keep for reference during migration), but remove all imports.

- [ ] Write unit test:
  - Guard with valid `LocalAuthState` -> `resolver.next()` called
  - Guard with valid `CloudAuthState` -> `resolver.next()` called
  - Guard with empty displayUid (no profile) -> redirected to `AppIntroRoute`
  - Guard never awaits, never calls Firebase

### T5: Startup Sequence Redesign (AC: 1, 5)

Defer Firebase and GoogleSignIn out of the critical startup path.

- [ ] Rewrite `lib/main.dart`:

  **Current blocking sequence (lines 23-33):**
  ```dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize();
  ```

  **New non-blocking sequence:**
  ```dart
  void main() {
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Bootstrap local identity (instant, no network)
      final prefs = await SharedPreferences.getInstance();
      final identityService = LocalIdentityService(prefs);
      final localUid = identityService.ensureLocalUid();

      final talker = AppLogger.init();
      AppLogger.setupFlutterErrorHandlers();
      talker.info('App starting (local UID: ${localUid.substring(0, 8)}...)');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        observers: [...],
      );

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
    }, (error, stack) {
      AppLogger.instance.handle(error, stack);
    });
  }
  ```

- [ ] Create `_initFirebaseInBackground()`:
  ```dart
  Future<void> _initFirebaseInBackground(
    Talker talker,
    ProviderContainer container,
  ) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      talker.info('Firebase initialized (background)');

      // If user has an account and Firebase restored auth, promote state
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final db = container.read(appDatabaseProvider);
        final localUid = container.read(localUidProvider);
        final profile = await db.userProfileDao.getUserProfileByLocalUid(localUid);
        if (profile != null && profile.hasAccount) {
          container.read(authStateNotifierProvider.notifier)
              .promoteToCloud(currentUser, profile);
        }
      }
    } on FirebaseException catch (_) {
      // Already initialized (hot restart)
    } catch (e, stack) {
      talker.warning('Firebase init failed (non-fatal, offline mode active)', e, stack);
    }
  }
  ```

- [ ] Remove `GoogleSignIn.instance.initialize()` from `main()` entirely. Move to lazy init inside `AuthRepositoryImpl.signInWithGoogle()`:
  ```dart
  @override
  Future<UserCredential> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(); // Lazy init — only when user taps Google Sign-In
    final googleUser = await _googleSignIn.authenticate();
    ...
  }
  ```
  Also add lazy init to `reauthenticateWithGoogle()` and `linkGoogleProvider()` in `AuthRepositoryImpl`.

- [ ] Create `_initNotificationsInBackground()` — move existing notification init from pre-`runApp` to post-`runApp`, wrapped in try/catch (same logic, just deferred).

- [ ] Write integration test: app starts with no Firebase, SharedPreferences is populated, local UID exists

### T6: UserProfileService Refactor — Local-First Profile Creation (AC: 2)

Change `UserProfileService.setUserMode` to accept `localUid` instead of requiring `firebaseUid`.

- [ ] Update `lib/features/onboarding/domain/services/user_profile_service.dart`:

  **Current signature:**
  ```dart
  Future<void> setUserMode({
    required String firebaseUid,
    required String displayName,
    required UserMode mode,
  })
  ```

  **New signature:**
  ```dart
  Future<void> setUserMode({
    required String localUid,
    String? firebaseUid,
    required String displayName,
    required UserMode mode,
  })
  ```

  The Firestore push becomes conditional:
  ```dart
  // Write to Firestore only if user has a cloud account
  if (firebaseUid != null) {
    try {
      await _pushUserProfile(
        firebaseUid: firebaseUid,
        displayName: displayName,
        userMode: modeString,
      );
    } catch (e, stack) { ... }
  }
  ```

- [ ] Update `UserProfileDao.upsertProfile` to support local-UID-based inserts:
  ```dart
  Future<void> upsertProfile({
    required String localUid,
    String? firebaseUid,
    required String displayName,
    required String userMode,
    required DateTime updatedAt,
  }) async {
    final existing = await getUserProfileByLocalUid(localUid);

    if (existing == null) {
      await insertUserProfile(
        UserProfilesCompanion.insert(
          localUid: localUid,
          firebaseUid: Value(firebaseUid),
          displayName: displayName,
          userMode: userMode,
          hasAccount: Value(firebaseUid != null),
          createdAt: updatedAt,
          updatedAt: updatedAt,
        ),
      );
    } else if (updatedAt.isAfter(existing.updatedAt)) {
      await (update(userProfiles)..where((t) => t.id.equals(existing.id)))
          .write(UserProfilesCompanion(
        displayName: Value(displayName),
        userMode: Value(userMode),
        updatedAt: Value(updatedAt),
      ));
    }
  }
  ```

- [ ] Update `getUserMode` to accept `localUid` instead of `firebaseUid`:
  ```dart
  Future<UserMode?> getUserMode(String localUid) async {
    final profile = await _userProfileDao.getUserProfileByLocalUid(localUid);
    if (profile == null) return null;
    return UserMode.values.where((m) => m.name == profile.userMode).firstOrNull;
  }
  ```

- [ ] Update all callers of `setUserMode` and `getUserMode`:
  - `onboarding_screen.dart` `_createProfile()` (line ~159): replace `firebaseUid: user.uid` with `localUid: ref.read(localUidProvider)`
  - `mode_selection_screen.dart`: same pattern
  - `settings_screen.dart`: same pattern
  - `account_creation_screen.dart`: passes both `localUid` and `firebaseUid` (user just created account)

- [ ] Write unit test: `setUserMode` with `firebaseUid: null` writes to DB, skips Firestore push

### T7: Onboarding Flow — Remove Firebase Requirement (AC: 2)

Update onboarding to create profiles with local UID, remove Firebase auth dependency.

- [ ] Update `lib/features/onboarding/presentation/screens/onboarding_screen.dart` `_createProfile()`:

  **Current (lines 147-175):**
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

  **New:**
  ```dart
  final localUid = ref.read(localUidProvider);
  final profileService = ref.read(userProfileServiceProvider);
  await profileService.setUserMode(
    localUid: localUid,
    displayName: name,
    mode: _profileMode == 'child' ? UserMode.child : UserMode.adult,
  );
  ```

  Remove the `if (user != null)` guard — profile creation is now unconditional.

- [ ] Remove `import 'package:learning_tracker/core/providers/firebase_providers.dart'` from `onboarding_screen.dart` (if no other Firebase refs remain in the file).

- [ ] Update `lib/features/onboarding/presentation/screens/app_intro_screen.dart`:

  **Current (lines 111, 116):**
  ```dart
  context.router.replace(const WelcomeRoute());
  ```

  **New:**
  ```dart
  context.router.replace(const OnboardingRoute());
  ```

  Both `_nextPage()` and `_skip()` navigate directly to onboarding, bypassing `WelcomeRoute` entirely.

- [ ] Update `onboarding_providers.dart` — the `userProfileServiceProvider` currently depends on `firebaseFirestoreProvider`. Make the Firestore push optional (pass a no-op `PushUserProfile` when `hasCloudAccount` is false, or make the push callback nullable):

  **Current:**
  ```dart
  UserProfileService(
    userProfileDao: db.userProfileDao,
    pushUserProfile: createFirestorePush(firestore),
  );
  ```

  **New:** Keep the Firestore push wired in — it is already guarded by the `firebaseUid != null` check added in T6. The provider still injects it, but it is never called for local-only users.

- [ ] Write widget test: onboarding flow completes without any Firebase mocks needed

### T8: SyncEngine Conditional Activation (AC: 7)

Make `SyncEngine` dormant when user has no cloud account.

- [ ] Update `lib/features/sync/presentation/providers/sync_providers.dart`:

  **Current:**
  ```dart
  final syncEngineProvider = Provider<SyncEngine>((ref) {
    ...
    final engine = SyncEngine(...);
    engine.initialize().catchError(...);
    ...
    return engine;
  });
  ```

  **New:**
  ```dart
  final syncEngineProvider = Provider<SyncEngine?>((ref) {
    final authState = ref.watch(authStateNotifierProvider);

    // No cloud account -> no sync engine
    if (!authState.hasCloudAccount) return null;

    // Cloud account but Firebase not ready -> no sync engine yet
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    final database = ref.watch(appDatabaseProvider);
    final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
    final offlineQueue = ref.watch(offlineQueueProvider);
    final logger = ref.watch(talkerProvider);
    final connectivityService = ref.watch(connectivityServiceProvider);

    final engine = SyncEngine(
      database: database,
      firestoreDataSource: firestoreDataSource,
      offlineQueue: offlineQueue,
      logger: logger,
      connectivityService: connectivityService,
    );

    engine.initialize().catchError((Object error, StackTrace stackTrace) {});
    ref.onDispose(() => engine.dispose());

    return engine;
  });
  ```

  **Return type changes to `SyncEngine?`.** All consumers must null-check.

- [ ] Update `syncStatusStreamProvider` and `syncStatusProvider` to handle null engine:
  ```dart
  final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
    final engine = ref.watch(syncEngineProvider);
    if (engine == null) return Stream.value(SyncStatus.idle());
    return engine.statusStream;
  });
  ```

- [ ] Update `lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart`:

  **Current (line 31):**
  ```dart
  if (FirebaseAuth.instance.currentUser != null) {
    final engine = ref.read(syncEngineProvider);
    engine.attachListeners();
  }
  ```

  **New:**
  ```dart
  final engine = ref.read(syncEngineProvider);
  engine?.attachListeners();  // null-safe — no-op if no engine
  ```

  Same pattern for `didChangeAppLifecycleState`:
  ```dart
  final engine = ref.read(syncEngineProvider);
  if (engine == null) return;  // Local-only user, nothing to do
  ```

  Remove `import 'package:firebase_auth/firebase_auth.dart'` from this file.

- [ ] Audit all other consumers of `syncEngineProvider` — add null checks:
  - `sync_screen.dart`
  - `device_restore_screen.dart`
  - Any provider that reads `syncEngineProvider`

- [ ] Write unit test: `syncEngineProvider` returns null when `authState` is `LocalAuthState`
- [ ] Write unit test: `syncEngineProvider` returns `SyncEngine` when `authState` is `CloudAuthState` and Firebase user exists

### T9: Auth Providers Cleanup (AC: 6)

Wire the new auth state into the existing provider graph.

- [ ] Update `lib/features/auth/presentation/providers/auth_providers.dart`:

  Keep existing providers (`authRepositoryProvider`, `authStateProvider`) — they are still used for Firebase auth operations. Add:
  ```dart
  /// Whether the current user has a cloud account.
  /// Convenience shorthand used across the app.
  @riverpod
  bool hasCloudAccount(Ref ref) {
    return ref.watch(authStateNotifierProvider).hasCloudAccount;
  }
  ```

- [ ] Audit all files that import `firebase_providers.dart` and use `firebaseAuthProvider` for auth state checks (NOT for auth operations). These should switch to `authStateNotifierProvider`:

  | File | Current Usage | New Usage |
  |------|--------------|-----------|
  | `onboarding_screen.dart` | `ref.read(firebaseAuthProvider).currentUser` | `ref.read(localUidProvider)` |
  | `mode_selection_screen.dart` | `ref.read(firebaseAuthProvider).currentUser` | `ref.read(localUidProvider)` |
  | `settings_screen.dart` | Firebase UID for display | `ref.read(authStateNotifierProvider)` |
  | `sync_lifecycle_observer.dart` | `FirebaseAuth.instance.currentUser` | `ref.read(syncEngineProvider)` null-check |

  Files that use `firebaseAuthProvider` for **auth operations** (sign in, sign up, link) keep it:
  - `auth_repository_impl.dart` — keeps `FirebaseAuth` for actual auth calls
  - `account_creation_screen.dart` — keeps it for sign-up flow
  - `sign_in_screen.dart` — keeps it for sign-in flow

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`

### T10: Tests — Full Integration (AC: 1-8)

- [ ] Unit test: `LocalIdentityService` — generates UUID on first call, returns same on subsequent calls
- [ ] Unit test: `AppAuthState` sealed class — verify `LocalAuthState` and `CloudAuthState` properties
- [ ] Unit test: `AuthStateNotifier` — initial state, resolveFromProfile, promoteToCloud, demoteToLocal
- [ ] Unit test: `LocalAuthGuard` — allows local users, allows cloud users, redirects pre-onboarding
- [ ] Unit test: Schema migration — old data preserved correctly
- [ ] Unit test: `UserProfileService.setUserMode` with null `firebaseUid` — no Firestore call
- [ ] Unit test: `syncEngineProvider` returns null for local-only, non-null for cloud
- [ ] Widget test: Onboarding creates profile without Firebase
- [ ] Integration test: Full cold start offline — UUID generated, onboarding works, dashboard accessible

## Dev Notes

### Architecture

This is the most architecturally significant story in Epic 19. It introduces the **two-tier identity model**:
- **Tier 1 (always present):** Local UUID stored in SharedPreferences, seeded into `UserProfiles.localUid`
- **Tier 2 (opt-in):** Firebase UID stored in `UserProfiles.firebaseUid`, linked when user creates account

The sealed `AppAuthState` class is the single source of truth for auth state throughout the app. It replaces the raw `Stream<User?>` from Firebase Auth.

### Key Invariant

`authStateNotifierProvider` ALWAYS resolves synchronously. It NEVER makes a network call. It NEVER returns null. The app always has an identity.

### Why This Story Is Large

This story touches:
1. Database schema (migration)
2. Startup sequence (`main.dart`)
3. Navigation guards (all 30+ guarded routes)
4. Auth provider graph
5. Onboarding flow
6. Sync engine activation
7. Profile service

These are tightly coupled — changing one without the others leaves the app in a broken state. They must ship together as an atomic unit.

### Dependency: `uuid` Package

The `uuid` package is already a transitive dependency via Drift. Verify it is accessible. If not, add `uuid: ^4.0.0` to `pubspec.yaml` direct dependencies.

### What This Story Does NOT Cover

- **UID migration (local -> Firebase):** Covered in a separate story (19.6). This story only sets up the schema and `linkFirebaseAccount` DAO method.
- **"Create Account" in Settings UI:** Covered in a separate story. This story only ensures the infrastructure exists.
- **ConnectivityService improvements:** Independent story (19.7).
- **`pushAllOnFirstLink()` on SyncEngine:** Covered in the sync activation story.

### Key Files

| File | Action |
|------|--------|
| `lib/core/database/tables/user_profiles.dart` | Modify — add `localUid`, nullable `firebaseUid`, `hasAccount` |
| `lib/core/database/daos/user_profile_dao.dart` | Modify — add `getUserProfileByLocalUid`, `linkFirebaseAccount`, update `upsertProfile` |
| `lib/core/database/app_database.dart` | Modify — bump schema version, add migration |
| `lib/core/services/local_identity_service.dart` | **Create** — UUID generation + SharedPreferences |
| `lib/features/auth/domain/models/app_auth_state.dart` | **Create** — sealed `AppAuthState` + subtypes |
| `lib/features/auth/presentation/providers/auth_state_provider.dart` | **Create** — `AuthStateNotifier` keepAlive provider |
| `lib/features/auth/presentation/providers/auth_providers.dart` | Modify — add `hasCloudAccountProvider` |
| `lib/core/navigation/guards/local_auth_guard.dart` | **Create** — replaces `AuthGuard` |
| `lib/core/navigation/guards/auth_guard.dart` | Deprecate — no longer imported |
| `lib/core/navigation/app_router.dart` | Modify — `AuthGuard` -> `LocalAuthGuard` |
| `lib/core/navigation/router_provider.dart` | Modify — wire `LocalAuthGuard` with Ref |
| `lib/main.dart` | Modify — defer Firebase, bootstrap local UID |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Modify — lazy `GoogleSignIn.initialize()` |
| `lib/features/onboarding/domain/services/user_profile_service.dart` | Modify — accept `localUid`, conditional Firestore push |
| `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | Modify — update `userProfileServiceProvider` |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Modify — use `localUid` instead of Firebase UID |
| `lib/features/onboarding/presentation/screens/app_intro_screen.dart` | Modify — navigate to `OnboardingRoute` instead of `WelcomeRoute` |
| `lib/features/sync/presentation/providers/sync_providers.dart` | Modify — return `SyncEngine?`, gate on `hasCloudAccount` |
| `lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart` | Modify — null-check engine, remove Firebase import |

### Implementation Order

Implement tasks in this order to keep the app compilable at each step:

1. **T1** (schema migration) — purely additive, no behavior change
2. **T2** (local UUID bootstrap) — new service, no existing code changed
3. **T3** (AppAuthState + notifier) — new files, no existing code changed
4. **T6** (UserProfileService refactor) — update service signatures
5. **T4** (LocalAuthGuard) — swap guard, update router (app behavior changes here)
6. **T5** (startup redesign) — defer Firebase (critical path change)
7. **T7** (onboarding flow) — remove Firebase requirement from onboarding
8. **T8** (SyncEngine conditional) — gate sync on cloud account
9. **T9** (provider cleanup) — audit and clean up Firebase imports
10. **T10** (tests) — verify everything end-to-end

### Critical Constraints

- **No data loss on migration.** Existing users with Firebase accounts must retain all data and continue syncing after upgrade.
- **No breaking change to Firestore paths.** `localUid` is NEVER used as a Firestore path component. Firebase UID continues to be used for all Firestore operations.
- **Integer PK stability.** All FK references chain through `UserProfiles.id` (integer PK) and `Profiles.id` (integer PK). No table other than `UserProfiles` needs UID changes.
- **`GoogleSignIn.initialize()` must NOT be called at startup.** It crashes on devices without Google Play Services or when offline. Move to lazy init inside `signInWithGoogle()`.

### Testing Strategy

Mock `SharedPreferences` with `SharedPreferences.setMockInitialValues({})` for unit tests. Mock `FirebaseAuth` with a fake that returns null `currentUser` to test offline scenarios. Use the existing `test/helpers/test_database.dart` for Drift migration tests.

### Auth Transition Edge Cases (Gap Analysis 2026-03-31)

#### Edge Case 1: Existing Firebase Users (dev/testing migration)
- Migration runs on schema upgrade: copies `firebaseUid` → `localUid` for existing rows, sets `hasAccount = true`
- For any row where `localUid` is still empty after migration, generate a fresh UUID
- Must be atomic (single DB transaction)
- Test: create a UserProfile with `firebaseUid = 'abc123'`, run migration, verify `localUid = 'abc123'` and `hasAccount = true`

#### Edge Case 2: Firebase SDK Not Ready on Startup
- User has `hasAccount == true` but `FirebaseAuth.instance.currentUser` is null (token expired, SDK not initialized)
- Emit `LocalAuthState` for this session — user is "local" until Firebase re-authenticates
- SyncEngine stays dormant (Tier 0 behavior)
- On next successful Firebase auth event, promote back to `CloudAuthState`
- Test: set `hasAccount = true` in DB, mock `currentUser` to null, verify `LocalAuthState` emitted

#### Edge Case 3: Sign-Out → Sign-In with Different Account
- User signs out → `hasAccount` flips to false, `firebaseUid` cleared
- User later signs in with a DIFFERENT Firebase account
- **Strategy:** New Firebase UID is stored, but `localUid` remains stable (it's the device identity)
- All local data stays associated with `localUid` — no data loss
- Sync pushes all local data to the new Firebase account's Firestore path
- Old Firestore data under previous UID is orphaned (acceptable — user chose to switch)
- Test: sign out, sign in with different UID, verify `localUid` unchanged, `firebaseUid` updated

#### Edge Case 4: Multiple Profiles with Mixed Auth State
- One device, multiple profiles — some created pre-account, some post-account
- All profiles share the same `UserProfiles.localUid` (device-level identity)
- `hasAccount` is on `UserProfiles`, not `Profiles` — account-level, not profile-level
- When account exists, ALL profiles sync together
- Test: create 2 profiles, link account, verify both profiles visible in Firestore sync

### References

- [Source: _bmad-output/planning-artifacts/local-first-auth-abstraction-layer.md — Full design doc]
- [Source: lib/core/navigation/guards/auth_guard.dart — Current guard being replaced]
- [Source: lib/main.dart — Current startup sequence being redesigned]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
