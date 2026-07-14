// L1 widget tests — ManageLearnersScreen
//
// Covers:
//   • Loading state — shows CircularProgressIndicator while stream is loading
//   • Error state   — shows AppErrorView "Something went wrong" + Retry button
//   • Empty state   — shows noProfilesYet l10n string
//   • List rendering — profiles with child/adult subtitle labels (no "parent" label)
//   • List rendering — only child + adult types appear in subtitles
//   • Add flow — FAB is always visible; ManageLearnersScreen delegates to showAddProfileDialog
//   • Edit flow — Edit popup → profileRepositoryProvider.updateProfile called
//   • Delete flow — Delete popup → confirm dialog → repo.deleteProfile called
//   • Delete flow — Cancel on confirm dialog → repo.deleteProfile NOT called
//   • Delete last profile — shows last-profile confirm dialog title
//   • Delete cloud-born offline — deleteProfile STILL called (offline-first, R3-10)
//   • Max-10 cap — FAB is present regardless of count (cap is repo-only)
//   • he-RTL smoke — Hebrew locale: screen renders without overflow/crash
//   • AppBar title localization — title comes from l10n.manageProfiles (en + he)

@Tags(['profiles', 'manage_learners'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/network/connectivity_gateway.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/manage_learners_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockConnectivityGateway extends Mock implements ConnectivityGateway {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Helpers ──────────────────────────────────────────────────────────────────

ProfileModel _profile({
  required int id,
  required String name,
  required String mode,
  int accountId = 1,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: id,
    accountId: accountId,
    displayName: name,
    mode: mode,
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

/// Stub [SelectedProfileId] notifier with a fixed value so keepAlive providers
/// do not try to read the real database on build.
class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

const _kLocalBornAuthState = AuthState.signedIn(
  user: AuthUser(profileId: 1, email: 'test@test.com', displayName: 'Test'),
  tier: Tier.localBorn,
);

const _kCloudBornAuthState = AuthState.signedIn(
  user: AuthUser(profileId: 1, email: 'test@test.com', displayName: 'Test'),
  tier: Tier.cloudBorn,
);

/// Build ManageLearnersScreen with a controlled stream and mock providers.
///
/// [profilesState]: controls what [profileListStreamProvider] emits.
///   - Pass `AsyncData([...])` for normal list display.
///   - Pass `AsyncLoading()` for loading state — the internal StreamController
///     never emits so the provider stays in loading.
///   - Pass `AsyncError(e, st)` for error state.
/// [repo]          : injected as [profileRepositoryProvider].
/// [connectivity]  : defaults to always-online.
/// [authState]     : defaults to localBorn so offline guard is bypassed.
/// [locale]        : defaults to 'en'.
/// [disableRetry]  : set true to let FutureProviders surface errors without
///                   Riverpod's built-in retry loop.
Widget _buildApp({
  required _MockStackRouter router,
  required AsyncValue<List<ProfileModel>> profilesState,
  _MockProfileRepository? repo,
  _MockConnectivityGateway? connectivity,
  AuthState authState = _kLocalBornAuthState,
  Locale locale = const Locale('en'),
  bool disableRetry = false,
}) {
  final mockRepo = repo ?? _MockProfileRepository();
  final isDefaultConnectivity = connectivity == null;
  final mockConnectivity = connectivity ?? _MockConnectivityGateway();

  // Only apply the default stub when the caller did not provide a pre-stubbed
  // connectivity mock. When the caller provides one, it has already configured
  // isOnline before invoking _buildApp (e.g. the offline test stubs false).
  if (isDefaultConnectivity) {
    when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
  }

  // Build a stream that matches the requested AsyncValue.
  Stream<List<ProfileModel>> makeStream() {
    switch (profilesState) {
      case AsyncData<List<ProfileModel>>(:final value):
        return Stream.value(value);
      case AsyncError<List<ProfileModel>>(:final error, :final stackTrace):
        return Stream<List<ProfileModel>>.error(error, stackTrace);
      default:
        // AsyncLoading — never emits and never closes so the provider remains
        // in the loading state for the duration of the test.
        return StreamController<List<ProfileModel>>().stream;
    }
  }

  return pumpApp(
    retry: disableRetry ? (_, __) => null : null,
    overrides: [
      profileListStreamProvider.overrideWith((ref) => makeStream()),
      profileRepositoryProvider.overrideWithValue(mockRepo),
      currentAccountIdProvider.overrideWithValue(1),
      authStateProvider.overrideWithValue(authState),
      connectivityServiceProvider.overrideWithValue(mockConnectivity),
      selectedProfileIdProvider.overrideWith(() => _FixedSelectedProfileId(1)),
    ],
    locale: locale,
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const ManageLearnersScreen(),
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
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/manage-learners');
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Future<Object?>.value());
  });

  // ── Loading ──────────────────────────────────────────────────────────────────

  group('Loading state', () {
    testWidgets('shows CircularProgressIndicator while stream is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(router: router, profilesState: const AsyncLoading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Error ────────────────────────────────────────────────────────────────────

  group('Error state', () {
    testWidgets('shows AppErrorView and Retry button on stream error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncError(Exception('boom'), StackTrace.empty),
          disableRetry: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // AppErrorView maps generic exceptions to "Something went wrong".
      expect(find.text('Something went wrong'), findsOneWidget);
      // Retry button shown because onRetry is wired in the screen.
      expect(find.text('Retry'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Empty state ──────────────────────────────────────────────────────────────

  group('Empty state', () {
    testWidgets('shows noProfilesYet text when profile list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(router: router, profilesState: const AsyncData([])),
      );
      await tester.pump();

      // l10n.noProfilesYet = 'No profiles yet. Tap + to add one.'
      expect(find.text('No profiles yet. Tap + to add one.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── List rendering ───────────────────────────────────────────────────────────

  group('List rendering', () {
    testWidgets('lists profiles by display name', (tester) async {
      final profiles = [
        _profile(id: 1, name: 'Avi', mode: 'adult'),
        _profile(id: 2, name: 'Beni', mode: 'child'),
      ];

      await tester.pumpWidget(
        _buildApp(router: router, profilesState: AsyncData(profiles)),
      );
      await tester.pump();

      expect(find.text('Avi'), findsOneWidget);
      expect(find.text('Beni'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows l10n profileTypeChild subtitle for child profile', (
      tester,
    ) async {
      final profiles = [_profile(id: 1, name: 'Dani', mode: 'child')];

      await tester.pumpWidget(
        _buildApp(router: router, profilesState: AsyncData(profiles)),
      );
      await tester.pump();

      // l10n.profileTypeChild = 'Child'
      expect(find.text('Child'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows l10n profileTypeAdult subtitle for adult profile', (
      tester,
    ) async {
      final profiles = [_profile(id: 1, name: 'Sarah', mode: 'adult')];

      await tester.pumpWidget(
        _buildApp(router: router, profilesState: AsyncData(profiles)),
      );
      await tester.pump();

      // l10n.profileTypeAdult = 'Adult'
      expect(find.text('Adult'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('never renders "Parent mode" as a profile type subtitle', (
      tester,
    ) async {
      // Product rule: only child + adult profile types exist — no "parent" type.
      final profiles = [
        _profile(id: 1, name: 'Reuven', mode: 'adult'),
        _profile(id: 2, name: 'Shimon', mode: 'child'),
      ];

      await tester.pumpWidget(
        _buildApp(router: router, profilesState: AsyncData(profiles)),
      );
      await tester.pump();

      expect(find.text('Parent mode'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'each profile tile exposes an Edit and a Delete popup menu item',
      (tester) async {
        final profiles = [_profile(id: 1, name: 'Avi', mode: 'adult')];

        await tester.pumpWidget(
          _buildApp(router: router, profilesState: AsyncData(profiles)),
        );
        await tester.pump();

        // Open the PopupMenuButton for the tile.
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        // l10n.profilesEditLabel = 'Edit', l10n.profilesDeleteLabel = 'Delete'
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Add flow ──────────────────────────────────────────────────────────────────

  group('Add flow', () {
    testWidgets('FAB is always visible (no UI cap gate)', (tester) async {
      // Screen has a FloatingActionButton for add regardless of profile count.
      await tester.pumpWidget(
        _buildApp(router: router, profilesState: const AsyncData([])),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('FAB is visible even when 10 profiles exist', (tester) async {
      // BUG: ManageLearnersScreen does not visually disable the FAB or show
      // a UI cap indicator when 10 profiles exist. The cap is enforced only
      // in the repo (MaxProfilesExceededException), but no proactive UI
      // feedback is shown to the user before they attempt to add. This is a
      // UX bug — the FAB should be disabled or hidden at cap.
      final profiles = List.generate(
        10,
        (i) => _profile(id: i + 1, name: 'Profile ${i + 1}', mode: 'adult'),
      );

      await tester.pumpWidget(
        _buildApp(router: router, profilesState: AsyncData(profiles)),
      );
      await tester.pump();

      // The FAB is still present (bug — should be disabled or absent at cap).
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Edit flow ─────────────────────────────────────────────────────────────────

  group('Edit flow', () {
    testWidgets('tapping Edit opens the ProfileEditFormDialog', (tester) async {
      final profile = _profile(id: 1, name: 'Avi', mode: 'adult');
      final repo = _MockProfileRepository();
      when(
        () => repo.updateProfile(
          id: any(named: 'id'),
          displayName: any(named: 'displayName'),
          avatarIndex: any(named: 'avatarIndex'),
        ),
      ).thenAnswer((_) async => profile);
      when(
        () => repo.getProfilesByAccount(any()),
      ).thenAnswer((_) async => [profile]);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([profile]),
          repo: repo,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // ProfileEditFormDialog has title l10n.profilesEditLearner = 'Edit Learner'.
      expect(find.text('Edit Learner'), findsOneWidget);
      // Name field is shown.
      expect(find.text('Name'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('confirming the edit dialog calls repo.updateProfile', (
      tester,
    ) async {
      final profile = _profile(id: 1, name: 'Avi', mode: 'adult');
      final repo = _MockProfileRepository();
      when(
        () => repo.updateProfile(
          id: any(named: 'id'),
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
          avatarIndex: any(named: 'avatarIndex'),
        ),
      ).thenAnswer(
        (_) async => _profile(id: 1, name: 'Avi Renamed', mode: 'adult'),
      );
      when(
        () => repo.getProfilesByAccount(any()),
      ).thenAnswer((_) async => [profile]);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([profile]),
          repo: repo,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Replace the name field content.
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Avi Renamed');
      await tester.pump();

      // Tap Save (l10n.actionSave = 'Save').
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // PP-2: editProfileFlow now persists the selected mode. The Edit dialog
      // pre-selects the profile's existing mode ('adult'), so the renamed
      // profile is saved with mode: 'adult' preserved.
      verify(
        () => repo.updateProfile(
          id: 1,
          displayName: 'Avi Renamed',
          mode: 'adult',
          avatarIndex: any(named: 'avatarIndex'),
        ),
      ).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('cancelling the edit dialog does NOT call repo.updateProfile', (
      tester,
    ) async {
      final profile = _profile(id: 1, name: 'Avi', mode: 'adult');
      final repo = _MockProfileRepository();

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([profile]),
          repo: repo,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Dismiss with Cancel (l10n.actionCancel = 'Cancel').
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repo.updateProfile(
          id: any(named: 'id'),
          displayName: any(named: 'displayName'),
          avatarIndex: any(named: 'avatarIndex'),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── Delete flow ───────────────────────────────────────────────────────────────

  group('Delete flow', () {
    testWidgets('tapping Delete shows a confirm dialog with the profile name', (
      tester,
    ) async {
      final profile = _profile(id: 1, name: 'Beni', mode: 'child');
      final repo = _MockProfileRepository();
      when(
        () => repo.countProfilesForAccount(any()),
      ).thenAnswer((_) async => 2);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([profile]),
          repo: repo,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Standard delete confirm dialog title: l10n.deleteProfileTitle = 'Delete Profile?'
      expect(find.text('Delete Profile?'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('confirming Delete calls repo.deleteProfile with profile id', (
      tester,
    ) async {
      final profile = _profile(id: 42, name: 'Beni', mode: 'child');
      final repo = _MockProfileRepository();
      when(
        () => repo.countProfilesForAccount(any()),
      ).thenAnswer((_) async => 2);
      when(
        () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
      ).thenAnswer((_) async {});
      when(
        () => repo.getProfilesByAccount(any()),
      ).thenAnswer((_) async => [profile]);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([profile]),
          repo: repo,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm the deletion — button text is l10n.actionDelete = 'Delete'.
      // There are two 'Delete' texts (dialog title and action button) so we
      // tap the last one (the action button).
      final deleteButtons = find.text('Delete');
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      verify(
        () => repo.deleteProfile(42, allowLast: any(named: 'allowLast')),
      ).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('cancelling Delete does NOT call repo.deleteProfile', (
      tester,
    ) async {
      final profile = _profile(id: 1, name: 'Beni', mode: 'child');
      final repo = _MockProfileRepository();
      when(
        () => repo.countProfilesForAccount(any()),
      ).thenAnswer((_) async => 2);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: AsyncData([profile]),
          repo: repo,
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // l10n.actionCancel = 'Cancel'
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'deleting the last profile shows the last-profile confirm dialog',
      (tester) async {
        final profile = _profile(id: 1, name: 'Solo', mode: 'adult');
        final repo = _MockProfileRepository();
        // countProfilesForAccount returns 1 → this is the last profile.
        when(
          () => repo.countProfilesForAccount(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
        ).thenAnswer((_) async {});
        when(
          () => repo.getProfilesByAccount(any()),
        ).thenAnswer((_) async => []);

        await tester.pumpWidget(
          _buildApp(
            router: router,
            profilesState: AsyncData([profile]),
            repo: repo,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // l10n.deleteProfileLastTitle = 'Delete your only profile?'
        expect(find.text('Delete your only profile?'), findsOneWidget);
        // l10n.deleteProfileLastConfirm = 'Delete anyway'
        expect(find.text('Delete anyway'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'cloud-born offline: confirming Delete STILL calls repo.deleteProfile '
      '(offline-first — R3-10)',
      (tester) async {
        final profile = _profile(id: 1, name: 'Beni', mode: 'child');
        final repo = _MockProfileRepository();
        final connectivity = _MockConnectivityGateway();
        when(
          () => repo.countProfilesForAccount(any()),
        ).thenAnswer((_) async => 2);
        when(
          () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
        ).thenAnswer((_) async {});
        // Bug B: deleting the active profile now re-queries remaining profiles
        // to auto-switch the selection. id=1 is the only profile, so none
        // remain after delete and the flow clears the selection.
        when(
          () => repo.getProfilesByAccount(any()),
        ).thenAnswer((_) async => <ProfileModel>[]);
        // Simulate offline.
        when(() => connectivity.isOnline).thenAnswer((_) async => false);

        await tester.pumpWidget(
          _buildApp(
            router: router,
            profilesState: AsyncData([profile]),
            repo: repo,
            connectivity: connectivity,
            // Cloud-born account: pre-R3-10 this was gated offline; now the
            // delete is offline-first (local delete + queued cloud delete).
            authState: _kCloudBornAuthState,
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Confirm deletion.
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        // R3-10: offline-first — the delete must proceed offline (no online gate).
        verify(
          () => repo.deleteProfile(1, allowLast: any(named: 'allowLast')),
        ).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── he-RTL smoke ──────────────────────────────────────────────────────────────

  group('he-RTL smoke', () {
    testWidgets(
      'Hebrew locale: screen renders child + adult profiles without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        final profiles = [
          _profile(id: 1, name: 'אבי', mode: 'adult'),
          _profile(id: 2, name: 'בני', mode: 'child'),
        ];

        await tester.pumpWidget(
          _buildApp(
            router: router,
            profilesState: AsyncData(profiles),
            locale: const Locale('he'),
          ),
        );
        await tester.pump();

        expect(find.text('אבי'), findsOneWidget);
        expect(find.text('בני'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Localized AppBar title ────────────────────────────────────────────────────

  group('AppBar title localization', () {
    testWidgets('English: title comes from l10n (manageProfiles), not hardcoded', (
      tester,
    ) async {
      // FR1 fix: the AppBar title now reads AppLocalizations.of(context)!
      // .manageProfiles instead of the hardcoded literal 'Manage Learners', so
      // it follows the device locale (resweep: English title over Hebrew body).
      await tester.pumpWidget(
        _buildApp(router: router, profilesState: const AsyncData([])),
      );
      await tester.pump();

      // l10n.manageProfiles (en) = 'Manage Profiles'.
      expect(find.text('Manage Profiles'), findsOneWidget);
      // The old hardcoded string must no longer appear.
      expect(find.text('Manage Learners'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Hebrew: title renders the Hebrew l10n string', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          router: router,
          profilesState: const AsyncData([]),
          locale: const Locale('he'),
        ),
      );
      await tester.pump();

      // l10n.manageProfiles (he) = 'ניהול פרופילים' — no English leak.
      expect(find.text('ניהול פרופילים'), findsOneWidget);
      expect(find.text('Manage Learners'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
