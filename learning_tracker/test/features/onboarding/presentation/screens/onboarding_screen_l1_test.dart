// L1 widget tests for OnboardingScreen phase router.
//
// Coverage (new — does NOT duplicate onboarding_bulk_l1_test.dart):
//   • parentPinSetup phase: AppBar shows "Set Parent PIN", pin-entry present
//   • parentPinSetup phase: child path routes here after adult route does NOT
//   • intentChooser "Track my own learning" → transitions to addTrack phase
//   • intentChooser "Skip for now" → _navigateToDashboardSkipped: writes
//       kOnboardingComplete=true + kOnboardingSkipped=true + replaces to EmptyLoginRoute
//   • profileCreation skip ("Skip for now" link) → kOnboardingComplete=true
//       + kOnboardingSkipped=true + replaces to EmptyLoginRoute
//   • addAnotherPrompt: "Start Learning" button present (l10n) — transition to permissionPrompt
//   • addAnotherPrompt: "Add Another Track" button present (l10n) — transitions to addTrack
//   • handoff phase: "Add Another Learner" button present (l10n)
//   • handoff phase: "Add Another Learner" → resets to profileCreation (name field shown)
//   • done phase: renders "All set!" text (OnboardingDoneStep)
//   • done phase: AppBar shows "All Set!" title
//   • AppBar title per-phase: parentPinSetup="Set Parent PIN",
//       addAnotherPrompt="Track Ready!", handoff="Setup Complete!"
//   • AppBar absent at profileCreation (isCombinedProfilePhase=true)
//   • AppBar absent at intentChooser phase
//   • kOnboardingComplete set after navigateToDashboard (markComplete called)
//   • HE locale: parentPinSetup phase mounts without overflow
//   • HE locale: intentChooser phase mounts without overflow

@Tags(['onboarding'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart'
    show ActiveAccountId;
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AUD-onboarding-04: locale-driven lookup for the Hebrew AppBar-title
/// assertions below, so a regression that reintroduces a hardcoded English
/// literal (which would render identically regardless of locale) re-breaks
/// these tests instead of silently passing.
final _he = AppLocalizationsHe();

// ── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

// ── Stub notifiers ────────────────────────────────────────────────────────────

class _FakeAuthStateNotifier extends AuthStateNotifier {
  _FakeAuthStateNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _NullSelectedProfileId extends SelectedProfileId {
  @override
  String? build() => null;
}

class _FixedActiveAccountId extends ActiveAccountId {
  @override
  String? build() => 'account-1';
}

// ── Default signed-in state ───────────────────────────────────────────────────

const _kSignedIn = AuthState.signedIn(
  user: AuthUser(
    uid: 'account-1',
    email: 'test@test.com',
    displayName: 'Tester',
  ),
  tier: Tier.local,
);

// ── Test rig ─────────────────────────────────────────────────────────────────

Widget _rig({
  required _MockStackRouter router,
  AuthState? authState,
  _MockProfileRepository? profileRepo,
  Locale locale = const Locale('en'),
}) {
  final state = authState ?? _kSignedIn;
  final repo = profileRepo ?? _MockProfileRepository();
  when(() => repo.getProfiles()).thenAnswer((_) async => []);

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _FakeAuthStateNotifier(state)),
      profileRepositoryProvider.overrideWithValue(repo),
      selectedProfileIdProvider.overrideWith(() => _NullSelectedProfileId()),
      activeAccountIdProvider.overrideWith(() => _FixedActiveAccountId()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const OnboardingScreen(),
      ),
    ),
  );
}

/// Shared prefs snapshot that puts the screen at [phase].
Map<String, Object> _phasePrefs(
  String phase, {
  String profileId = 'ulid-2',
  String profileName = 'Moshe',
  String profileMode = 'adult',
}) => {
  'onboarding_phase': phase,
  'onboarding_profile_id': profileId,
  'onboarding_profile_name': profileName,
  'onboarding_profile_mode': profileMode,
  'onboarding_use_hebrew_calendar': true,
  'onboarding_use_hebrew_terms': true,
  'onboarding_show_nikud': true,
  'onboarding_transliteration_variant': 'ashkenazi',
};

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  late _MockStackRouter router;

  setUp(() {
    router = _MockStackRouter();
    when(() => router.replaceAll(any())).thenAnswer((_) async {});
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) async => null);
    SharedPreferences.setMockInitialValues({});
  });

  // ── parentPinSetup phase ─────────────────────────────────────────────────────

  group('parentPinSetup phase', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(
        _phasePrefs('parentPinSetup', profileMode: 'child'),
      );
    });

    testWidgets('AppBar title is "Set Parent PIN"', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Set Parent PIN'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('PinEntryWidget shows "Enter New PIN" sub-header', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // OnboardingParentPinStep renders PinEntryWidget with title "Enter New PIN"
      expect(find.text('Enter New PIN'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('does NOT show profile-creation name field', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Profile creation step has a TextField for the name.
      // At parentPinSetup we only expect the PinEntry numeric fields, not the
      // free-text name field.
      expect(find.text('What should we call you?'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('HE locale: mounts without overflow', (tester) async {
      SharedPreferences.setMockInitialValues(
        _phasePrefs('parentPinSetup', profileMode: 'child'),
      );
      await tester.pumpWidget(_rig(router: router, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);

      // AUD-onboarding-04: AppBar title and PinEntryWidget sub-header must
      // render in Hebrew, not the English literal (both used to be
      // hardcoded, so this smoke test previously passed regardless of
      // locale).
      expect(find.text(_he.setParentPinDialogTitle), findsOneWidget);
      expect(find.text(_he.enterNewPin), findsOneWidget);
      expect(find.text('Set Parent PIN'), findsNothing);
      expect(find.text('Enter New PIN'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── intentChooser phase ───────────────────────────────────────────────────

  group('intentChooser phase', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(_phasePrefs('intentChooser'));
    });

    testWidgets('AppBar is absent at intentChooser (showAppBar=false)', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The intentChooser hides the app bar. There should be no AppBar with a
      // title. The "What brings you here?" header is inside the step body.
      expect(find.byType(AppBar), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('"Track my own learning" tap transitions to addTrack phase', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Sanity: we are in intentChooser
      expect(find.text('What brings you here?'), findsOneWidget);

      await tester.tap(find.text('Track my own learning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // After choosing "Track my own learning" we are in addTrack phase.
      // The profile-creation header should be gone; no "What brings you here?"
      expect(find.text('What brings you here?'), findsNothing);
      // The addTrack phase suppresses the app bar — no "Set Up a Track" shown
      // in the AppBar, but the switch has happened (no intent chooser text).
      expect(find.text('What should we call you?'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets(
      '"Skip for now" writes kOnboardingComplete + kOnboardingSkipped',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('Skip for now'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(kOnboardingComplete),
          isTrue,
          reason: 'kOnboardingComplete must be set after skip',
        );
        expect(
          prefs.getBool(kOnboardingSkipped),
          isTrue,
          reason: 'kOnboardingSkipped must be set when skipping',
        );

        await _tearDown(tester);
      },
    );

    testWidgets('"Skip for now" calls router.replaceAll to EmptyLoginRoute', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Skip for now'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(() => router.replaceAll(captureAny())).captured;
      expect(captured.isNotEmpty, isTrue);
      final routes = captured.first as List<dynamic>;
      expect(routes.first, isA<EmptyLoginRoute>());

      await _tearDown(tester);
    });

    testWidgets('HE locale: intentChooser mounts without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      // Intent chooser header
      expect(find.text('מה מביא אותך לכאן?'), findsNothing);
      // At minimum the scaffold renders
      expect(find.byType(Scaffold), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── profileCreation skip path ─────────────────────────────────────────────

  group('profileCreation skip path (WS2.skip)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('"Skip for now" link is present at profileCreation phase', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The skip link is rendered via onSkipProfileCreation callback
      expect(find.text('Skip for now'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets(
      '"Skip for now" at profileCreation writes kOnboardingComplete',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // The "Skip for now" button is inside a SingleChildScrollView.
        // We use ensureVisible to scroll it into the viewport before tapping.
        await tester.ensureVisible(find.text('Skip for now'));
        await tester.pump();
        await tester.tap(find.text('Skip for now'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(kOnboardingComplete),
          isTrue,
          reason: 'kOnboardingComplete must be set',
        );
        expect(
          prefs.getBool(kOnboardingSkipped),
          isTrue,
          reason:
              'kOnboardingSkipped must be set when skipping profile creation',
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      '"Skip for now" at profileCreation navigates to EmptyLoginRoute',
      (tester) async {
        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.ensureVisible(find.text('Skip for now'));
        await tester.pump();
        await tester.tap(find.text('Skip for now'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        final captured = verify(() => router.replaceAll(captureAny())).captured;
        expect(captured.isNotEmpty, isTrue);
        final routes = captured.first as List<dynamic>;
        expect(routes.first, isA<EmptyLoginRoute>());

        await _tearDown(tester);
      },
    );
  });

  // ── addAnotherPrompt phase ─────────────────────────────────────────────────

  group('addAnotherPrompt phase', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(_phasePrefs('addAnotherPrompt'));
    });

    testWidgets('AppBar title is "Track Ready!"', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Track Ready!'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Start Learning" button (l10n) is present', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Start Learning'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Add Another Track" button (l10n) is present', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add Another Track'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Add Another Track" tap transitions back to addTrack phase', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // "Track Ready!" means we are in addAnotherPrompt
      expect(find.text('Track Ready!'), findsOneWidget);

      await tester.tap(find.text('Add Another Track'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // After tapping "Add Another Track" the phase moves to addTrack.
      // addTrack has no AppBar → "Track Ready!" disappears.
      expect(find.text('Track Ready!'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('"Start Learning" tap transitions away from addAnotherPrompt', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Track Ready!'), findsOneWidget);

      await tester.tap(find.text('Start Learning'));
      await tester.pump();
      // permissionPrompt phase shows SizedBox.shrink while pushing a route.
      await tester.pump(const Duration(milliseconds: 500));

      // "Track Ready!" is no longer present — phase has advanced.
      expect(find.text('Track Ready!'), findsNothing);

      await _tearDown(tester);
    });

    // AUD-onboarding-04: locale-driven lookup (was a hardcoded English
    // literal that rendered under any locale).
    testWidgets('HE locale: AppBar title renders in Hebrew, not English', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_he.onboardingTrackReadyTitle), findsOneWidget);
      expect(find.text('Track Ready!'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── handoff phase ─────────────────────────────────────────────────────────

  group('handoff phase', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(
        _phasePrefs(
          'handoff',
          profileId: 'ulid-4',
          profileName: 'Yitzchak',
          profileMode: 'child',
        ),
      );
    });

    testWidgets('AppBar title is "Setup Complete!"', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Setup Complete!'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Add Another Learner" button is present (l10n)', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add Another Learner'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Add Another Learner" tap resets to profileCreation phase', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Setup Complete!'), findsOneWidget);

      await tester.tap(find.text('Add Another Learner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // profileCreation phase shows name field
      expect(find.text('What should we call you?'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Start Learning" button is present at handoff', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Start Learning'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('"Add Another Track" button is present at handoff', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add Another Track'), findsOneWidget);

      await _tearDown(tester);
    });

    // Regression (cycle-3 P2): on a fresh single-profile signup, tapping
    // "Start Learning" must land directly on the dashboard (AppShellRoute) AND
    // select the just-created profile in-memory first, so the AppShellRoute
    // guard chain (AuthGuard / ProfileGuard) does NOT bounce the brand-new user
    // to the "Choose an Account" picker as an extra confusing step.
    testWidgets(
      '"Start Learning" selects the created profile + replaces to AppShellRoute',
      (tester) async {
        // Single profile on the account → the direct-to-dashboard branch.
        final repo = _MockProfileRepository();
        final now = DateTime(2026, 1, 1);
        when(() => repo.getProfiles()).thenAnswer(
          (_) async => [
            LearnerProfileEntity(
              profileId: 'ulid-4', // matches onboarding_profile_id in this group's prefs
              displayName: 'Yitzchak',
              mode: ProfileMode.child,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        // Hold a container so we can read the selected-profile state after the
        // navigation runs. Use the real SelectedProfileId notifier (not the
        // null stub) so select() actually mutates state.
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith(
              () => _FakeAuthStateNotifier(_kSignedIn),
            ),
            profileRepositoryProvider.overrideWithValue(repo),
            activeAccountIdProvider.overrideWith(() => _FixedActiveAccountId()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: StackRouterScope(
                controller: router,
                stateHash: 0,
                child: const OnboardingScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Sanity: no profile selected yet at the handoff screen.
        expect(container.read(selectedProfileIdProvider), isNull);

        await tester.tap(find.text('Start Learning'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The created profile is now selected — ProfileGuard short-circuits
        // (profile_guard_already_selected) instead of bouncing to a picker.
        expect(container.read(selectedProfileIdProvider), 'ulid-4');

        // And navigation lands directly on the dashboard, NOT the account/profile
        // picker.
        final captured = verify(() => router.replaceAll(captureAny())).captured;
        expect(captured.isNotEmpty, isTrue);
        final routes = captured.last as List<dynamic>;
        expect(routes.first, isA<AppShellRoute>());

        await _tearDown(tester);
      },
    );

    // AUD-onboarding-04: locale-driven lookup (was a hardcoded English
    // literal that rendered under any locale).
    testWidgets('HE locale: AppBar title renders in Hebrew, not English', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_he.setupComplete), findsOneWidget);
      expect(find.text('Setup Complete!'), findsNothing);
      // OnboardingHandoffStep body text (AUD-onboarding-04): was hardcoded
      // English, now resolved through l10n for the 'Yitzchak' profile name
      // seeded by this group's prefs.
      expect(
        find.text(_he.onboardingHandoffAllSetUp('Yitzchak')),
        findsOneWidget,
      );
      expect(
        find.text(_he.onboardingHandoffDeviceHint('Yitzchak')),
        findsOneWidget,
      );
      expect(find.text(_he.onboardingHandoffRewardsHint), findsOneWidget);
      expect(find.textContaining('learning is all set up'), findsNothing);
      expect(find.textContaining('Hand the device to'), findsNothing);
      expect(
        find.text('You can set up rewards later in Parent Mode'),
        findsNothing,
      );

      await _tearDown(tester);
    });
  });

  // ── done phase ────────────────────────────────────────────────────────────

  group('done phase', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(_phasePrefs('done'));
    });

    testWidgets('AppBar title is "All Set!"', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('All Set!'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('renders "All set!" text from OnboardingDoneStep (l10n)', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n key allSet = "All set!"
      expect(find.text('All set!'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('renders check icon in done phase', (tester) async {
      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await _tearDown(tester);
    });

    // AUD-onboarding-04: locale-driven lookup (was a hardcoded English
    // literal that rendered under any locale).
    testWidgets('HE locale: AppBar title renders in Hebrew, not English', (
      tester,
    ) async {
      await tester.pumpWidget(_rig(router: router, locale: const Locale('he')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_he.onboardingAllSetTitle), findsOneWidget);
      expect(find.text('All Set!'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── AppBar visibility logic ───────────────────────────────────────────────

  group('AppBar visibility per phase', () {
    testWidgets('AppBar absent at profileCreation (isCombinedProfilePhase)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppBar), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('AppBar present at parentPinSetup with correct title', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(
        _phasePrefs('parentPinSetup', profileMode: 'child'),
      );

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Set Parent PIN'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('AppBar present at addAnotherPrompt with "Track Ready!"', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(_phasePrefs('addAnotherPrompt'));

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Track Ready!'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('AppBar present at handoff with "Setup Complete!"', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(
        _phasePrefs('handoff', profileMode: 'child'),
      );

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Setup Complete!'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('AppBar present at done with "All Set!"', (tester) async {
      SharedPreferences.setMockInitialValues(_phasePrefs('done'));

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('All Set!'), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── kOnboardingComplete written on markComplete ───────────────────────────

  group('kOnboardingComplete persistence', () {
    testWidgets('skip from intentChooser writes kOnboardingComplete=true', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(_phasePrefs('intentChooser'));

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Skip for now'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kOnboardingComplete), isTrue);

      await _tearDown(tester);
    });

    testWidgets(
      'kOnboardingJoinedToTutor=false when skipping, not joining tutor',
      (tester) async {
        SharedPreferences.setMockInitialValues(_phasePrefs('intentChooser'));

        await tester.pumpWidget(_rig(router: router));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('Skip for now'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final prefs = await SharedPreferences.getInstance();
        // "Skip for now" passes joinedToTutor: false
        expect(prefs.getBool(kOnboardingJoinedToTutor), isFalse);

        await _tearDown(tester);
      },
    );
  });

  // ── permissionPrompt phase shows SizedBox.shrink ─────────────────────────

  group('permissionPrompt phase', () {
    testWidgets('Scaffold renders without crash when permissionPrompt phase', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(_phasePrefs('permissionPrompt'));
      // permissionPrompt pushes a route via addPostFrameCallback.
      // In tests the StackRouter mock absorbs the push call.
      when(
        () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('AppBar is absent at permissionPrompt (showAppBar=false)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(_phasePrefs('permissionPrompt'));

      await tester.pumpWidget(_rig(router: router));
      await tester.pump();

      // No AppBar at permissionPrompt phase
      expect(find.byType(AppBar), findsNothing);

      await _tearDown(tester);
    });
  });
}
