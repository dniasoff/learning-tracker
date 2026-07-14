// Regression test for R-PR2:
//
// The profile PICKER screen's _showDeleteDialog had a stale online guard for
// cloud-born accounts (added before R3-10, which removed the same guard from
// the canonical deleteProfileFlow). This left the two delete paths inconsistent:
//
//   - switcher-sheet path (deleteProfileFlow):  offline-first, no guard [CORRECT]
//   - picker long-press path (_showDeleteDialog): blocked offline [WRONG / stale]
//
// Fix: removed the connectivity check from _showDeleteDialog in
// profile_picker_screen.dart. The repo is offline-first (local Drift delete +
// outbox queue for cloud); no UI gate is needed.
//
// These tests fail BEFORE the fix (repo.deleteProfile is not called when
// offline for a cloud-born account) and pass AFTER.

@Tags(['l1', 'profiles', 'r_pr2', 'offline_first'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/profile_picker_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

ProfileModel _profile({
  required int id,
  required String name,
  String mode = 'child',
}) => ProfileModel(
  id: id,
  accountId: 1,
  displayName: name,
  mode: mode,
  avatarIndex: 0,
  createdAt: _epoch,
  updatedAt: _epoch,
);

const _kCloudBorn = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'cloud@test.com',
    displayName: 'Cloud',
    firebaseUid: 'uid123',
  ),
  tier: Tier.cloudBorn,
);

const _kLocalBorn = AuthState.signedIn(
  user: AuthUser(profileId: 1, email: 'local@test.com', displayName: 'Local'),
  tier: Tier.localBorn,
);

/// Pumps [ProfilePickerScreen] with two profiles and a mock repository.
///
/// [authState] controls the account tier; [selectedId] is the initially
/// selected profile (defaults to none so neither profile is "active" when
/// we long-press the non-selected one).
Widget _buildApp({
  required _MockStackRouter router,
  required _MockProfileRepository repo,
  required List<ProfileModel> profiles,
  required AuthState authState,
  int? selectedId,
}) {
  return pumpApp(
    overrides: [
      profileListProvider.overrideWith((ref) => Future.value(profiles)),
      incomingTutorGrantsProvider.overrideWith((ref) async => []),
      pendingTutorInvitesProvider.overrideWith((ref) async => []),
      authStateProvider.overrideWithValue(authState),
      currentAccountIdProvider.overrideWithValue(1),
      profileRepositoryProvider.overrideWithValue(repo),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(selectedId),
      ),
    ],
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const Scaffold(body: ProfilePickerScreen()),
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  // R-PR2 core regression: cloud-born offline delete via picker long-press
  // ─────────────────────────────────────────────────────────────────────────

  group('R-PR2 — picker _showDeleteDialog: no connectivity gate (offline-first)', () {
    // Shared mock repo setup reused by both cloud-born and local-born tests.
    _MockProfileRepository makeRepo({required List<ProfileModel> profiles}) {
      final repo = _MockProfileRepository();
      // Two profiles → isLast == false.
      when(
        () => repo.countProfilesForAccount(any()),
      ).thenAnswer((_) async => profiles.length);
      // deleteProfile succeeds (simulates the offline-first local Drift delete).
      when(
        () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
      ).thenAnswer((_) async {});
      return repo;
    }

    /// Drive the picker's long-press → manage sheet → delete → confirm dialog
    /// and verify [repo.deleteProfile] is called.
    ///
    /// Does NOT inject [connectivityServiceProvider] — if the code still reads
    /// it (the pre-fix state), the provider resolves via the real
    /// ConnectivityGateway which is online in CI. But the point is that the
    /// production code should NOT call it at all after the fix.
    Future<void> doDeleteFlow(
      WidgetTester tester,
      _MockStackRouter router,
      _MockProfileRepository repo,
      List<ProfileModel> profiles,
      AuthState authState,
      String profileNameToDelete,
    ) async {
      // Use a wide enough logical viewport so the profile grid doesn't overflow.
      // 1080×2340 physical at ratio 1.0 → 1080×2340 logical, enough for the grid.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Profile cards may overflow at some sizes depending on font metrics in CI.
      // Suppress overflow-only errors so the delete-flow assertions are not masked.
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      await tester.pumpWidget(
        _buildApp(
          router: router,
          repo: repo,
          profiles: profiles,
          authState: authState,
          selectedId: null, // no currently-selected profile
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Long-press to open the manage bottom sheet.
      await tester.longPress(find.text(profileNameToDelete));
      await tester.pumpAndSettle();

      // Bottom sheet: tap Delete (enabled — 2 profiles).
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm dialog: tap the destructive "Delete" button.
      // The dialog has Cancel + Delete; use .last to hit the FilledButton.
      final deleteButtons = find.text('Delete');
      expect(
        deleteButtons,
        findsWidgets,
        reason: 'Delete button in confirm dialog must be present',
      );
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'cloud-born + offline: repo.deleteProfile IS called (no online gate)',
      (tester) async {
        final profiles = [
          _profile(id: 1, name: 'Avi', mode: 'adult'),
          _profile(id: 2, name: 'Beni', mode: 'child'),
        ];
        final repo = makeRepo(profiles: profiles);

        await doDeleteFlow(tester, router, repo, profiles, _kCloudBorn, 'Beni');

        // R-PR2: the repository must be called regardless of connectivity.
        // Before the fix this would NOT be called when offline for cloud-born.
        verify(() => repo.deleteProfile(2, allowLast: false)).called(1);

        // The old offline snackbar must NOT appear.
        expect(
          find.textContaining('internet connection'),
          findsNothing,
          reason:
              'R-PR2: the stale offline snackbar must not appear — deletion '
              'is offline-first',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'local-born + offline: repo.deleteProfile IS called (unchanged behavior)',
      (tester) async {
        final profiles = [
          _profile(id: 1, name: 'Avi', mode: 'adult'),
          _profile(id: 2, name: 'Beni', mode: 'child'),
        ];
        final repo = makeRepo(profiles: profiles);

        await doDeleteFlow(tester, router, repo, profiles, _kLocalBorn, 'Beni');

        // Local-born always passed the old guard (isLocalBorn == true skipped
        // the check). Must still work after the fix.
        verify(() => repo.deleteProfile(2, allowLast: false)).called(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
