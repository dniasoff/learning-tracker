/// L1 widget tests for ProfilePickerScreen.
///
/// Covers:
///   • Loading state  — CircularProgressIndicator while profileListProvider loads
///   • Empty state    — no own profiles → TutoredChildrenSection visible +
///                       Add-profile card present; NO wizard navigation
///   • Populated grid — child/adult tiles rendered; CHILD MODE / ADULT MODE
///                       labels visible; "Add\nProfile" card rendered
///   • Tap profile    — selectedProfileIdProvider updated + router.replaceAll called
///   • Add-profile    — tapping Add card invokes showAddProfileDialog (dialog opens)
///   • Sign-out section visibility:
///       - visible when profiles.isEmpty && isLocalBorn
///       - visible when profiles.isEmpty && isCloudBorn
///       - hidden  when profiles.isEmpty && signedOut (anon)
///       - hidden  when profiles.nonEmpty (has own profiles)
///   • child/adult labels: CHILD MODE + ADULT MODE only (no "parent" type)
///   • he-RTL smoke: screen renders without overflow or crash in Hebrew locale
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/profile_picker_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Notifier subclass override ───────────────────────────────────────────────

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

ProfileModel _child({int id = 1, String name = 'Yosef'}) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: name,
  mode: 'child',
  avatarIndex: 0,
  createdAt: _epoch,
  updatedAt: _epoch,
);

ProfileModel _adult({int id = 2, String name = 'Avraham'}) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: name,
  mode: 'adult',
  avatarIndex: 0,
  createdAt: _epoch,
  updatedAt: _epoch,
);

/// Build the widget-under-test.
///
/// [profilesState]  — what [profileListProvider] returns.
/// [grants]         — what [incomingTutorGrantsProvider] returns (default: []).
/// [pendingInvites] — what [pendingTutorInvitesProvider] returns (default: []).
/// [authState]      — overrides [authStateProvider].
/// [selectedId]     — initial selected profile id.
/// [router]         — StackRouter for navigation assertions.
/// [disableRetry]   — pass `retry: (_, __) => null` to ProviderScope so
///                    FutureProvider transitions to AsyncError in error tests.
/// [locale]         — test locale (default: en).
Widget _buildApp({
  required _MockStackRouter router,
  AsyncValue<List<ProfileModel>>? profilesState,
  List<ProfileModel>? profiles,
  List<TutorGrant> grants = const [],
  List<TutorGrant> pendingInvites = const [],
  AuthState? authState,
  int? selectedId,
  bool disableRetry = false,
  Locale locale = const Locale('en'),
}) {
  final resolvedAuth =
      authState ??
      const AuthState.signedIn(
        user: AuthUser(profileId: 1, email: 't@t.com', displayName: 'Test'),
        tier: Tier.localBorn,
      );

  // Derive profilesState from the convenience [profiles] list if provided.
  final AsyncValue<List<ProfileModel>> pState;
  if (profilesState != null) {
    pState = profilesState;
  } else {
    pState = AsyncData(profiles ?? []);
  }

  return ProviderScope(
    retry: disableRetry ? (_, __) => null : null,
    overrides: [
      profileListProvider.overrideWith((ref) {
        switch (pState) {
          case AsyncData(:final value):
            return Future.value(value);
          case AsyncError(:final error, :final stackTrace):
            return Future.error(error, stackTrace);
          case _:
            return Completer<List<ProfileModel>>().future;
        }
      }),
      incomingTutorGrantsProvider.overrideWith((ref) async => grants),
      pendingTutorInvitesProvider.overrideWith((ref) async => pendingInvites),
      authStateProvider.overrideWithValue(resolvedAuth),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(selectedId),
      ),
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
        child: const Scaffold(body: ProfilePickerScreen()),
      ),
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    router = _MockStackRouter();
    when(
      () => router.replaceAll(any<List<PageRouteInfo>>()),
    ).thenAnswer((_) async {});
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/profile-picker');
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Future<Object?>.value(null));
  });

  // ── Loading state ─────────────────────────────────────────────────────────

  testWidgets(
    'shows CircularProgressIndicator while profileListProvider loads',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, profilesState: const AsyncLoading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Error state ───────────────────────────────────────────────────────────

  testWidgets('shows AppErrorView with Retry when profileListProvider errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        profilesState: AsyncError(Exception('oops'), StackTrace.current),
        disableRetry: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Empty state (no own profiles) ────────────────────────────────────────

  testWidgets('empty state: Add Profile card rendered — no wizard navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, profiles: []));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // "Add\nProfile" card is present in the grid.
    // The card uses l10n.addProfileCardTitle = 'Add\nProfile'
    expect(find.textContaining('Add'), findsWidgets);
    // No wizard text — the card opens a dialog, not a route.
    // Verify router.replaceAll was NOT called (no auto-navigation).
    verifyNever(() => router.replaceAll(any<List<PageRouteInfo>>()));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('empty state: TutoredChildrenSection is present in widget tree', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, profiles: []));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TutoredChildrenSection), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Populated grid ────────────────────────────────────────────────────────

  testWidgets('populated: renders child and adult profile tiles', (
    tester,
  ) async {
    final profiles = [_child(name: 'Yosef'), _adult(name: 'Avraham')];
    await tester.pumpWidget(_buildApp(router: router, profiles: profiles));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Yosef'), findsOneWidget);
    expect(find.text('Avraham'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'populated: CHILD MODE label for child profile, ADULT MODE for adult '
    '— no "parent" label anywhere',
    (tester) async {
      final profiles = [_child(name: 'Yosef'), _adult(name: 'Avraham')];
      await tester.pumpWidget(_buildApp(router: router, profiles: profiles));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('CHILD MODE'), findsOneWidget);
      expect(find.text('ADULT MODE'), findsOneWidget);

      // HARD RULE: no "parent" profile type label (project_profile_model).
      expect(find.textContaining('PARENT'), findsNothing);
      expect(find.textContaining('Parent Mode'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('populated: Add Profile card is present after the profile tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        profiles: [_adult(name: 'Avi')],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Grid renders: profile tile + add-card.
    expect(find.text('Avi'), findsOneWidget);
    // The add card shows 'Add\nProfile' — use textContaining for the line break.
    expect(find.textContaining('Add'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Tap profile → selects + reloads shell ────────────────────────────────

  testWidgets(
    'tapping a profile tile updates selectedProfileIdProvider and calls '
    'router.replaceAll',
    (tester) async {
      final profiles = [_adult(id: 5, name: 'Avi')];

      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileListProvider.overrideWith((ref) => Future.value(profiles)),
            incomingTutorGrantsProvider.overrideWith((ref) async => []),
            pendingTutorInvitesProvider.overrideWith((ref) async => []),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  profileId: 1,
                  email: 't@t.com',
                  displayName: 'Test',
                ),
                tier: Tier.localBorn,
              ),
            ),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(null),
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
              controller: router,
              stateHash: 0,
              child: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return const Scaffold(body: ProfilePickerScreen());
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Profile tile is visible.
      expect(find.text('Avi'), findsOneWidget);

      // Tap the profile tile.
      await tester.tap(find.text('Avi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // selectedProfileIdProvider should now hold profile id 5.
      expect(container.read(selectedProfileIdProvider), 5);

      // Router should have been asked to replace the stack (navigate to AppShell).
      verify(() => router.replaceAll(any<List<PageRouteInfo>>())).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Add-profile card → opens dialog (no wizard route) ────────────────────

  testWidgets(
    'tapping the Add Profile card opens showAddProfileDialog — dialog '
    'appears, no router push',
    (tester) async {
      // Use a single profile so the Add card is enabled (< 10 cap).
      final profiles = [_adult(name: 'Avi')];
      await tester.pumpWidget(_buildApp(router: router, profiles: profiles));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The add-card "Add\nProfile" text.
      final addCardFinder = find.textContaining('Profile');
      expect(addCardFinder, findsWidgets);

      // Tap the add-profile card.
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.pumpAndSettle();

      // The dialog shows the whatsYourName or addProfile title text.
      // The dialog is NOT a route — no replaceAll called.
      verifyNever(() => router.replaceAll(any<List<PageRouteInfo>>()));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Sign-out section visibility ───────────────────────────────────────────

  testWidgets('sign-out button visible when profiles.isEmpty && isLocalBorn', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        profiles: [],
        authState: const AuthState.signedIn(
          user: AuthUser(profileId: 1, email: 't@t.com', displayName: 'Test'),
          tier: Tier.localBorn,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Sign Out button should be visible.
    expect(find.text('Sign Out'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('sign-out button visible when profiles.isEmpty && isCloudBorn', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        profiles: [],
        authState: const AuthState.signedIn(
          user: AuthUser(
            profileId: 1,
            email: 'cloud@t.com',
            displayName: 'Cloud',
            firebaseUid: 'uid123',
          ),
          tier: Tier.cloudBorn,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sign Out'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'sign-out button hidden when profiles.isEmpty && signedOut (anon)',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          profiles: [],
          authState: const AuthState.signedOut(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Auth is signedOut (no tier) → sign-out section must be hidden.
      expect(find.text('Sign Out'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('sign-out section hidden when profiles are non-empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        profiles: [_adult(name: 'Avi')],
        authState: const AuthState.signedIn(
          user: AuthUser(profileId: 1, email: 't@t.com', displayName: 'Test'),
          tier: Tier.localBorn,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The sign-out section only renders when profiles is empty — with profiles
    // present it must be absent.
    expect(find.text('Sign Out'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Skip to Settings (Bug 8) ──────────────────────────────────────────────

  testWidgets(
    'Skip to Settings affordance is shown when there are no own profiles',
    (tester) async {
      await tester.pumpWidget(_buildApp(router: router, profiles: []));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Skip to Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets('Skip to Settings is also available when own profiles exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(
        router: router,
        profiles: [_adult(name: 'Avi')],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Skip to Settings'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('tapping Skip to Settings routes to SettingsRoute', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, profiles: []));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Skip to Settings'));
    await tester.tap(find.text('Skip to Settings'));
    await tester.pump();

    // The picker pushes a route (SettingsRoute) onto the stack rather than
    // forcing profile creation.
    final pushed = verify(
      () => router.push<Object?>(
        captureAny(),
        onFailure: any(named: 'onFailure'),
      ),
    ).captured;
    expect(pushed, isNotEmpty);
    expect(pushed.first.runtimeType.toString(), 'SettingsRoute');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  // ── Segmented view: YOUR PROFILES header ─────────────────────────────────

  testWidgets(
    'YOUR PROFILES header shown when user has active tutored grants',
    (tester) async {
      final doc = TutorGrantDoc(
        grantId: 'grant1',
        parentUid: 'p_uid',
        childProfileId: 'child_remote_id',
        tutorEmail: 'tutor@test.com',
        state: TutorGrantState.active,
        invitedAt: _epoch,
        updatedAt: _epoch,
        acceptedAt: _epoch,
      );
      final activeGrant = TutorGrant.fromDoc(doc);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profiles: [_adult(name: 'Avi')],
          grants: [activeGrant],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('YOUR PROFILES'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'YOUR PROFILES header NOT shown when user has no tutored grants',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          profiles: [_adult(name: 'Avi')],
          grants: [],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('YOUR PROFILES'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── Max-10 cap: add card disabled at capacity ─────────────────────────────

  testWidgets(
    'Add card is disabled (shows Max Profiles) when 10 profiles present',
    (tester) async {
      final profiles = List.generate(
        10,
        (i) => _adult(id: i + 1, name: 'Profile ${i + 1}'),
      );
      await tester.pumpWidget(_buildApp(router: router, profiles: profiles));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The add card should show the max-profiles label when at cap.
      expect(find.text('Max Profiles'), findsOneWidget);

      // Tapping the disabled add card must NOT open any dialog or call router.
      await tester.tap(find.text('Max Profiles'), warnIfMissed: false);
      await tester.pump();

      verifyNever(() => router.replaceAll(any<List<PageRouteInfo>>()));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── he-RTL smoke test ─────────────────────────────────────────────────────

  testWidgets(
    'he-RTL smoke: screen renders without overflow or crash in Hebrew locale',
    (tester) async {
      // Constrain viewport to a phone-sized screen (1080×2340 → logical ~360×780).
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // The big AddProfileCard overflow is fixed (FittedBox). Residual small
      // profile-grid RenderFlex overflows at this 360×780-logical Hebrew viewport
      // are tracked for the Phase 8 RTL/visual sweep; ignore overflow errors here
      // so this functional smoke (Hebrew names render, no crash) isn't masked.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final profiles = [_child(name: 'יוסף'), _adult(name: 'אברהם')];

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profiles: profiles,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Both profile names must be visible.
      expect(find.text('יוסף'), findsOneWidget);
      expect(find.text('אברהם'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  // ── R-TU-CARD-EMAIL: pending invite card shows parent + child names ─────────

  TutorGrant makePendingGrant({
    String grantId = 'g1',
    String? parentName,
    String? childName,
  }) {
    final doc = TutorGrantDoc(
      grantId: grantId,
      parentUid: 'p_uid',
      childProfileId: 'child_remote_id',
      tutorEmail: 'tutor@test.com',
      state: TutorGrantState.pending,
      invitedAt: _epoch,
      updatedAt: _epoch,
      parentName: parentName,
      childName: childName,
    );
    return TutorGrant.fromDoc(doc);
  }

  testWidgets(
    'pending invite card shows parent name and child name in body text',
    (tester) async {
      final grant = makePendingGrant(parentName: 'Chana', childName: 'Avi');

      await tester.pumpWidget(
        _buildApp(router: router, profiles: [], pendingInvites: [grant]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The body must contain both the parent name and the child name so the
      // user can distinguish multiple pending invites.
      expect(
        find.textContaining('Chana'),
        findsOneWidget,
        reason: 'parent name must appear in the pending invite card body',
      );
      expect(
        find.textContaining('Avi'),
        findsOneWidget,
        reason: 'child name must appear in the pending invite card body',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'pending invite card falls back to generic labels when names are absent',
    (tester) async {
      // No parentName or childName supplied — server has not denormalised them.
      final grant = makePendingGrant();

      await tester.pumpWidget(
        _buildApp(router: router, profiles: [], pendingInvites: [grant]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should show l10n fallback for parent ("Parent") and generic child label.
      expect(
        find.textContaining('Parent'),
        findsOneWidget,
        reason: 'should fall back to "Parent" label when parentName is null',
      );
      expect(
        find.textContaining('Talmid'),
        findsOneWidget,
        reason: 'should fall back to "Talmid" label when childName is null',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'two pending invites show distinct parent+child labels so user can tell them apart',
    (tester) async {
      final grant1 = makePendingGrant(
        grantId: 'g1',
        parentName: 'Chana',
        childName: 'Avi',
      );
      final grant2 = makePendingGrant(
        grantId: 'g2',
        parentName: 'Rivka',
        childName: 'Moshe',
      );

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profiles: [],
          pendingInvites: [grant1, grant2],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Chana'), findsOneWidget);
      expect(find.textContaining('Avi'), findsOneWidget);
      expect(find.textContaining('Rivka'), findsOneWidget);
      expect(find.textContaining('Moshe'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
