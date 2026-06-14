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
      'deleting the active cloud-account profile auto-switches the selection '
      'to a remaining profile (Bug B — not cleared to null)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final db = createTestDatabase();
        await seedProfileWithIds(db, profileId: 1, accountId: 1);
        addTearDown(() => db.close());

        // One sibling profile (id=1) remains after deleting the active id=2.
        final remainingProfile = _cloudProfile(id: 1, name: 'Daniel');

        final repo = _MockProfileRepository();
        when(
          () => repo.countProfilesForAccount(any()),
        ).thenAnswer((_) async => 2);
        when(
          () => repo.deleteProfile(any(), allowLast: any(named: 'allowLast')),
        ).thenAnswer((_) async {});
        // Bug B: after delete the flow looks up remaining profiles to pick the
        // next active one. id=2 was deleted, so only id=1 ("Daniel") is left.
        when(
          () => repo.getProfilesByAccount(any()),
        ).thenAnswer((_) async => [remainingProfile]);

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

        // Bug B: selectedProfileId auto-switched to the remaining profile (id=1)
        // instead of clearing to null — so the dashboard greeting / top-bar
        // immediately re-derive to that profile rather than the generic
        // "Learner" fallback.
        expect(
          container.read(selectedProfileIdProvider),
          1,
          reason:
              'deleting the active profile must auto-switch to a remaining '
              'profile, not clear the selection (Bug B)',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── Mode-seeding regression ──────────────────────────────────────────────
  //
  // P2 (low-confidence on-device observation): opening the edit dialog on a
  // CHILD profile reportedly showed "Adult" pre-selected. Code review shows the
  // dialog correctly seeds its initial selection from widget.initialMode
  // (defaulting to 'child', never 'adult'). These tests lock that in so the
  // initial selection always reflects the profile's actual mode.

  group('ProfileEditFormDialog — initial mode seeding', () {
    Future<void> pumpDialog(WidgetTester tester, String? initialMode) async {
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
            body: ProfileEditFormDialog(
              title: 'Edit Learner',
              initialName: 'Sample',
              initialMode: initialMode,
              initialAvatar: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Set<String> selectedSegments(WidgetTester tester) {
      final button = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      return button.selected;
    }

    testWidgets('child profile pre-selects Child', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpDialog(tester, 'child');

      expect(
        selectedSegments(tester),
        {'child'},
        reason: 'Editing a child profile must pre-select the Child segment',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('adult profile pre-selects Adult', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpDialog(tester, 'adult');

      expect(
        selectedSegments(tester),
        {'adult'},
        reason: 'Editing an adult profile must pre-select the Adult segment',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('null/unknown mode falls back to Child (never Adult)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await pumpDialog(tester, null);

      expect(
        selectedSegments(tester),
        {'child'},
        reason: 'Missing mode must default to Child, not Adult',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── P2: empty-name inline validation ─────────────────────────────────────
  //
  // Previously, tapping Save with an empty/whitespace-only name silently
  // no-oped: the dialog stayed open with NO feedback. The Save handler now
  // surfaces a localized inline error (learnerNameRequired) and blocks the
  // pop; typing a valid name clears the error and Save proceeds.

  group('ProfileEditFormDialog — empty-name inline validation (P2)', () {
    Future<({String name, String mode, int avatar})?> pumpAndCapture(
      WidgetTester tester, {
      required String initialName,
    }) async {
      ({String name, String mode, int avatar})? popped;
      var dialogOpen = true;

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
              builder: (ctx) => Center(
                child: ElevatedButton(
                  key: const Key('open_dialog'),
                  onPressed: () async {
                    popped =
                        await showDialog<
                          ({String name, String mode, int avatar})
                        >(
                          context: ctx,
                          builder: (_) => ProfileEditFormDialog(
                            title: 'Edit Learner',
                            initialName: initialName,
                            initialMode: 'child',
                            initialAvatar: 0,
                          ),
                        );
                    dialogOpen = false;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog')));
      await tester.pumpAndSettle();
      expect(dialogOpen, isTrue);
      return popped;
    }

    testWidgets(
      'tapping Save with a whitespace-only name shows the inline error and '
      'does NOT close the dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await pumpAndCapture(tester, initialName: '   ');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // No error before Save.
        expect(find.text(l10n.learnerNameRequired), findsNothing);

        await tester.tap(find.widgetWithText(FilledButton, l10n.actionSave));
        await tester.pumpAndSettle();

        // Inline error shown, dialog still open (Save blocked).
        expect(find.text(l10n.learnerNameRequired), findsOneWidget);
        expect(find.byType(ProfileEditFormDialog), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'typing a valid name clears the error and Save proceeds (pops the result)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await pumpAndCapture(tester, initialName: '');

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Trigger the inline error first.
        await tester.tap(find.widgetWithText(FilledButton, l10n.actionSave));
        await tester.pumpAndSettle();
        expect(find.text(l10n.learnerNameRequired), findsOneWidget);

        // Typing a valid name clears the inline error.
        await tester.enterText(find.byType(TextField), 'Aviva');
        await tester.pumpAndSettle();
        expect(find.text(l10n.learnerNameRequired), findsNothing);

        // Save now proceeds and closes the dialog.
        await tester.tap(find.widgetWithText(FilledButton, l10n.actionSave));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileEditFormDialog), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
