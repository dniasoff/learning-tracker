# Story 19.6: Startup Sequence Hardening

Status: ready-for-dev

## Story

As a learner,
I want the app to launch instantly and work fully offline from the first tap,
so that I am never blocked by network issues, Firebase hangs, or slow initialization.

## Acceptance Criteria

**AC-1: Firebase.initializeApp() deferred to background**
**Given** the app is launched (online or offline)
**When** `main()` executes
**Then** `runApp()` is called without waiting for `Firebase.initializeApp()`
**And** Firebase initialization happens in the background after the first frame
**And** a failure in Firebase init does not crash the app or block any functionality

**AC-2: GoogleSignIn.initialize() deferred to first use**
**Given** the app is launched
**When** `main()` executes
**Then** `GoogleSignIn.instance.initialize()` is NOT called during startup
**And** it is called lazily on the first invocation of `signInWithGoogle()` in `AuthRepository`
**And** if it fails (no network), the user sees a clear error message

**AC-3: SeedManager integration at startup**
**Given** the app is launched for the first time (or after a seed version upgrade)
**When** `main()` executes
**Then** `SeedManager.ensureContentDatabase()` runs before `runApp()` so content queries are available immediately
**And** the content DB path is passed to the `ProviderContainer` as a provider override
**And** on subsequent launches with the same seed version, this step is a no-op (< 5ms)

**AC-4: ConnectivityService tiered check with caching**
**Given** the app checks connectivity
**When** `ConnectivityService.isOnline` is called
**Then** a cached result is returned if within the 30-second cache window
**And** if the cache is stale, a platform-level check via `connectivity_plus` runs first (< 1ms)
**And** a DNS probe only runs if the platform says the device has a network interface
**And** the DNS timeout is 2 seconds (not 5)

**AC-5: ConnectivityService platform stream**
**Given** the device changes network state (e.g., airplane mode toggled)
**When** `connectivity_plus` emits a `ConnectivityResult.none` event
**Then** the cached connectivity state is immediately set to `false` (no DNS probe needed)
**And** when the platform reports a network interface is available, the cache is invalidated to force a fresh DNS check on the next `isOnline` call

**AC-6: Guaranteed startup time**
**Given** the app is launched offline (airplane mode, no WiFi)
**When** measuring from `main()` entry to `runApp()` return
**Then** the elapsed time is under 200ms (excluding first-launch seed decompression)
**And** the user never sees a spinner or blank screen waiting for network

**AC-7: Notification init moved to post-first-frame**
**Given** the app is launched
**When** `main()` executes
**Then** `NotificationInitializer.initialize()` runs after `runApp()`, not before
**And** a failure in notification init is logged but does not block the app

## Tasks / Subtasks

### T1: Restructure main.dart Startup Sequence (AC: 1, 3, 6, 7)

The current `main()` in `learning_tracker/lib/main.dart` is:

```dart
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } on FirebaseException catch (_) {
        // Already initialized (e.g. hot restart) — use existing app.
      }

      // google_sign_in v7 requires initialize() before authenticate().
      await GoogleSignIn.instance.initialize();

      final talker = AppLogger.init();
      AppLogger.setupFlutterErrorHandlers();

      talker.info('App starting');

      final container = ProviderContainer(
        observers: [
          TalkerRiverpodObserver(
            talker: talker,
            settings: const TalkerRiverpodLoggerSettings(
              printProviderDisposed: true,
            ),
          ),
        ],
      );

      // Initialize notification system (timezone data + plugin).
      try {
        final router = container.read(routerProvider);
        final notificationInitializer = NotificationInitializer(
          service: NotificationService(),
          router: router,
        );
        await notificationInitializer.initialize();
      } catch (e, stack) {
        talker.error('Notification init failed (non-fatal)', e, stack);
      }

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LearningTrackerApp(),
        ),
      );
    },
    (Object error, StackTrace stack) {
      AppLogger.instance.handle(error, stack);
    },
  );
}
```

- [ ] Remove `Firebase.initializeApp()` from the synchronous startup path
- [ ] Remove `GoogleSignIn.instance.initialize()` from `main()` entirely
- [ ] Add `SeedManager.ensureContentDatabase()` call before `ProviderContainer` creation
- [ ] Move `NotificationInitializer.initialize()` to after `runApp()` (fire-and-forget)
- [ ] Pass `contentDbPath` into the `ProviderContainer` as a provider override

**Target main() structure:**

```dart
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final talker = AppLogger.init();
      AppLogger.setupFlutterErrorHandlers();
      talker.info('App starting');

      // --- Critical path: no network calls, guaranteed fast ---

      // Step 1: Ensure content DB is ready (no-op on repeat launches,
      // decompresses from bundled asset on first launch / seed upgrade).
      final seedManager = SeedManager();
      final contentDbPath = await seedManager.ensureContentDatabase();

      // Step 2: Create provider container with content DB path override.
      final container = ProviderContainer(
        overrides: [
          contentDbPathProvider.overrideWithValue(contentDbPath),
        ],
        observers: [
          TalkerRiverpodObserver(
            talker: talker,
            settings: const TalkerRiverpodLoggerSettings(
              printProviderDisposed: true,
            ),
          ),
        ],
      );

      // Step 3: Launch app — UI is interactive from here.
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const LearningTrackerApp(),
        ),
      );

      // --- Post-first-frame: background, non-blocking ---

      // Step 4: Firebase init (background, fire-and-forget).
      unawaited(_initFirebaseInBackground(talker, container));

      // Step 5: Notification init (background, fire-and-forget).
      unawaited(_initNotificationsInBackground(talker, container));
    },
    (Object error, StackTrace stack) {
      AppLogger.instance.handle(error, stack);
    },
  );
}
```

### T2: Implement _initFirebaseInBackground() (AC: 1)

- [ ] Create a top-level async function that wraps `Firebase.initializeApp()` in try/catch:

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

    // If user has an account and Firebase restored auth state from
    // its local token cache, the SyncEngine can activate.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Signal to SyncLifecycleObserver that Firebase is now ready.
      container.read(firebaseReadyProvider.notifier).state = true;
    }
  } on FirebaseException catch (_) {
    // Already initialized (hot restart) — safe to ignore.
    talker.info('Firebase already initialized (hot restart)');
  } catch (e, stack) {
    // Offline or network error — app continues in local-only mode.
    talker.warning('Firebase init failed (non-fatal, offline mode)', e, stack);
  }
}
```

- [ ] Create `firebaseReadyProvider` — a simple `StateProvider<bool>` defaulting to `false`:

```dart
// lib/core/providers/firebase_ready_provider.dart
final firebaseReadyProvider = StateProvider<bool>((ref) => false);
```

- [ ] Ensure `SyncLifecycleObserver` watches `firebaseReadyProvider` so it can attach listeners once Firebase is available (see T6)

### T3: Implement _initNotificationsInBackground() (AC: 7)

- [ ] Create a top-level async function that wraps notification initialization:

```dart
Future<void> _initNotificationsInBackground(
  Talker talker,
  ProviderContainer container,
) async {
  try {
    final router = container.read(routerProvider);
    final notificationInitializer = NotificationInitializer(
      service: NotificationService(),
      router: router,
    );
    await notificationInitializer.initialize();
    talker.info('Notifications initialized (background)');
  } catch (e, stack) {
    talker.error('Notification init failed (non-fatal)', e, stack);
  }
}
```

- [ ] Verify that notification tap handling still works when initialization completes after `runApp()` — the router must already be mounted. Current code passes `router` by reference so this should be safe; validate with manual test.

### T4: Defer GoogleSignIn.initialize() to First Use (AC: 2)

- [ ] Remove `await GoogleSignIn.instance.initialize();` from `main.dart` (line 33 in current file)
- [ ] Remove the `google_sign_in` import from `main.dart`
- [ ] Find `AuthRepository` (or equivalent) where `signInWithGoogle()` is implemented
- [ ] Add lazy initialization with try/catch at the call site:

```dart
// In AuthRepository.signInWithGoogle():
Future<UserCredential> signInWithGoogle() async {
  // Lazy init — only on first Google sign-in attempt.
  try {
    await GoogleSignIn.instance.initialize();
  } catch (e) {
    throw AuthException(
      'Google Sign-In requires an internet connection. '
      'Please check your network and try again.',
    );
  }

  // Proceed with normal Google sign-in flow...
  final googleUser = await _googleSignIn.signIn();
  if (googleUser == null) throw AuthException('Sign-in cancelled');
  // ...existing credential exchange code...
}
```

- [ ] Guard against double-initialization: `GoogleSignIn.instance.initialize()` should be safe to call multiple times, but if not, add a `bool _googleSignInInitialized = false` flag to `AuthRepository` and skip if already true
- [ ] Verify that no other code path calls `GoogleSignIn` APIs before `initialize()` — search for all `GoogleSignIn` usages in the codebase

### T5: SeedManager Startup Integration (AC: 3)

- [ ] Import `SeedManager` from `lib/core/database/seed_manager.dart` (created in a prior Epic 19 story)
- [ ] Call `seedManager.ensureContentDatabase()` in `main()` before `ProviderContainer` creation (see T1 target structure)
- [ ] Create `contentDbPathProvider` if it does not already exist:

```dart
// lib/core/providers/database_provider.dart (or new file)

/// Overridden in main() with the actual path from SeedManager.
final contentDbPathProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'contentDbPathProvider must be overridden in main()',
  );
});
```

- [ ] Ensure `ContentDatabase` provider reads from `contentDbPathProvider`:

```dart
final contentDatabaseProvider = Provider<ContentDatabase>((ref) {
  final path = ref.watch(contentDbPathProvider);
  return ContentDatabase(
    NativeDatabase(
      File(path),
      setup: (db) {
        db.execute('PRAGMA query_only = ON');
      },
    ),
  );
});
```

- [ ] Handle first-launch decompression time: if decompression takes > 500ms, consider showing a brief splash/progress indicator (this is the one allowed blocking step — it reads from bundled assets, not network)

### T6: Update SyncLifecycleObserver for Deferred Firebase (AC: 1)

The current `SyncLifecycleObserver` at `learning_tracker/lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart` directly checks `FirebaseAuth.instance.currentUser` at widget init time. With deferred Firebase, this will be `null` during initial build because Firebase has not initialized yet.

**Current code (problematic with deferred Firebase):**

```dart
class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser != null) {
        final engine = ref.read(syncEngineProvider);
        engine.attachListeners();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        if (FirebaseAuth.instance.currentUser != null) {
          engine.attachListeners();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        engine.detachListeners();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.detachListeners();
        break;
    }
  }
}
```

- [ ] Replace direct `FirebaseAuth.instance.currentUser` checks with a watch on `firebaseReadyProvider`:

```dart
class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    // Watch firebaseReadyProvider — rebuilds when Firebase finishes
    // background init and a signed-in user is detected.
    final firebaseReady = ref.watch(firebaseReadyProvider);

    if (firebaseReady && !_listenersAttached) {
      // Schedule attachment after this build frame completes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(syncEngineProvider).attachListeners();
          _listenersAttached = true;
        }
      });
    }

    return widget.child;
  }

  bool _listenersAttached = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(firebaseReadyProvider)) return;

    final engine = ref.read(syncEngineProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        engine.attachListeners();
        _listenersAttached = true;
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.detachListeners();
        _listenersAttached = false;
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

- [ ] Remove the `firebase_auth` import from `sync_lifecycle_observer.dart` since it no longer directly checks `FirebaseAuth.instance`

### T7: ConnectivityService — Add connectivity_plus and Tiered Check (AC: 4, 5)

- [ ] Add `connectivity_plus` to `pubspec.yaml`:

```yaml
dependencies:
  connectivity_plus: ^6.0.0  # or latest stable
```

- [ ] Run `flutter pub get`
- [ ] Rewrite `ConnectivityService` at `learning_tracker/lib/core/network/connectivity_service.dart`:

**Current code (full file):**

```dart
import 'dart:io';

class ConnectivityService {
  Future<bool> get isOnline async {
    try {
      final result = await InternetAddress.lookup(
        'dns.google',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on Exception {
      return false;
    }
  }

  Future<bool> get isOffline async => !(await isOnline);

  void dispose() {}
}
```

**New code:**

```dart
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for checking network connectivity status.
///
/// Uses a three-tier strategy:
/// 1. Cache — return cached result if within 30-second window.
/// 2. Platform — instant OS-level check via connectivity_plus.
/// 3. DNS probe — only if platform says a network interface is active.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  // --- Cache state ---
  bool? _lastKnownState;
  DateTime? _lastCheckTime;
  static const _cacheDuration = Duration(seconds: 30);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Start listening to platform connectivity changes.
  ///
  /// Call once during app startup (or when the provider is first created).
  void initialize() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        // Platform says no network — cache immediately, skip DNS.
        _lastKnownState = false;
        _lastCheckTime = DateTime.now();
      } else {
        // Platform says network available — invalidate cache so next
        // isOnline call performs a fresh DNS probe.
        _lastKnownState = null;
        _lastCheckTime = null;
      }
    });
  }

  /// Whether the device currently has internet connectivity.
  ///
  /// Performance characteristics:
  /// - Cache hit (within 30s): 0ms
  /// - Airplane mode / no interface: < 1ms (platform check)
  /// - WiFi connected, internet reachable: ~50-200ms (DNS probe)
  /// - WiFi connected, no internet: 2s (DNS timeout)
  Future<bool> get isOnline async {
    // Tier 0: Cache hit
    if (_lastKnownState != null && _lastCheckTime != null) {
      final age = DateTime.now().difference(_lastCheckTime!);
      if (age < _cacheDuration) return _lastKnownState!;
    }

    // Tier 1: Platform check (instant, no network call)
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none) ||
        connectivityResults.isEmpty) {
      _lastKnownState = false;
      _lastCheckTime = DateTime.now();
      return false;
    }

    // Tier 2: DNS probe (only if platform says connected)
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 2));
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

  /// Whether the device is currently offline.
  Future<bool> get isOffline async => !(await isOnline);

  /// Release resources held by this service.
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}
```

### T8: Update ConnectivityService Provider (AC: 4, 5)

- [ ] Update `learning_tracker/lib/core/providers/network_providers.dart` to call `initialize()`:

**Current code:**

```dart
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});
```

**New code:**

```dart
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
```

- [ ] Verify all existing consumers of `connectivityServiceProvider` still work (the public API is unchanged: `isOnline`, `isOffline`, `dispose()`)

### T9: Tests (AC: 1-7)

- [ ] **Unit test: ConnectivityService tiered check**
  - Mock `Connectivity` to return `ConnectivityResult.none` — verify `isOnline` returns `false` without DNS probe
  - Mock `Connectivity` to return `ConnectivityResult.wifi` — verify DNS probe executes
  - Verify cache: call `isOnline` twice within 30s — second call returns cached result without DNS

- [ ] **Unit test: ConnectivityService platform stream**
  - Emit `ConnectivityResult.none` on mock stream — verify `_lastKnownState` is `false`
  - Emit `ConnectivityResult.wifi` on mock stream — verify cache is invalidated (`_lastKnownState` is `null`)

- [ ] **Unit test: ConnectivityService DNS timeout**
  - Mock DNS lookup to hang — verify `isOnline` returns `false` after 2s (not 5s)

- [ ] **Unit test: _initFirebaseInBackground resilience**
  - Test that when `Firebase.initializeApp()` throws, the function completes without rethrowing
  - Test that when `Firebase.initializeApp()` throws `FirebaseException`, it is treated as a no-op (hot restart case)
  - Test that `firebaseReadyProvider` is set to `true` when `currentUser` is non-null

- [ ] **Unit test: GoogleSignIn lazy init**
  - Test that `signInWithGoogle()` calls `GoogleSignIn.instance.initialize()` before `signIn()`
  - Test that if `initialize()` throws, a user-facing `AuthException` is thrown with network message

- [ ] **Widget test: SyncLifecycleObserver with deferred Firebase**
  - Build widget with `firebaseReadyProvider = false` — verify `attachListeners()` is NOT called
  - Set `firebaseReadyProvider = true` — verify `attachListeners()` IS called on next frame
  - Verify lifecycle transitions (paused/resumed) respect `firebaseReadyProvider` state

- [ ] **Integration test: startup sequence order**
  - Verify `runApp()` is called before Firebase init completes
  - Verify SeedManager runs before `ProviderContainer` creation
  - Verify notification init runs after `runApp()`

## Dev Notes

### Architecture

- **Dependencies:** This story depends on `SeedManager` being implemented (Epic 19 prior story). If `SeedManager` is not yet available, implement T1 with a TODO placeholder for the SeedManager call and implement all other tasks fully.
- **Core change:** Move all network-dependent initialization out of the critical startup path. The critical path becomes: `WidgetsFlutterBinding` -> `SeedManager` -> `ProviderContainer` -> `runApp()`. Everything else is background.
- **Pattern:** Fire-and-forget with `unawaited()` for post-first-frame work. Each background initializer is independently try/caught so one failure does not cascade.

### Current Startup Timing (Blocking)

```
1. WidgetsFlutterBinding.ensureInitialized()          ~50ms
2. Firebase.initializeApp()                            ~200ms (HANGS offline)
3. GoogleSignIn.instance.initialize()                  ~100ms (CRASHES offline)
4. Logger init                                         ~10ms
5. ProviderContainer creation                          ~5ms
6. NotificationInitializer.initialize()                ~150ms
7. runApp()                                            ~50ms
                                              TOTAL:   ~565ms best-case
                                                       INFINITE worst-case (offline)
```

### Target Startup Timing (Non-Blocking)

```
1. WidgetsFlutterBinding.ensureInitialized()          ~50ms
2. Logger init                                         ~10ms
3. SeedManager.ensureContentDatabase()                 ~5ms (repeat) / ~2-5s (first launch)
4. ProviderContainer creation                          ~5ms
5. runApp()                                            ~50ms
                                              TOTAL:   ~120ms (guaranteed, no network)

--- Background (after first frame, non-blocking) ---
6. Firebase.initializeApp()                            try/catch, fire-and-forget
7. NotificationInitializer.initialize()                try/catch, fire-and-forget
```

### Key Files

| File | Action |
|------|--------|
| `lib/main.dart` | Major rewrite — restructure startup sequence |
| `lib/core/network/connectivity_service.dart` | Rewrite — tiered check with connectivity_plus |
| `lib/core/providers/network_providers.dart` | Modify — call `initialize()` on ConnectivityService |
| `lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart` | Modify — watch `firebaseReadyProvider` instead of `FirebaseAuth.instance` |
| `lib/core/providers/firebase_ready_provider.dart` | Create — `StateProvider<bool>` |
| `lib/core/providers/database_provider.dart` | Modify — add `contentDbPathProvider` |
| `lib/features/auth/data/repositories/auth_repository.dart` | Modify — lazy GoogleSignIn init |
| `pubspec.yaml` | Modify — add `connectivity_plus` dependency |
| `test/core/network/connectivity_service_test.dart` | Create — unit tests for tiered check |
| `test/features/sync/sync_lifecycle_observer_test.dart` | Modify — tests for deferred Firebase |

### Investigation Areas

- Verify `GoogleSignIn.instance.initialize()` is safe to call multiple times (idempotent). If not, add a guard flag in `AuthRepository`.
- Check if `NotificationInitializer.initialize()` has any dependency on the widget tree being fully mounted (e.g., requesting permissions may need a foreground activity). If so, delay further using `WidgetsBinding.instance.addPostFrameCallback`.
- Audit all imports of `firebase_auth` in non-auth files. After this story, only `AuthRepository`, sync providers, and the background init helper should import Firebase directly.
- Check whether `connectivity_plus` version 6.x returns `List<ConnectivityResult>` (multi-network) or single `ConnectivityResult`. The code above assumes the list API. Adjust if the installed version differs.

### Critical Constraints

- `SeedManager.ensureContentDatabase()` MUST complete before `runApp()` because content queries will fire immediately when the dashboard loads. This is the one allowed blocking call in the critical path.
- `firebaseReadyProvider` must only be set to `true` AFTER `Firebase.initializeApp()` succeeds AND `FirebaseAuth.instance.currentUser` is non-null. Setting it prematurely will cause `SyncEngine` to attempt Firestore calls before Firebase is initialized, resulting in crashes.
- The `connectivity_plus` stream subscription must be cancelled in `dispose()` to avoid memory leaks.
- Do not remove the `on FirebaseException catch` guard in `_initFirebaseInBackground` — hot restart calls `Firebase.initializeApp()` a second time, which throws `FirebaseException` if already initialized.

### References

- [Offline-First Architecture v2, §5 Inherited Unchanged](../docs/planning/architecture-offline-v2.md) — Startup hardening (deferred Firebase init, deferred Google Sign-In init, 2s DNS timeout) is inherited from the prior architecture and remains canon
- [Seed Database Build Tool Design, Section 11](../docs/stories/implementation/seed-database-build-tool-design.md) — SeedManager runtime integration

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
