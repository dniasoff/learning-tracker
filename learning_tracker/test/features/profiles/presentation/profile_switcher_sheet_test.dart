/// Widget tests for the canonical profile switcher/manager flow:
///   • Tapping the Settings profile header opens the ACCOUNT actions sheet
///     (account/profile separation); the switcher itself is tested directly.
///   • The sheet lists every profile (with a child/adult label), the active
///     one is marked, and it exposes Add + per-row Edit/Delete affordances.
///   • Tapping a non-active profile switches the active profile via
///     selectedProfileIdProvider + a shell reload.
///   • The "Parent mode — viewing [child]" banner derivation only triggers
///     when an adult is active in a child profile, and exposes an explicit
///     "Exit parent mode" button.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockProfileRepo extends Mock implements ProfileRepository {}

LearnerProfileEntity _profile({
  required String id,
  required String name,
  required String mode,
}) => LearnerProfileEntity(
  profileId: id,
  displayName: name,
  mode: ProfileMode.fromStorageKey(mode),
  avatar: '',
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

Widget _wrap({
  required Widget child,
  required List<LearnerProfileEntity> profiles,
  String? selectedProfileId,
  StackRouter? router,
}) {
  final mockRouter = router ?? _MockStackRouter();
  return pumpApp(
    overrides: [
      profileListStreamProvider.overrideWith((ref) => Stream.value(profiles)),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(selectedProfileId),
      ),
      authStateProvider.overrideWithValue(
        const AuthState.signedIn(
          user: AuthUser(
            uid: 'account-1',
            email: 'test@test.com',
            displayName: 'Test',
          ),
          tier: Tier.local,
        ),
      ),
    ],
    child: StackRouterScope(
      controller: mockRouter,
      stateHash: 0,
      child: Scaffold(body: child),
    ),
  );
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final String? _initial;
  @override
  String? build() => _initial;
}

void main() {
  setUpAll(() {
    // mocktail needs a concrete fallback for the PageRouteInfo arg used by
    // StackRouter.push(any()) in the FIX#8 Skip-to-Settings test.
    registerFallbackValue(const SettingsRoute());
    // mocktail needs a concrete fallback for the ProfileMode arg used by
    // ProfileRepository.createProfile(mode: any()) in the D4-regression test.
    registerFallbackValue(ProfileMode.adult);
  });

  group('Profile header tap → switcher sheet', () {
    testWidgets('tapping the Settings profile header opens the account sheet', (
      tester,
    ) async {
      final profiles = [
        _profile(id: 'ulid-1', name: 'Avi', mode: 'adult'),
        _profile(id: 'ulid-2', name: 'Beni', mode: 'child'),
      ];
      final mockAuth = _MockAuthRepository();
      when(() => mockAuth.currentUser).thenReturn(null);

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(profiles),
            ),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId('ulid-1'),
            ),
            authRepositoryProvider.overrideWithValue(mockAuth),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  uid: 'account-1',
                  email: 'avi@test.com',
                  displayName: 'Avi',
                ),
                tier: Tier.local,
              ),
            ),
          ],
          child: const Scaffold(
            body: UserProfileHeaderCard(
              user: AppUser(
                uid: 'u1',
                email: 'avi@test.com',
                displayName: 'Avi',
                emailVerified: true,
                providers: ['password'],
              ),
              surface: UserProfileHeaderSurface.settings,
            ),
          ),
        ),
      );
      await tester.pump();

      // Sheet not yet shown.
      expect(find.text('ACCOUNT'), findsNothing);

      await tester.tap(find.text('Avi'));
      await tester.pumpAndSettle();

      // Tapping the Settings profile header opens the ACCOUNT actions sheet
      // (account/profile separation) — NOT the profile switcher. The sheet
      // shows the ACCOUNT section with switch-account + sign-out.
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Switch account'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });

  group('ProfileSwitcherSheet contents', () {
    testWidgets('lists profiles with child/adult labels, marks active, exposes '
        'add + edit/delete affordances', (tester) async {
      final profiles = [
        _profile(id: 'ulid-1', name: 'Avi', mode: 'adult'),
        _profile(id: 'ulid-2', name: 'Beni', mode: 'child'),
      ];

      await tester.pumpWidget(
        _wrap(
          profiles: profiles,
          selectedProfileId: 'ulid-1',
          child: const ProfileSwitcherSheet(),
        ),
      );
      await tester.pump();

      // Both profiles listed.
      expect(find.text('Avi'), findsOneWidget);
      expect(find.text('Beni'), findsOneWidget);

      // Localized type labels (NOT raw enum).
      expect(find.text('Adult'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);

      // Active profile is marked with a check.
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Add entry present.
      expect(find.text('Add Profile'), findsOneWidget);

      // Per-row edit + delete affordances (one each per profile row).
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));
    });

    testWidgets('FIX#8: exposes a "Skip to Settings" affordance that routes to '
        'SettingsRoute', (tester) async {
      final mockRouter = _MockStackRouter();
      when(() => mockRouter.push(any())).thenAnswer((_) async => null);

      final profiles = [_profile(id: 'ulid-1', name: 'Avi', mode: 'adult')];

      await tester.pumpWidget(
        _wrap(
          profiles: profiles,
          selectedProfileId: 'ulid-1',
          router: mockRouter,
          child: const ProfileSwitcherSheet(),
        ),
      );
      await tester.pump();

      // The Settings affordance is present (keyed + localized label).
      final skip = find.byKey(const Key('switcherSheetSkipToSettings'));
      expect(skip, findsOneWidget);
      expect(find.text('Skip to Settings'), findsOneWidget);

      await tester.tap(skip);
      await tester.pump();

      // Routes to the Settings shell tab.
      final pushed = verify(() => mockRouter.push(captureAny())).captured;
      expect(pushed.single, isA<SettingsRoute>());
    });

    testWidgets(
      'tapping a non-active profile switches the active profile and reloads '
      'the shell',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

        final profiles = [
          _profile(id: 'ulid-1', name: 'Avi', mode: 'adult'),
          _profile(id: 'ulid-2', name: 'Beni', mode: 'child'),
        ];

        late ProviderContainer container;
        await tester.pumpWidget(
          pumpApp(
            overrides: [
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(profiles),
              ),
              selectedProfileIdProvider.overrideWith(
                () => _FixedSelectedProfileId('ulid-1'),
              ),
              authStateProvider.overrideWithValue(
                const AuthState.signedIn(
                  user: AuthUser(
                    uid: 'account-1',
                    email: 'test@test.com',
                    displayName: 'Test',
                  ),
                  tier: Tier.local,
                ),
              ),
            ],
            child: StackRouterScope(
              controller: mockRouter,
              stateHash: 0,
              child: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return const Scaffold(body: ProfileSwitcherSheet());
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(container.read(selectedProfileIdProvider), 'ulid-1');

        // Tap the non-active child profile → enters parent-mode for Beni.
        await tester.tap(find.text('Beni'));
        await tester.pump();

        expect(container.read(selectedProfileIdProvider), 'ulid-2');
        verify(() => mockRouter.replaceAll(any())).called(1);
      },
    );
  });

  group('Parent-mode banner derivation + exit', () {
    /// Mirrors the AppShell derivation: banner shows only when an adult owns the
    /// account AND the active profile is a child (parent mode for that child).
    bool adultIsViewingChild(
      List<LearnerProfileEntity> profiles,
      String activeId,
    ) {
      final active = profiles.where((p) => p.profileId == activeId).firstOrNull;
      final hasAdult = profiles.any((p) => p.mode == ProfileMode.adult);
      return active?.mode == ProfileMode.child && hasAdult;
    }

    test('triggers when an adult is active in a child profile', () {
      final profiles = [
        _profile(id: 'ulid-1', name: 'Avi', mode: 'adult'),
        _profile(id: 'ulid-2', name: 'Beni', mode: 'child'),
      ];
      expect(adultIsViewingChild(profiles, 'ulid-2'), isTrue);
    });

    test('does NOT trigger for an adult in their own adult profile', () {
      final profiles = [
        _profile(id: 'ulid-1', name: 'Avi', mode: 'adult'),
        _profile(id: 'ulid-2', name: 'Beni', mode: 'child'),
      ];
      expect(adultIsViewingChild(profiles, 'ulid-1'), isFalse);
    });

    test('does NOT trigger for a standalone child account (no adult)', () {
      final profiles = [_profile(id: 'ulid-2', name: 'Beni', mode: 'child')];
      expect(adultIsViewingChild(profiles, 'ulid-2'), isFalse);
    });

    testWidgets('exit-parent-mode label resolves to "Exit parent mode"', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpApp(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Column(
                  children: [
                    Text(l10n.viewingChildBanner('Beni')),
                    Text(l10n.viewingChildBannerExit),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Parent mode — viewing Beni'), findsOneWidget);
      expect(find.text('Exit parent mode'), findsOneWidget);
    });
  });

  // D4 regression: tapping "Add Profile" used to pop the sheet first, unmounting
  // its context/ref so showAddProfileDialog's mounted-guard bailed before
  // createProfile — Add Profile silently created nothing. The fix keeps the
  // sheet mounted while the dialog runs.
  group('Add Profile from switcher (D4 regression)', () {
    testWidgets('keeps the sheet mounted and actually invokes createProfile', (
      tester,
    ) async {
      final repo = _MockProfileRepo();
      when(
        () => repo.createProfile(
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer(
        (_) async => _profile(id: 'ulid-9', name: 'Newbie', mode: 'adult'),
      );

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value([
                _profile(id: 'ulid-1', name: 'Avi', mode: 'adult'),
              ]),
            ),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId('ulid-1'),
            ),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  uid: 'account-1',
                  email: 'avi@test.com',
                  displayName: 'Avi',
                ),
                tier: Tier.local,
              ),
            ),
            profileListProvider.overrideWith(
              (ref) async => [
                _profile(id: 'ulid-1', name: 'Avi', mode: 'adult'),
              ],
            ),
            profileRepositoryProvider.overrideWithValue(repo),
          ],
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_switcher'),
                  onPressed: () => showProfileSwitcherSheet(ctx),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_switcher')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSwitcherSheet), findsOneWidget);

      await tester.tap(find.text('Add Profile'));
      await tester.pumpAndSettle();

      // Sheet NOT popped before the dialog → dialog shown over a still-mounted
      // sheet (the fix); both are present.
      expect(find.byType(ProfileSwitcherSheet), findsOneWidget);
      expect(find.text('Create Profile'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Newbie');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Create Profile'));
      await tester.pumpAndSettle();

      // The actual regression guard: createProfile WAS invoked (not silent).
      verify(
        () => repo.createProfile(
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
        ),
      ).called(1);
      expect(find.text('An unexpected error occurred.'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
