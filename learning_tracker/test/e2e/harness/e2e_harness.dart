/// Full-app E2E harness for headless "flutter test" runs.
///
/// ## Design intent
///
/// Boots the REAL router (AppRouter with its auth/profile guards), the
/// REAL screens and the REAL Riverpod providers — but with a controllable
/// [FakeFirebaseFirestore] + [ContentDatabase].
///
/// ## What is real
/// - AppRouter + all route guards (AuthGuard, ProfileGuard, …)
/// - All Riverpod providers that are wired into LearningTrackerApp
/// - NavigationResolver / AutoRoute deep-link mechanics
///
/// ## What is stubbed / overridden
/// - [ContentDatabase] → in-memory NativeDatabase (no bundled seed file).
///   Seed content rows with [E2EHarness.seedContent] when a journey needs
///   content browsing or text display.
/// - [authStateProvider] → caller-supplied [AuthState] (no Firebase)
/// - [authRepositoryProvider] → [_StubAuthRepository] (returns the supplied
///   identity as an [AppUser], or null without an identity; stream never fires)
/// - [pinServiceProvider] → [_NullPinService] stub (no secure-storage;
///   hasParentPin returns false so PIN guard never activates)
/// - [analyticsServiceProvider] → [NullAnalyticsService] (no-op events)
/// - [magicLinkInitializationProvider] → completes instantly (no deep-link
///   listening)
/// - [streakMilestoneAnalyticsObserverProvider] → empty stream (no Drift streak
///   watch)
/// - SharedPreferences → in-memory mock (onboarding_complete = true so AuthGuard
///   passes through on the happy path)
/// - path_provider → mocked to /tmp so Drift guards don't panic
/// - [rootScaffoldMessengerKey] → wired into [MaterialApp.router]
///   so SnackBar / MaterialBanner assertions via the root messenger work.
///
/// ## Usage
///
/// ```dart
/// testWidgets('dashboard journey', (tester) async {
///   final identity = E2EIdentity.localBorn();
///   final h = E2EHarness(tester, identity: identity);
///   await h.pumpApp(path: '/dashboard', extraOverrides: h.dashboardSilenceOverrides);
///   await h.expectOnScreen('DASHBOARD');
///   await h.dispose();
/// });
/// ```
///
/// ## Seeding content
///
/// Journeys that exercise content browsing (E2E-305, E2E-306) or text display
/// (E2E-308, E2E-311) need rows in the content database.  Call
/// [E2EHarness.seedContent] **before** [pumpApp]:
///
/// ```dart
/// await h.seedContent([
///   TextCacheCompanion.insert(
///     sefariaRef: 'Berakhot 2a',
///     hebrewText: 'ברכות',
///     englishText: 'Berakhot',
///     fetchedAt: DateTime.utc(2026, 1, 1),
///   ),
/// ]);
/// ```
///
/// ## Headless limitations — device-only surfaces
///
/// The following surfaces require a physical / emulator device via
/// `integration_test` and **cannot** be exercised by this harness:
///
/// - **[PersistentSwitcherScaffold]** — mounted in [LearningTrackerApp]'s
///   `MaterialApp.router builder` slot.  The harness constructs a plain
///   [MaterialApp.router] without that builder, so the persistent role-label
///   bar at the top of the screen is absent.  Journeys that assert the
///   switcher bar is "present on all tabs" (e.g. E2E-1117) or that tapping it
///   opens a sheet must run as device integration tests.
///
/// - **[SacredTimeLockOverlay]** — rendered by [AppShell] when
///   `currentSacredWindowProvider` emits an active window.  Because the harness
///   does not mount [AppShell] directly the overlay is not in the tree.
///   Journeys that assert the lock overlay appears / auto-dismisses
///   (e.g. E2E-1103) must run as device integration tests.
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart' show FirebaseApp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/guards/auth_guard.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/streak_milestone_analytics_observer.dart'
    show streakMilestoneAnalyticsObserverProvider;
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/navigation/root_scaffold_messenger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show ActiveProfileDocId, activeProfileDocIdProvider;
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/magic_link_providers.dart'
    show magicLinkInitializationProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_fixtures.dart';

// ── Global setup helper ─────────────────────────────────────────────────────

/// Call once in [setUpAll] before any [E2EHarness] test runs.
///
/// Suppresses google_fonts network, Drift multi-DB warnings, and mocks
/// path_provider so guarded code that opens a real file-backed DB in the auth
/// guard doesn't crash in the headless environment.
void e2eSetUpAll() {
  GoogleFonts.config.allowRuntimeFetching = false;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final savedOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    if (msg.contains('GoogleFonts') || msg.contains('google_fonts')) return;
    savedOnError?.call(details);
  };

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getTemporaryDirectory' ||
              methodCall.method == 'getApplicationDocumentsDirectory' ||
              methodCall.method == 'getApplicationSupportDirectory') {
            return '/tmp/flutter_e2e_test';
          }
          return null;
        },
      );
}

// ── Stubs ──────────────────────────────────────────────────────────────────

/// No-op [AuthRepository] that never touches Firebase Auth.
class _StubAuthRepository extends Mock implements AuthRepository {
  _StubAuthRepository({
    required E2EIdentity? identity,
    required String? accountId,
  }) : _identity = identity,
       _accountId = accountId;

  final E2EIdentity? _identity;
  final String? _accountId;

  @override
  AppUser? get currentUser {
    final identity = _identity;
    final accountId = _accountId;
    if (identity == null || accountId == null) return null;

    final isCloudBorn = identity.tier == Tier.cloud;
    return AppUser(
      uid: accountId,
      email: identity.email,
      displayName: identity.displayName,
      emailVerified: true,
      providers: isCloudBorn ? const ['password'] : const [],
    );
  }

  @override
  Future<AppUser?> reloadCurrentUser() async => null;

  @override
  Stream<AppUser?> onAuthStateChanged() => const Stream.empty();

  @override
  bool isSignInWithEmailLink(String link) => false;

  @override
  Future<void> signOut() async {}

  @override
  List<String> getLinkedProviders() => [];
}

/// [PinService] stub: hasPin always returns false; guard never activates.
class _NullPinService extends Fake implements PinService {
  @override
  Future<bool> hasParentPin() async => false;

  @override
  Future<bool> hasProfilePin(String profileId) async => false;

  @override
  Future<bool> hasTutorPin(String profileId) async => false;
}

class _FakeFirebaseApp extends Mock implements FirebaseApp {}

class _FakeFirebaseAuth extends Mock implements FirebaseAuth {}

class _FixedActiveAccountId extends ActiveAccountId {
  _FixedActiveAccountId(this._id);
  final String _id;

  @override
  String? build() => _id;
}

class _FixedActiveProfileDocId extends ActiveProfileDocId {
  _FixedActiveProfileDocId(this._id);
  final String _id;

  @override
  String? build() => _id;
}

// ── Fixed-value notifier helpers ────────────────────────────────────────────

class _FixedProfileId extends ActiveProfileId {
  _FixedProfileId(this._id);
  final String _id;
  @override
  String? build() => _id;
}

class _FixedSelectedProfile extends SelectedProfileId {
  _FixedSelectedProfile(this._id);
  final String _id;
  @override
  String? build() => _id;
}

// ── E2EIdentity ─────────────────────────────────────────────────────────────

/// Describes the authenticated identity the harness should boot into.
///
/// Create via [E2EIdentity.localBorn] for the common headless case.
class E2EIdentity {
  E2EIdentity._({
    required this.email,
    required this.displayName,
    required this.profileMode,
    this.tier = Tier.local,
    required String seedAccountId,
    required String seedProfileId,
  }) : _seedAccountId = seedAccountId,
       _seedProfileId = seedProfileId;

  factory E2EIdentity.localBorn({
    String email = 'e2e@test.com',
    String displayName = 'E2E User',
    String profileMode = 'adult',
    String accountId = 'e2e-account',
    String profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA',
  }) => E2EIdentity._(
    email: email,
    displayName: displayName,
    profileMode: profileMode,
    seedAccountId: accountId,
    seedProfileId: profileId,
  );

  factory E2EIdentity.cloudBorn({
    String email = 'e2e@test.com',
    String displayName = 'E2E User',
    String profileMode = 'adult',
    String accountId = 'e2e-account',
    String profileId = '01J6Q2H4A8M7K3P9R5T6V8WXYA',
  }) => E2EIdentity._(
    email: email,
    displayName: displayName,
    profileMode: profileMode,
    tier: Tier.cloud,
    seedAccountId: accountId,
    seedProfileId: profileId,
  );

  final String email;
  final String displayName;
  final String profileMode;
  final Tier tier;
  final String _seedAccountId;
  final String _seedProfileId;

  // Resolved after [E2EHarness._seedIdentity] runs.
  String? _resolvedProfileId;
  String? _resolvedAccountId;

  /// The Firestore ULID profile id (available after [E2EHarness.pumpApp]).
  String get profileId => _resolvedProfileId!;

  /// The Firestore account uid (available after [E2EHarness.pumpApp]).
  String get accountId => _resolvedAccountId!;
}

// ── E2EHarness ──────────────────────────────────────────────────────────────

/// Full-app headless E2E harness.
///
/// Constructs a real [AppRouter] wired to fake Firestore with sensible guard
/// stubs and Riverpod overrides that disable network-touching providers.
///
/// Typical lifecycle in a [testWidgets] callback:
/// ```dart
/// final identity = E2EIdentity.localBorn(displayName: 'Alice');
/// final h = E2EHarness(tester, identity: identity);
/// await h.pumpApp(
///   path: '/dashboard',
///   extraOverrides: h.dashboardSilenceOverrides,
/// );
/// h.expectOnScreen('DASHBOARD');
/// addTearDown(h.dispose);
/// ```
class E2EHarness {
  E2EHarness(
    this._tester, {

    /// Optional initial auth identity.  When provided the harness pre-seeds a
    /// matching account + profile document in fake Firestore and overrides
    /// [authStateProvider] so the AuthGuard passes straight through.
    E2EIdentity? identity,
  }) : _identity = identity {
    _firestore = createFakeFirestore(
      authenticatedUid: identity?._seedAccountId,
    );
    _contentDb = ContentDatabase(NativeDatabase.memory());
  }

  final WidgetTester _tester;
  final E2EIdentity? _identity;

  late FakeFirebaseFirestore _firestore;
  late ContentDatabase _contentDb;
  late AppRouter _router;
  late PinGuard _pinGuard;

  // ── Setup ─────────────────────────────────────────────────────────────────

  /// Boots the app widget tree.
  ///
  /// [path] — initial deep-link path (e.g. `'/dashboard'`, `'/onboarding'`).
  ///   Defaults to `'/'` (router's own initial route, resolved by guards).
  ///
  /// [extraOverrides] — additional [Override] entries merged AFTER the standard
  ///   set.  Use to inject fakes for providers not covered by the harness.
  Future<void> pumpApp({
    String path = '/',
    List<Override> extraOverrides = const [],
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    final identity = _identity;
    if (identity != null) {
      await _seedIdentity(identity);
    }

    _router = _buildRouter();

    await _tester.pumpWidget(
      ProviderScope(
        overrides: [..._buildOverrides(identity), ...extraOverrides],
        child: _buildMaterialApp(
          path == '/'
              ? _router.config()
              : _router.config(deepLinkBuilder: (_) => DeepLink.path(path)),
          locale,
        ),
      ),
    );

    // Settle async providers and navigation guards.
    await pump();
    await pump(const Duration(milliseconds: 500));
    await pump();
  }

  /// Disposes the fake Firestore-backed harness and collapses the widget tree.
  ///
  /// Register with [addTearDown] at the start of the test:
  /// ```dart
  /// addTearDown(h.dispose);
  /// ```
  Future<void> dispose() async {
    await _tester.pumpWidget(const SizedBox.shrink());
    await _tester.pump(Duration.zero);
    await _contentDb.close();
  }

  // ── Interaction helpers ────────────────────────────────────────────────────

  /// Pumps [duration] frames.
  Future<void> pump([Duration? duration]) => _tester.pump(duration);

  /// Taps the widget found by [finder] and pumps a settle delay.
  Future<void> tapWidget(
    Finder finder, {
    Duration settle = const Duration(milliseconds: 300),
  }) async {
    await _tester.tap(finder);
    await _tester.pump();
    await _tester.pump(settle);
  }

  /// Taps the first widget that contains [text].
  Future<void> tapText(
    String text, {
    Duration settle = const Duration(milliseconds: 300),
  }) => tapWidget(find.text(text), settle: settle);

  /// Taps the widget with the given [key].
  Future<void> tapByKey(
    Key key, {
    Duration settle = const Duration(milliseconds: 300),
  }) => tapWidget(find.byKey(key), settle: settle);

  /// Types [text] into the first [TextField] matching [finder].
  Future<void> enterText(Finder finder, String text) async {
    await _tester.tap(finder);
    await _tester.pump();
    await _tester.enterText(finder, text);
    await _tester.pump();
  }

  // ── Assertion helpers ──────────────────────────────────────────────────────

  /// Asserts that [text] appears in the widget tree.
  ///
  /// [routeName] is an optional human label included in the failure message.
  void expectOnScreen(String text, {String? routeName}) {
    expect(
      find.text(text),
      findsWidgets,
      reason: routeName != null
          ? 'expected to be on screen "$routeName" (text: "$text")'
          : 'expected text "$text" on screen',
    );
  }

  /// Asserts that [text] is absent from the widget tree.
  void expectNotOnScreen(String text) {
    expect(find.text(text), findsNothing);
  }

  /// Returns the fake Firestore instance for direct data assertions/seeding.
  FakeFirebaseFirestore get firestore => _firestore;

  /// Returns the in-memory [ContentDatabase] for direct content assertions.
  ContentDatabase get contentDb => _contentDb;

  /// Returns the [AppRouter] for low-level navigation assertions.
  AppRouter get router => _router;

  /// Marks the parent-mode PIN as authenticated for the current identity's
  /// profile, so PIN-gated routes (`/parent-mode/*`) can be reached in tests
  /// without going through the real PIN-entry flow.
  ///
  /// Call **after** [pumpApp] (so the identity profileId is resolved and the
  /// [_pinGuard] is built) but **before** navigating to a PIN-gated route.
  /// Use router-level navigation ([router.push]) for PIN-gated screens — a
  /// second [pumpApp] call rebuilds the guard and resets the session:
  ///
  /// ```dart
  /// await h.pumpApp(path: '/dashboard', extraOverrides: [...]);
  /// h.markPinAuthenticated();  // prime the cache for /parent-mode/* routes
  /// await h.router.push(const RewardConfigurationRoute());
  /// await h.pump(const Duration(milliseconds: 500));
  /// ```
  void markPinAuthenticated() {
    final profileId = _identity?._resolvedProfileId;
    if (profileId != null) {
      _pinGuard.markAuthenticated(profileId);
    }
  }

  /// Seeds rows into the in-memory [ContentDatabase] via a caller-supplied
  /// async callback.
  ///
  /// Call **before** [pumpApp] when a journey needs content browsing or
  /// text display.  The callback receives the live [ContentDatabase] so callers
  /// can use fully-typed companions without extra generic constraints:
  ///
  /// ```dart
  /// import 'package:learning_tracker/core/database/content/content_database.dart';
  ///
  /// await h.seedContent((db) async {
  ///   await db.into(db.textCache).insert(
  ///     TextCacheCompanion.insert(
  ///       sefariaRef: 'Berakhot 2a',
  ///       hebrewText: 'ברכות',
  ///       englishText: 'Berakhot',
  ///       fetchedAt: DateTime.utc(2026, 1, 1),
  ///     ),
  ///   );
  /// });
  /// ```
  Future<void> seedContent(Future<void> Function(ContentDatabase db) seed) =>
      seed(_contentDb);

  // ── Dashboard silence overrides ────────────────────────────────────────────

  /// Provider overrides that silence the heavy dashboard providers (streak,
  /// active curricula, active tracks) so tests that land on `/dashboard` don't
  /// trigger Drift stream subscriptions or timers that violate the
  /// `_verifyInvariants` timer check.
  ///
  /// Include via `extraOverrides: h.dashboardSilenceOverrides` when navigating
  /// directly to `/dashboard`.
  List<Override> get dashboardSilenceOverrides => [
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(<CurriculumId>[]),
    ),
    dashboardActiveTracksStreamProvider.overrideWith(
      (ref) => Stream.value(<CurriculumTrackEntity>[]),
    ),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value((currentStreak: 0, maxStreak: 0)),
    ),
    dashboardStreakRecoveryProvider.overrideWith(
      (ref) => Future.value(
        const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0),
      ),
    ),
    // The migrated provider is a Firestore-backed Future<int>, so this keeps
    // the dashboard quiet without creating a live data subscription.
    dashboardGlobalPointsProvider.overrideWith((ref) => Future.value(0)),
  ];

  // ── Private builders ───────────────────────────────────────────────────────

  Future<void> _seedIdentity(E2EIdentity identity) async {
    // The harness creates this authenticated fake before callers can seed
    // additional documents through [firestore].
    await seedAccount(
      _firestore,
      uid: identity._seedAccountId,
      email: identity.email,
      displayName: identity.displayName,
    );
    await seedProfile(
      _firestore,
      uid: identity._seedAccountId,
      profileId: identity._seedProfileId,
      displayName: identity.displayName,
      mode:
          ProfileMode.tryFromStorageKey(identity.profileMode) ??
          ProfileMode.adult,
    );

    identity._resolvedProfileId = identity._seedProfileId;
    identity._resolvedAccountId = identity._seedAccountId;
  }

  AppRouter _buildRouter() {
    final profileId = _identity?._resolvedProfileId;
    final profileRepository = FirestoreLearnerProfileRepository(
      firestore: _firestore,
      uid: _identity?._resolvedAccountId ?? 'e2e-signed-out',
    );

    _pinGuard = PinGuard(
      pinService: _NullPinService(),
      promptForPin: () async => false,
      getScope: () => profileId != null ? PinScope.parent(profileId) : null,
      pinSetupRoute: () => const PinFlowSetupRoute(),
    );
    return AppRouter(
      authGuard: AuthGuard(),
      profileGuard: ProfileGuard(
        getProfiles: () => profileRepository.watchProfiles().first,
        getSelectedProfileId: () => profileId,
        setSelectedProfileId: (_) {},
        isTutoredSession: () => false,
        profilePickerRoute: () => const ProfilePickerRoute(),
      ),
      childModeGuard: ChildModeGuard(
        getProfileById: (id) => profileRepository.getProfile(id),
        getSelectedProfileId: () => profileId,
      ),
      pinGuard: _pinGuard,
    );
  }

  List<Override> _buildOverrides(E2EIdentity? identity) {
    final profileId = identity?._resolvedProfileId ?? identity?._seedProfileId;
    final accountId = identity?._resolvedAccountId ?? identity?._seedAccountId;

    final seededProfiles = identity != null && profileId != null
        ? [
            LearnerProfileEntity(
              profileId: profileId,
              displayName: identity.displayName,
              mode:
                  ProfileMode.tryFromStorageKey(identity.profileMode) ??
                  ProfileMode.adult,
              avatar: '',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
            ),
          ]
        : <LearnerProfileEntity>[];

    final authState = identity != null
        ? AuthState.signedIn(
            user: AuthUser(
              uid: accountId!,
              email: identity.email,
              displayName: identity.displayName,
            ),
            tier: identity.tier,
          )
        : const AuthState.signedOut();

    return [
      // Override the content database with an in-memory NativeDatabase so
      // content-browsing and text-display journeys work without the bundled
      // seed file.  Seed rows via [seedContent] when a journey needs them.
      // contentDatabaseProvider is now a FutureProvider so use overrideWith.
      contentDatabaseProvider.overrideWith((ref) => Future.value(_contentDb)),

      // ── Auth ──────────────────────────────────────────────────────────────
      authStateProvider.overrideWithValue(authState),
      authRepositoryProvider.overrideWithValue(
        _StubAuthRepository(identity: identity, accountId: accountId),
      ),

      // ── Firestore identity ───────────────────────────────────────────────
      if (identity != null && profileId != null && accountId != null) ...[
        activeAccountIdProvider.overrideWith(
          () => _FixedActiveAccountId(accountId),
        ),
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => AccountFirebaseHandles(
            app: _FakeFirebaseApp(),
            firestore: _firestore,
            auth: _FakeFirebaseAuth(),
            uid: accountId,
          ),
        ),
        activeProfileDocIdProvider.overrideWith(
          () => _FixedActiveProfileDocId(profileId),
        ),
      ],

      // ── Profiles ─────────────────────────────────────────────────────────
      if (seededProfiles.isNotEmpty) ...[
        profileListStreamProvider.overrideWith(
          (ref) => Stream.value(seededProfiles),
        ),
      ],
      if (profileId != null) ...[
        activeProfileIdProvider.overrideWith(() => _FixedProfileId(profileId)),
        selectedProfileIdProvider.overrideWith(
          () => _FixedSelectedProfile(profileId),
        ),
      ],

      // ── PIN (no secure storage) ────────────────────────────────────────────
      flutterSecureStorageProvider.overrideWithValue(
        const FlutterSecureStorage(),
      ),
      pinServiceProvider.overrideWithValue(_NullPinService()),

      // ── Analytics (no-op) ─────────────────────────────────────────────────
      analyticsServiceProvider.overrideWithValue(const NullAnalyticsService()),

      // ── Magic link (instant no-op) ────────────────────────────────────────
      magicLinkInitializationProvider.overrideWith(
        (ref) => Future<void>.value(),
      ),

      // ── Streak milestone observer (no Firestore watch) ────────────────────
      streakMilestoneAnalyticsObserverProvider.overrideWith(
        (ref) => const Stream<void>.empty(),
      ),
    ];
  }

  MaterialApp _buildMaterialApp(
    RouterConfig<Object> routerConfig, [
    Locale locale = const Locale('en'),
  ]) {
    return MaterialApp.router(
      // Wire the root messenger key so SnackBar / MaterialBanner assertions
      // that target rootScaffoldMessengerKey (e.g. UpgradeToCloud banner)
      // work in the headless harness.
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: routerConfig,
      debugShowCheckedModeBanner: false,
      // Locale is injectable (defaults to en) so Hebrew-RTL journeys can pump
      // the app under Locale('he') and assert RTL + Hebrew l10n strings.
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
