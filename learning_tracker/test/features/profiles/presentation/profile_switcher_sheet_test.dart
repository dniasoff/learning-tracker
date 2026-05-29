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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_switcher_sheet.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/user_profile_header_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAuthRepository extends Mock implements AuthRepository {}

ProfileModel _profile({
  required int id,
  required String name,
  required String mode,
}) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: name,
  mode: mode,
  avatarIndex: 0,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

Widget _wrap({
  required Widget child,
  required List<ProfileModel> profiles,
  int? selectedProfileId,
  StackRouter? router,
}) {
  final mockRouter = router ?? _MockStackRouter();
  return ProviderScope(
    overrides: [
      profileListStreamProvider.overrideWith((ref) => Stream.value(profiles)),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(selectedProfileId),
      ),
      authStateProvider.overrideWithValue(
        const AuthState.signedIn(
          user: AuthUser(
            profileId: 1,
            email: 'test@test.com',
            displayName: 'Test',
          ),
          tier: Tier.localBorn,
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: mockRouter,
        stateHash: 0,
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

void main() {
  group('Profile header tap → switcher sheet', () {
    testWidgets('tapping the Settings profile header opens the account sheet', (
      tester,
    ) async {
      final profiles = [
        _profile(id: 1, name: 'Avi', mode: 'adult'),
        _profile(id: 2, name: 'Beni', mode: 'child'),
      ];
      final mockAuth = _MockAuthRepository();
      when(() => mockAuth.currentUser).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileListStreamProvider.overrideWith(
              (ref) => Stream.value(profiles),
            ),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(1),
            ),
            authRepositoryProvider.overrideWithValue(mockAuth),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  profileId: 1,
                  email: 'avi@test.com',
                  displayName: 'Avi',
                ),
                tier: Tier.localBorn,
              ),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
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
        _profile(id: 1, name: 'Avi', mode: 'adult'),
        _profile(id: 2, name: 'Beni', mode: 'child'),
      ];

      await tester.pumpWidget(
        _wrap(
          profiles: profiles,
          selectedProfileId: 1,
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

    testWidgets(
      'tapping a non-active profile switches the active profile and reloads '
      'the shell',
      (tester) async {
        final mockRouter = _MockStackRouter();
        when(() => mockRouter.replaceAll(any())).thenAnswer((_) async {});

        final profiles = [
          _profile(id: 1, name: 'Avi', mode: 'adult'),
          _profile(id: 2, name: 'Beni', mode: 'child'),
        ];

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(profiles),
              ),
              selectedProfileIdProvider.overrideWith(
                () => _FixedSelectedProfileId(1),
              ),
              authStateProvider.overrideWithValue(
                const AuthState.signedIn(
                  user: AuthUser(
                    profileId: 1,
                    email: 'test@test.com',
                    displayName: 'Test',
                  ),
                  tier: Tier.localBorn,
                ),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: StackRouterScope(
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
          ),
        );
        await tester.pump();

        expect(container.read(selectedProfileIdProvider), 1);

        // Tap the non-active child profile → enters parent-mode for Beni.
        await tester.tap(find.text('Beni'));
        await tester.pump();

        expect(container.read(selectedProfileIdProvider), 2);
        verify(() => mockRouter.replaceAll(any())).called(1);
      },
    );
  });

  group('Parent-mode banner derivation + exit', () {
    /// Mirrors the AppShell derivation: banner shows only when an adult owns the
    /// account AND the active profile is a child (parent mode for that child).
    bool adultIsViewingChild(List<ProfileModel> profiles, int activeId) {
      final active = profiles.where((p) => p.id == activeId).firstOrNull;
      final hasAdult = profiles.any((p) => p.profileMode == ProfileMode.adult);
      return active?.profileMode == ProfileMode.child && hasAdult;
    }

    test('triggers when an adult is active in a child profile', () {
      final profiles = [
        _profile(id: 1, name: 'Avi', mode: 'adult'),
        _profile(id: 2, name: 'Beni', mode: 'child'),
      ];
      expect(adultIsViewingChild(profiles, 2), isTrue);
    });

    test('does NOT trigger for an adult in their own adult profile', () {
      final profiles = [
        _profile(id: 1, name: 'Avi', mode: 'adult'),
        _profile(id: 2, name: 'Beni', mode: 'child'),
      ];
      expect(adultIsViewingChild(profiles, 1), isFalse);
    });

    test('does NOT trigger for a standalone child account (no adult)', () {
      final profiles = [_profile(id: 2, name: 'Beni', mode: 'child')];
      expect(adultIsViewingChild(profiles, 2), isFalse);
    });

    testWidgets('exit-parent-mode label resolves to "Exit parent mode"', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
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
}
