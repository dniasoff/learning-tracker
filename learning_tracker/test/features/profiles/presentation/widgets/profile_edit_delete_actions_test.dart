// Regression tests for:
//   R3-10: offline-first profile deletion.
//   R-PR4: child→adult mode change must clear stale per-profile PIN from
//          FlutterSecureStorage.
//   AUD-profiles-02: editProfileFlow must surface (not swallow) a
//          TutorWriteException from a tutor-routed pushLearnerProfile, and
//          must catch DuplicateProfileNameException the same way
//          profile_picker_screen.dart's rename dialog does.
//
// Deleting a cloud-account profile while offline must succeed — the local Drift
// delete happens immediately and the cloud delete is queued to the outbox.
// The previous code blocked deletion with an error snackbar when !isOnline.
@Tags(['l1', 'profiles', 'offline_first', 'r3_10', 'r_pr4', 'aud_profiles_02'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Shared mock storage factory (in-memory back-end for PinService).
// ---------------------------------------------------------------------------

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

_MockFlutterSecureStorage _createMockStorage() {
  final mock = _MockFlutterSecureStorage();
  final store = <String, String>{};

  when(
    () => mock.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    final value = invocation.namedArguments[#value] as String?;
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  });

  when(() => mock.read(key: any(named: 'key'))).thenAnswer((invocation) async {
    final key = invocation.namedArguments[#key] as String;
    return store[key];
  });

  when(() => mock.delete(key: any(named: 'key'))).thenAnswer((
    invocation,
  ) async {
    final key = invocation.namedArguments[#key] as String;
    store.remove(key);
  });

  return mock;
}

class _MockProfileRepository extends Mock implements ProfileRepository {}

/// [SyncWriteFacade] whose [pushLearnerProfile] fails the way a tutor-routed
/// [TutoredWriteRouter] does on a Cloud Function error (AUD-profiles-02). All
/// other operations are no-ops.
class _TutorRoutedFailingFacade implements SyncWriteFacade {
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {
    throw const TutorWriteException(
      'permission denied',
      code: 'permission-denied',
    );
  }

  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> pushGamificationSettingsSnapshot() async {}
  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

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
      ulid: 'ulid-$id',
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
        pumpApp(
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
          child: Consumer(
            builder: (ctx, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('trigger_delete'),
                  onPressed: () => deleteProfileFlow(ctx, ref, profileToDelete),
                  child: const Text('Delete'),
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
          pumpApp(
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
            child: Consumer(
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
        pumpApp(
          child: Scaffold(
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
        pumpApp(
          child: Scaffold(
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

  // ── R-PR4: child→adult mode change must clear stale per-profile PIN ───────
  //
  // ROOT CAUSE: editProfileFlow updated the profile mode in the database but
  // never cleared the per-profile parent PIN (and tutor PIN) from
  // FlutterSecureStorage. After the mode change, hasProfilePin(id) still
  // returned true, so the PinGuard would incorrectly prompt for a PIN on
  // what is now an adult profile.
  //
  // FIX: when result.mode == 'adult' and the previous profile.mode == 'child',
  // call clearProfilePin(id) and clearTutorPin(id) before returning.

  group('R-PR4 — child→adult mode change clears stale profile PIN', () {
    testWidgets(
      'editProfileFlow: after child→adult change, hasProfilePin returns false',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const profileId = 5;
        const accountId = 1;

        final mockStorage = _createMockStorage();
        final pinService = PinService(mockStorage);

        // Pre-seed: the child profile has a parent PIN set.
        await pinService.setProfilePin(profileId, '1234');
        expect(
          await pinService.hasProfilePin(profileId),
          isTrue,
          reason: 'precondition: PIN must be set before the mode change',
        );

        final childProfile = ProfileModel(
          id: profileId,
          ulid: 'ulid-$profileId',
          accountId: accountId,
          displayName: 'Yosef',
          mode: 'child',
          avatarIndex: 0,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );
        final updatedAdultProfile = childProfile.copyWith(mode: 'adult');

        final repo = _MockProfileRepository();
        when(
          () => repo.updateProfile(
            id: any(named: 'id'),
            displayName: any(named: 'displayName'),
            mode: any(named: 'mode'),
            avatarIndex: any(named: 'avatarIndex'),
          ),
        ).thenAnswer((_) async => updatedAdultProfile);
        when(
          () => repo.getProfilesByAccount(any()),
        ).thenAnswer((_) async => [updatedAdultProfile]);
        when(
          () => repo.getProfileById(any()),
        ).thenAnswer((_) async => updatedAdultProfile);
        when(
          () => repo.countProfilesForAccount(any()),
        ).thenAnswer((_) async => 1);

        await tester.pumpWidget(
          pumpApp(
            overrides: [
              // Override secure storage so the real PinService uses our
              // in-memory store and we can observe clearProfilePin's effect.
              flutterSecureStorageProvider.overrideWithValue(mockStorage),
              profileRepositoryProvider.overrideWithValue(repo),
              selectedProfileIdProvider.overrideWith(
                () => _FixedSelectedProfileId(profileId),
              ),
              currentAccountIdProvider.overrideWithValue(accountId),
            ],
            child: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('trigger_edit'),
                    onPressed: () => editProfileFlow(ctx, ref, childProfile),
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Open the edit dialog.
        await tester.tap(find.byKey(const Key('trigger_edit')));
        await tester.pump(const Duration(milliseconds: 300));

        // The dialog is open. Switch from "Child" to "Adult".
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.text(l10n.profilesAdultLabel).first);
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Save.
        await tester.tap(find.text(l10n.actionSave));
        await tester.pump(const Duration(milliseconds: 300));

        // R-PR4 fix: the profile PIN must now be absent.
        expect(
          await pinService.hasProfilePin(profileId),
          isFalse,
          reason:
              'R-PR4: promoting a child profile to adult must clear the stale '
              'per-profile parent PIN from FlutterSecureStorage',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'editProfileFlow: after child→adult change, hasTutorPin returns false',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const profileId = 6;
        const accountId = 1;

        final mockStorage = _createMockStorage();
        final pinService = PinService(mockStorage);

        // Pre-seed: the child profile also has a tutor PIN.
        await pinService.setTutorPin(profileId, '5678');
        expect(await pinService.hasTutorPin(profileId), isTrue);

        final childProfile = ProfileModel(
          id: profileId,
          ulid: 'ulid-$profileId',
          accountId: accountId,
          displayName: 'Rivka',
          mode: 'child',
          avatarIndex: 1,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );
        final updatedAdultProfile = childProfile.copyWith(mode: 'adult');

        final repo = _MockProfileRepository();
        when(
          () => repo.updateProfile(
            id: any(named: 'id'),
            displayName: any(named: 'displayName'),
            mode: any(named: 'mode'),
            avatarIndex: any(named: 'avatarIndex'),
          ),
        ).thenAnswer((_) async => updatedAdultProfile);
        when(
          () => repo.getProfilesByAccount(any()),
        ).thenAnswer((_) async => [updatedAdultProfile]);
        when(
          () => repo.getProfileById(any()),
        ).thenAnswer((_) async => updatedAdultProfile);
        when(
          () => repo.countProfilesForAccount(any()),
        ).thenAnswer((_) async => 1);

        await tester.pumpWidget(
          pumpApp(
            overrides: [
              flutterSecureStorageProvider.overrideWithValue(mockStorage),
              profileRepositoryProvider.overrideWithValue(repo),
              selectedProfileIdProvider.overrideWith(
                () => _FixedSelectedProfileId(profileId),
              ),
              currentAccountIdProvider.overrideWithValue(accountId),
            ],
            child: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('trigger_edit'),
                    onPressed: () => editProfileFlow(ctx, ref, childProfile),
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byKey(const Key('trigger_edit')));
        await tester.pump(const Duration(milliseconds: 300));

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.text(l10n.profilesAdultLabel).first);
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text(l10n.actionSave));
        await tester.pump(const Duration(milliseconds: 300));

        // R-PR4 fix: the tutor PIN must also be gone.
        expect(
          await pinService.hasTutorPin(profileId),
          isFalse,
          reason:
              'R-PR4: promoting a child profile to adult must also clear the '
              'stale tutor PIN from FlutterSecureStorage',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('editProfileFlow: adult→child change does NOT clear any PIN '
        '(no PINs are set; guard applies only to child→adult)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const profileId = 7;
      const accountId = 1;

      final mockStorage = _createMockStorage();
      final pinService = PinService(mockStorage);

      // No PIN for this adult profile.
      expect(await pinService.hasProfilePin(profileId), isFalse);

      final adultProfile = ProfileModel(
        id: profileId,
        ulid: 'ulid-$profileId',
        accountId: accountId,
        displayName: 'Shmuel',
        mode: 'adult',
        avatarIndex: 0,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      final updatedChildProfile = adultProfile.copyWith(mode: 'child');

      final repo = _MockProfileRepository();
      when(
        () => repo.updateProfile(
          id: any(named: 'id'),
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
          avatarIndex: any(named: 'avatarIndex'),
        ),
      ).thenAnswer((_) async => updatedChildProfile);
      when(
        () => repo.getProfilesByAccount(any()),
      ).thenAnswer((_) async => [updatedChildProfile]);
      when(
        () => repo.getProfileById(any()),
      ).thenAnswer((_) async => updatedChildProfile);
      when(
        () => repo.countProfilesForAccount(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            flutterSecureStorageProvider.overrideWithValue(mockStorage),
            profileRepositoryProvider.overrideWithValue(repo),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(profileId),
            ),
            currentAccountIdProvider.overrideWithValue(accountId),
          ],
          child: Consumer(
            builder: (ctx, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('trigger_edit'),
                  onPressed: () => editProfileFlow(ctx, ref, adultProfile),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('trigger_edit')));
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.profilesChildLabel).first);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text(l10n.actionSave));
      await tester.pump(const Duration(milliseconds: 300));

      // adult→child: no PINs existed, and we should not have accidentally
      // broken any state. hasProfilePin stays false (nothing to clear).
      expect(await pinService.hasProfilePin(profileId), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ── AUD-profiles-02: tutor-routed pushLearnerProfile failures must reach
  // editProfileFlow's existing `on TutorWriteException` handler ─────────────
  //
  // ROOT CAUSE: ProfileRepositoryImpl wrapped every pushLearnerProfile call in
  // a blanket `catch (_) {}` on the premise that the push is a durable,
  // retryable offline-first outbox write. When a tutor session is active,
  // the sync facade is a TutoredWriteRouter instead — a one-shot, non-
  // retryable Cloud Function RPC. Swallowing that failure the same way left
  // editProfileFlow's `on TutorWriteException` handler (below) permanently
  // unreachable: repo.updateProfile could only ever let StateError or
  // DuplicateProfileNameException escape.
  //
  // FIX: ProfileRepositoryImpl now rethrows TutorWriteException instead of
  // swallowing it. This test exercises the REAL ProfileRepositoryImpl (not a
  // mock) wired to a facade that fails the way TutoredWriteRouter does, so it
  // proves the exception actually propagates end-to-end into editProfileFlow.

  group('AUD-profiles-02 — editProfileFlow surfaces tutor-routed push '
      'failures', () {
    testWidgets(
      'a failed tutor-routed pushLearnerProfile shows the tutorPermissionDenied '
      'snackbar instead of being silently swallowed',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const profileId = 10;
        const accountId = 1;
        final db = createTestDatabase();
        await seedProfileWithIds(
          db,
          profileId: profileId,
          accountId: accountId,
        );
        addTearDown(() => db.close());

        // Real repository wired to a facade that fails pushLearnerProfile the
        // way TutoredWriteRouter does on a CF error — exercises the actual
        // propagation path end-to-end, not a mocked shortcut.
        final repo = ProfileRepositoryImpl(
          db,
          syncEngine: _TutorRoutedFailingFacade(),
        );

        final profile = ProfileModel(
          id: profileId,
          ulid: 'ulid-$profileId',
          accountId: accountId,
          displayName: 'Talmid',
          mode: 'child',
          avatarIndex: 0,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );

        await tester.pumpWidget(
          pumpApp(
            overrides: [profileRepositoryProvider.overrideWithValue(repo)],
            child: Consumer(
              builder: (ctx, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('trigger_edit'),
                    onPressed: () => editProfileFlow(ctx, ref, profile),
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byKey(const Key('trigger_edit')));
        await tester.pump(const Duration(milliseconds: 300));

        // Save without changing any field — any Save triggers
        // repo.updateProfile → pushLearnerProfile → TutorWriteException.
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.text(l10n.actionSave));
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          tester.takeException(),
          isNull,
          reason:
              'the TutorWriteException must be caught by editProfileFlow, '
              'not thrown unhandled out of the button handler',
        );
        expect(
          find.text(l10n.tutorPermissionDenied),
          findsOneWidget,
          reason:
              'AUD-profiles-02: a failed tutor-routed pushLearnerProfile '
              'must surface a user-visible error from editProfileFlow — '
              'previously this catch clause was unreachable because '
              'ProfileRepositoryImpl swallowed every push failure',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ── AUD-profiles-02: editProfileFlow must catch DuplicateProfileNameException
  // the same way profile_picker_screen.dart's rename dialog does ────────────

  group(
    'AUD-profiles-02 — editProfileFlow catches DuplicateProfileNameException',
    () {
      testWidgets(
        'a same-account name collision on Edit shows profileNameTaken '
        'instead of throwing unhandled',
        (tester) async {
          tester.view.physicalSize = const Size(1080, 2340);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final repo = _MockProfileRepository();
          when(
            () => repo.updateProfile(
              id: any(named: 'id'),
              displayName: any(named: 'displayName'),
              mode: any(named: 'mode'),
              avatarIndex: any(named: 'avatarIndex'),
            ),
          ).thenThrow(const DuplicateProfileNameException('Original'));

          final profile = _cloudProfile(id: 11, name: 'Original');

          await tester.pumpWidget(
            pumpApp(
              overrides: [profileRepositoryProvider.overrideWithValue(repo)],
              child: Consumer(
                builder: (ctx, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('trigger_edit'),
                      onPressed: () => editProfileFlow(ctx, ref, profile),
                      child: const Text('Edit'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));

          await tester.tap(find.byKey(const Key('trigger_edit')));
          await tester.pump(const Duration(milliseconds: 300));

          final l10n = await AppLocalizations.delegate.load(const Locale('en'));
          await tester.tap(find.text(l10n.actionSave));
          await tester.pump(const Duration(milliseconds: 300));

          expect(
            tester.takeException(),
            isNull,
            reason:
                'AUD-profiles-02: DuplicateProfileNameException must be '
                'caught by editProfileFlow, not thrown unhandled out of the '
                'button handler',
          );
          expect(
            find.text(l10n.profileNameTaken('Original')),
            findsOneWidget,
            reason:
                'editProfileFlow must show the same profileNameTaken '
                'feedback as profile_picker_screen.dart\'s rename dialog',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(Duration.zero);
        },
      );
    },
  );
}
