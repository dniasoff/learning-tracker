// Regression test for R3-10: offline-first profile deletion.
//
// Deleting a cloud-account profile while offline must succeed — the local Drift
// delete happens immediately and the cloud delete is queued to the outbox.
// The previous code blocked deletion with an error snackbar when !isOnline.
@Tags(['l1', 'profiles', 'offline_first', 'r3_10'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

/// A fixed [SelectedProfileId] notifier that starts at [_initial].
class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

ProfileModel _cloudProfile({required int id, required String name}) =>
    ProfileModel(
      id: id,
      accountId: 1,
      displayName: name,
      mode: 'child',
      avatarIndex: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

/// A cloud-born [AuthState] used throughout the test.
///
/// [isLocalBorn] is false → this is the account type that used to be blocked
/// by the online gate.
const _cloudBornAuthState = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'cloud@test.com',
    displayName: 'Cloud User',
    firebaseUid: 'uid-123',
  ),
  tier: Tier.cloudBorn,
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── R3-10 regression ─────────────────────────────────────────────────────

  group('R3-10 — deleteProfileFlow offline-first (cloud account)', () {
    testWidgets('deleting a cloud-account profile while offline succeeds '
        '(local delete is called, no online-gate snackbar shown)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = createTestDatabase();
      // Seed account 1 (FK required by the profiles table).
      await seedProfileWithIds(db, profileId: 1, accountId: 1);
      addTearDown(() => db.close());

      final repo = _MockProfileRepository();

      // Two profiles so the last-profile guard does not fire.
      when(
        () => repo.countProfilesForAccount(any()),
      ).thenAnswer((_) async => 2);

      // The actual delete must not throw (simulates a successful local delete).
      when(
        () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
      ).thenAnswer((_) async {});

      final profileToDelete = _cloudProfile(id: 2, name: 'ToDelete');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            // Cloud-born account: isLocalBorn == false.  This is the case
            // that the old online-gate wrongly blocked when offline.
            authStateProvider.overrideWithValue(_cloudBornAuthState),
            currentAccountIdProvider.overrideWithValue(1),
            profileRepositoryProvider.overrideWithValue(repo),
            // The profile being deleted is not the currently selected one.
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(1),
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
            home: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('trigger_delete'),
                    onPressed: () =>
                        deleteProfileFlow(ctx, ref, profileToDelete),
                    child: const Text('Delete'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Trigger the delete flow.
      await tester.tap(find.byKey(const Key('trigger_delete')));
      await tester.pump(); // open dialog
      await tester.pump(const Duration(milliseconds: 50));

      // Confirm the deletion in the dialog.
      // The dialog shows the non-last-profile body with the "Delete" action.
      final deleteButtons = find.widgetWithText(TextButton, 'Delete');
      expect(
        deleteButtons,
        findsOneWidget,
        reason: 'Confirmation dialog should show a Delete button',
      );
      await tester.tap(deleteButtons);
      await tester.pump(); // process confirmation
      await tester.pump(const Duration(milliseconds: 50));

      // The local repo.deleteProfile was called — the online gate did NOT
      // block the flow.
      verify(
        () => repo.deleteProfile(profileToDelete.id, allowLast: false),
      ).called(1);

      // The old error snackbar ("An internet connection is required to delete
      // a profile.") must NOT appear.
      expect(
        find.textContaining('internet connection'),
        findsNothing,
        reason:
            'Online gate snackbar must not appear — deletion is offline-first',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'deleting the selected cloud-account profile while offline clears '
      'selectedProfileId',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final db = createTestDatabase();
        await seedProfileWithIds(db, profileId: 1, accountId: 1);
        addTearDown(() => db.close());

        final repo = _MockProfileRepository();
        when(
          () => repo.countProfilesForAccount(any()),
        ).thenAnswer((_) async => 2);
        when(
          () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
        ).thenAnswer((_) async {});

        // The profile being deleted IS the currently selected one (id=2).
        final profileToDelete = _cloudProfile(id: 2, name: 'ActiveProfile');

        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userDatabaseProvider.overrideWithValue(db),
              authStateProvider.overrideWithValue(_cloudBornAuthState),
              currentAccountIdProvider.overrideWithValue(1),
              profileRepositoryProvider.overrideWithValue(repo),
              // Selected profile matches the one being deleted.
              selectedProfileIdProvider.overrideWith(
                () => _FixedSelectedProfileId(2),
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
              home: Consumer(
                builder: (ctx, ref, _) {
                  container = ProviderScope.containerOf(ctx);
                  return Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        key: const Key('trigger_delete'),
                        onPressed: () =>
                            deleteProfileFlow(ctx, ref, profileToDelete),
                        child: const Text('Delete'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('trigger_delete')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Local delete was called.
        verify(
          () => repo.deleteProfile(profileToDelete.id, allowLast: false),
        ).called(1);

        // selectedProfileId was cleared because the deleted profile was active.
        expect(
          container.read(selectedProfileIdProvider),
          isNull,
          reason:
              'selectedProfileId should be cleared after deleting the active profile',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
