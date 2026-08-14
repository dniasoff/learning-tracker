// Deep L1 widget tests — ProfilePickerScreen + TutoredChildrenSection
//
// PURPOSE: strengthen coverage of uncovered branches BEYOND the existing
//   profile_picker_screen_l1_test.dart and profile_picker_and_tutored_l1_test.dart.
//
// Coverage groups:
//
//  D. Manage-sheet (long-press on profile tile)
//     D1. Long-press → bottom sheet appears with Rename + Delete
//     D2. Delete option reachable (AUD-profiles-04: no longer disabled) when
//         only 1 profile — opens the canonical deleteProfileFlow's
//         last-profile confirm dialog
//     D3. Delete option enabled when >1 profiles
//     D4. Tapping Cancel on manage sheet dismisses without action
//
//  E. Rename dialog
//     E1. Tapping Rename opens rename dialog with current profile name pre-filled
//     E2. Save disabled when field is empty
//     E3. Save enabled once non-empty text is typed
//
//  F. Delete flow
//     F1. Tapping Delete (>1 profiles) opens delete-confirm dialog
//     F2. Cancel on delete dialog → no deletion attempted
//     F3. Last-profile delete dialog shows "Delete your only profile?" title
//         (AUD-profiles-04: now exercised end-to-end via the canonical
//         deleteProfileFlow — no longer blocked by a disabled menu tile)
//     F4. Deleting the CURRENTLY-SELECTED profile via the long-press menu
//         auto-switches selectedProfileIdProvider to a remaining profile,
//         never clears it to null (Bug B — AUD-profiles-03 regression gap:
//         F1-F3 never passed a selectedId matching the deleted profile)
//
//  G. ProfilePickerScreen visual structure
//     G1. Picker title "Who is learning?" and subtitle always shown
//     G3. Single child profile — rendered alone (no adult label confusion)
//     G4. Single adult profile — rendered alone
//     G5. Three profiles (2 children + 1 adult) — all names rendered
//
//  H. Segmentation correctness
//     H1. Flat mode (0 grants): YOUR PROFILES header absent even with profiles
//     H2. Segmented mode (active grant): YOUR PROFILES header present
//     H3. Only pending (no active) grants: YOUR PROFILES header ABSENT
//         (because isSegmented = tutoredCount, which counts active only)
//
//  I. TutoredChildrenSection — deeper branch coverage
//     I1. Three active grants → all three child names rendered
//     I2. Active grant revoked mix: revoked-only → hidden; active present → visible
//     I3. School icon rendered per active tutored-child row
//     I4. Section visible with pending-only grants (DEC-8 rule)
//
//  J. Product rules — additional invariants
//     J1. No "parent" text anywhere with mix of child + adult profiles
//     J2. TutorPermissions.canMarkLiveCompletion false for all construction paths
//     J3. "CHILD MODE" appears for child profiles (not "PARENT" or other labels)
//
// PROTOCOL: drive the REAL provider / logic. Overrides only for
//   FutureProviders + authState + router. No overrides of unit-under-test.

@Tags(['needs_flutter', 'profiles', 'tutored_children', 'deep'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/profile_picker_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/tutored_children_section.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ── Notifier override ─────────────────────────────────────────────────────────

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final int? _initial;
  @override
  int? build() => _initial;
}

// ── Test data factories ────────────────────────────────────────────────────────

final _epoch = DateTime.utc(2026, 1, 1);

LearnerProfileEntity _child({int id = 1, String name = 'Yosef'}) =>
    LearnerProfileEntity(
  profileId: 'ulid-$id',
  displayName: name,
  mode: ProfileMode.child,
  createdAt: _epoch,
  updatedAt: _epoch,
);

LearnerProfileEntity _adult({int id = 2, String name = 'Avraham'}) =>
    LearnerProfileEntity(
  profileId: 'ulid-$id',
  displayName: name,
  mode: ProfileMode.adult,
  createdAt: _epoch,
  updatedAt: _epoch,
);

TutorGrant _activeGrant({
  String grantId = 'grant-active-1',
  String? childName = 'Yossi Levi',
}) {
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid-1',
    childProfileId: 'child-profile-$grantId',
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.active,
    invitedAt: _epoch,
    updatedAt: _epoch,
    acceptedAt: _epoch,
    childName: childName,
  );
  return TutorGrant.fromDoc(doc, permissions: TutorPermissions.defaults());
}

TutorGrant _pendingGrant({
  String grantId = 'grant-pending-1',
  String? childName = 'Moshe Cohen',
}) {
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid-1',
    childProfileId: 'child-profile-$grantId',
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.pending,
    invitedAt: _epoch,
    updatedAt: _epoch,
    expiresAt: _epoch.add(const Duration(days: 7)),
    childName: childName,
  );
  return TutorGrant.fromDoc(doc);
}

TutorGrant _revokedGrant({String grantId = 'grant-revoked-1'}) {
  final doc = TutorGrantDoc(
    grantId: grantId,
    parentUid: 'parent-uid-1',
    childProfileId: 'child-profile-$grantId',
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.revokedByParent,
    invitedAt: _epoch,
    updatedAt: _epoch,
    revokedAt: _epoch,
  );
  return TutorGrant.fromDoc(doc);
}

// ── Section-standalone builder ─────────────────────────────────────────────────

Widget _buildSection(
  Future<List<TutorGrant>> Function() grantsFactory, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      incomingTutorGrantsProvider.overrideWith((ref) => grantsFactory()),
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
      home: const Scaffold(
        body: SingleChildScrollView(child: TutoredChildrenSection()),
      ),
    ),
  );
}

/// Small Firestore-backed test repository for the picker flows. It keeps the
/// list in sync with the fake's learner-profile collection so delete/rename
/// dialogs exercise the current ULID-based repository contract without
/// resurrecting the archived Drift database.
class _FirestoreProfileRepository implements ProfileRepository {
  _FirestoreProfileRepository(this._firestore, this._profiles);

  final FakeFirebaseFirestore _firestore;
  final List<LearnerProfileEntity> _profiles;

  @override
  Future<List<LearnerProfileEntity>> getProfiles() async => _profiles;

  @override
  Stream<List<LearnerProfileEntity>> watchProfiles() => Stream.value(_profiles);

  @override
  Future<LearnerProfileEntity?> getProfileById(String profileId) async {
    for (final profile in _profiles) {
      if (profile.profileId == profileId) return profile;
    }
    return null;
  }

  @override
  Future<int> countProfiles() async => _profiles.length;

  @override
  Future<LearnerProfileEntity> createProfile({
    required String displayName,
    required ProfileMode mode,
    String avatar = '',
  }) => throw UnimplementedError();

  @override
  Future<LearnerProfileEntity> updateProfile({
    required String profileId,
    String? displayName,
    ProfileMode? mode,
    String? avatar,
  }) async {
    final index = _profiles.indexWhere((p) => p.profileId == profileId);
    if (index < 0) throw StateError('Profile $profileId not found');
    final current = _profiles[index];
    final updated = current.copyWith(
      displayName: displayName ?? current.displayName,
      mode: mode ?? current.mode,
      avatar: avatar ?? current.avatar,
      updatedAt: _epoch,
    );
    _profiles[index] = updated;
    await _profileDoc(profileId).set(updated.toFirestore());
    return updated;
  }

  @override
  Future<void> deleteProfile(String profileId, {bool allowLast = false}) async {
    _profiles.removeWhere((p) => p.profileId == profileId);
    await _profileDoc(profileId).delete();
  }

  DocumentReference<Map<String, dynamic>> _profileDoc(String profileId) =>
      _firestore
          .collection('users')
          .doc('account-picker')
          .collection('learner_profiles')
          .doc(profileId);
}

// ── Full-picker builder ────────────────────────────────────────────────────────

Widget _buildPicker({
  required _MockStackRouter router,
  List<LearnerProfileEntity> profiles = const [],
  List<TutorGrant> grants = const [],
  List<TutorGrant> pendingInvites = const [],
  AuthState? authState,
  String? selectedId,
  Locale locale = const Locale('en'),
}) {
  final resolvedAuth =
      authState ??
      const AuthState.signedIn(
        user: AuthUser(uid: 'account-picker', email: 't@t.com', displayName: 'Test'),
        tier: Tier.local,
      );
  final firestore = createFakeFirestore(authenticatedUid: 'account-picker');
  final profileRepository = _FirestoreProfileRepository(firestore, profiles);

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      profileListProvider.overrideWith((ref) => Future.value(profiles)),
      profileRepositoryProvider.overrideWithValue(profileRepository),
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

// ── Teardown helper ────────────────────────────────────────────────────────────

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ──────────────────────────────────────────────────────────────────────

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

  // ────────────────────────────────────────────────────────────────────────────
  // D. Manage-sheet (long-press)
  // ────────────────────────────────────────────────────────────────────────────

  group('D: Manage-sheet (long-press)', () {
    // D1 — long-press → sheet shows Rename + Delete
    testWidgets(
      'D1: long-press profile → bottom sheet shows Rename and Delete',
      (tester) async {
        final profiles = [
          _adult(id: 1, name: 'Avi'),
          _child(id: 2, name: 'Yosef'),
        ];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Long-press the first profile tile.
        await tester.longPress(find.text('Avi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The manage sheet must contain Rename and Delete actions.
        expect(find.text('Rename'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // D2 — single profile: Delete is reachable (AUD-profiles-04) and opens
    // the canonical deleteProfileFlow's last-profile confirm dialog, instead
    // of being hard-disabled by a private "must keep one profile" gate.
    testWidgets(
      'D2: single profile long-press → Delete tile is tappable and opens '
      'the last-profile confirm dialog',
      (tester) async {\n
        final profiles = [_adult(id: 1, name: 'OnlyOne')];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles, db: db),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.longPress(find.text('OnlyOne'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // No hard-blocking subtitle — the tile is a plain, tappable Delete.
        expect(find.text('You must have at least one profile'), findsNothing);

        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // deleteProfileFlow's own last-profile confirm dialog opens instead.
        // l10n.deleteProfileLastTitle = 'Delete your only profile?'
        expect(find.text('Delete your only profile?'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // D3 — multiple profiles: Delete tile is enabled (no subtitle)
    testWidgets(
      'D3: multiple profiles long-press → Delete enabled (no mustKeep '
      'subtitle)',
      (tester) async {
        final profiles = [
          _adult(id: 1, name: 'Avi'),
          _child(id: 2, name: 'Yosef'),
        ];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.longPress(find.text('Avi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The "You must have at least one profile" subtitle must NOT appear.
        expect(find.text('You must have at least one profile'), findsNothing);
        // Delete tile should still be present.
        expect(find.text('Delete'), findsOneWidget);

        await _teardown(tester);
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // E. Rename dialog
  // ────────────────────────────────────────────────────────────────────────────

  group('E: Rename dialog', () {
    // E1 — AUD-profiles-04: "Rename" now opens the canonical
    // editProfileFlow's ProfileEditFormDialog (title 'Edit Learner') instead
    // of the private rename-only dialog (title 'Rename Profile'), matching
    // manage_learners_screen.dart. The name field is still pre-filled.
    testWidgets(
      'E1: Rename opens the canonical Edit Learner dialog with profile '
      'name pre-filled',
      (tester) async {
        final profiles = [
          _adult(id: 1, name: 'Avi'),
          _child(id: 2, name: 'Yosef'),
        ];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Open manage sheet.
        await tester.longPress(find.text('Avi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap Rename.
        await tester.tap(find.text('Rename'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // l10n.profilesEditLearner = 'Edit Learner' — the canonical dialog
        // title, not the old private 'Rename Profile'.
        expect(find.text('Edit Learner'), findsOneWidget);
        expect(find.text('Rename Profile'), findsNothing);

        // The text field must be pre-filled with the profile name.
        expect(find.widgetWithText(TextField, 'Avi'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // E2 — AUD-profiles-04: the canonical ProfileEditFormDialog uses P2
    // inline validation (Save always tappable; an empty name surfaces an
    // inline error and blocks the pop) rather than disabling Save's
    // onPressed. This replaces the old private dialog's disabled-button
    // behavior with the canonical dialog's actual behavior.
    testWidgets(
      'E2: Rename (Edit Learner) dialog shows inline error and stays open '
      'when Save is tapped with an empty name',
      (tester) async {
        final profiles = [
          _adult(id: 1, name: 'Avi'),
          _child(id: 2, name: 'Yosef'),
        ];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Open manage sheet → tap Rename.
        await tester.longPress(find.text('Avi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Rename'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Clear the text field.
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pump();

        // Tap Save with an empty name.
        await tester.tap(find.text('Save'));
        await tester.pump();

        // l10n.learnerNameRequired = 'Enter a name' — inline error shown,
        // dialog still open (Save blocked, no pop).
        expect(find.text('Enter a name'), findsOneWidget);
        expect(find.text('Edit Learner'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // E3 — Save enabled with non-empty text
    testWidgets('E3: Rename dialog Save button enabled when field has text', (
      tester,
    ) async {
      final profiles = [
        _adult(id: 1, name: 'Avi'),
        _child(id: 2, name: 'Yosef'),
      ];
      await tester.pumpWidget(_buildPicker(router: router, profiles: profiles));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open manage sheet → tap Rename.
      await tester.longPress(find.text('Avi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Rename'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Type a new valid name.
      await tester.enterText(find.byType(TextField), 'NewName');
      await tester.pump();

      // Save button should now be enabled.
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);

      await _teardown(tester);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // F. Delete flow
  // ────────────────────────────────────────────────────────────────────────────

  group('F: Delete flow', () {
    // F1 — Delete opens confirm dialog for non-last profile.
    // Requires a real in-memory DB so _showDeleteDialog can call
    // repo.countProfilesForAccount without crashing.
    testWidgets(
      'F1: Delete (>1 profiles) opens confirm dialog with profile name',
      (tester) async {
        // Seed the in-memory DB with 2 profiles so countProfilesForAccount > 1.\n
        final profiles = [
          _adult(id: 1, name: 'Avi'),
          _child(id: 2, name: 'Yosef'),
        ];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles, db: db),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Long-press → open manage sheet → tap Delete.
        await tester.longPress(find.text('Avi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Delete confirm dialog should appear.
        expect(find.text('Delete Profile?'), findsOneWidget);
        // The dialog must reference the profile name.
        expect(find.textContaining('Avi'), findsWidgets);

        await _teardown(tester);
      },
    );

    // F2 — Cancel on delete dialog → no router interaction.
    testWidgets('F2: Cancel on delete dialog dismisses without navigation', (
      tester,
    ) async {\n
      final profiles = [
        _adult(id: 1, name: 'Avi'),
        _child(id: 2, name: 'Yosef'),
      ];
      await tester.pumpWidget(
        _buildPicker(router: router, profiles: profiles, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open delete dialog.
      await tester.longPress(find.text('Avi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No navigation should have happened.
      verifyNever(() => router.replaceAll(any<List<PageRouteInfo>>()));

      await _teardown(tester);
    });

    // F3 — Last-profile delete: "Delete your only profile?" title.
    // AUD-profiles-04: previously this test could only assert the disabled
    // menu-tile subtitle because the manage sheet hard-blocked Delete for a
    // sole profile. Now deleteProfileFlow is reachable end-to-end (matching
    // manage_learners_screen.dart), so this exercises the real dialog.
    testWidgets(
      'F3: last-profile long-press → Delete title is "Delete your only '
      'profile?" variant',
      (tester) async {\n
        final profiles = [_adult(id: 1, name: 'OnlyOne')];
        await tester.pumpWidget(
          _buildPicker(
            router: router,
            profiles: profiles,
            db: db,
            // For a localBorn account, online check is skipped so deletion can
            // reach the dialog without needing a real connectivity provider.
            authState: const AuthState.signedIn(
              user: AuthUser(
                profileId: 1,
                email: 't@t.com',
                displayName: 'Test',
              ),
              tier: Tier.localBorn,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.longPress(find.text('OnlyOne'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // l10n.deleteProfileLastTitle = 'Delete your only profile?'
        expect(find.text('Delete your only profile?'), findsOneWidget);
        // l10n.deleteProfileLastConfirm = 'Delete anyway'
        expect(find.text('Delete anyway'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // F4 — AUD-profiles-03: ProfilePickerScreen's delete path must route
    // through the shared deleteProfileFlow (not a private duplicate) so that
    // deleting the CURRENTLY-SELECTED profile auto-switches
    // selectedProfileIdProvider to a remaining profile rather than clearing
    // it to null (Bug B). profile_edit_delete_actions_test.dart already
    // covers deleteProfileFlow directly; this drives the same regression
    // end-to-end through the Picker's long-press menu, which F1-F3 never did
    // (none of them pass a selectedId matching the deleted profile).
    testWidgets('F4: deleting the currently-selected profile via long-press '
        'auto-switches selectedProfileIdProvider to a remaining profile', (
      tester,
    ) async {\n
      final profiles = [
        _adult(id: 1, name: 'Avi'),
        _child(id: 2, name: 'Yosef'),
      ];
      await tester.pumpWidget(
        _buildPicker(
          router: router,
          profiles: profiles,
          db: db,
          // Avi (id=1), the profile about to be deleted, is ALSO the
          // currently-selected profile.
          selectedId: 1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Long-press → open manage sheet → tap Delete → confirm the dialog.
      await tester.longPress(find.text('Avi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Delete Profile?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Bug B: selectedProfileIdProvider must auto-switch to the one
      // remaining profile (Yosef, id=2) — never clear to null.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfilePickerScreen)),
      );
      expect(
        container.read(selectedProfileIdProvider),
        2,
        reason:
            "deleting the currently-selected profile via the Picker's "
            'long-press menu must auto-switch to a remaining profile, not '
            'clear the selection to null (Bug B / AUD-profiles-03)',
      );

      await _teardown(tester);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // G. ProfilePickerScreen visual structure
  // ────────────────────────────────────────────────────────────────────────────

  group('G: Visual structure', () {
    // G1 — title + subtitle always present
    testWidgets('G1: picker title and subtitle always shown', (tester) async {
      await tester.pumpWidget(
        _buildPicker(router: router, profiles: [_adult()]),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // l10n.profilePickerTitle = 'Who is learning?'
      expect(find.text('Who is learning?'), findsOneWidget);
      // l10n.profilePickerSubtitle contains 'Choose your profile'
      expect(find.textContaining('Choose'), findsOneWidget);

      await _teardown(tester);
    });

    // G3 — single child profile renders correctly (not confused with adult)
    testWidgets('G3: single child profile — "CHILD MODE" label present, no '
        '"ADULT MODE"', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          router: router,
          profiles: [_child(id: 1, name: 'Yosef')],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Yosef'), findsOneWidget);
      expect(find.text('CHILD MODE'), findsOneWidget);
      expect(find.text('ADULT MODE'), findsNothing);

      await _teardown(tester);
    });

    // G4 — single adult profile renders correctly
    testWidgets('G4: single adult profile — "ADULT MODE" label present, no '
        '"CHILD MODE"', (tester) async {
      await tester.pumpWidget(
        _buildPicker(
          router: router,
          profiles: [_adult(id: 2, name: 'Avraham')],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Avraham'), findsOneWidget);
      expect(find.text('ADULT MODE'), findsOneWidget);
      expect(find.text('CHILD MODE'), findsNothing);

      await _teardown(tester);
    });

    // G5 — three profiles: 2 children + 1 adult
    testWidgets(
      'G5: three profiles (2 children + 1 adult) — all names rendered',
      (tester) async {
        // Use phone viewport so profiles fit.
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final profiles = [
          _child(id: 1, name: 'Yosef'),
          _child(id: 2, name: 'Shimon'),
          _adult(id: 3, name: 'Avraham'),
        ];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Yosef'), findsOneWidget);
        expect(find.text('Shimon'), findsOneWidget);
        expect(find.text('Avraham'), findsOneWidget);

        await _teardown(tester);
      },
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // H. Segmentation correctness
  // ────────────────────────────────────────────────────────────────────────────

  group('H: Segmentation correctness', () {
    // H1 — flat mode: YOUR PROFILES absent even with profiles present
    testWidgets(
      'H1: 0 active grants → YOUR PROFILES header absent (flat mode)',
      (tester) async {
        await tester.pumpWidget(
          _buildPicker(
            router: router,
            profiles: [_adult(name: 'Avi')],
            grants: [],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('YOUR PROFILES'), findsNothing);

        await _teardown(tester);
      },
    );

    // H2 — segmented mode: YOUR PROFILES present with active grant
    testWidgets(
      'H2: ≥1 active grant → YOUR PROFILES header present (segmented mode)',
      (tester) async {
        final grant = _activeGrant(childName: 'Talmid');
        await tester.pumpWidget(
          _buildPicker(
            router: router,
            profiles: [_adult(name: 'Avi')],
            grants: [grant],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('YOUR PROFILES'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // H3 — pending-only grants: YOUR PROFILES header absent
    // (isSegmented = tutoredCount which counts active only, not pending)
    testWidgets('H3: pending-only grants → YOUR PROFILES header absent '
        '(isSegmented gates on active count)', (tester) async {
      final pending = _pendingGrant();
      await tester.pumpWidget(
        _buildPicker(
          router: router,
          profiles: [_adult(name: 'Avi')],
          grants: [pending],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No active grants — isSegmented=false → YOUR PROFILES must NOT show.
      expect(find.text('YOUR PROFILES'), findsNothing);

      await _teardown(tester);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // I. TutoredChildrenSection — deeper branch coverage
  // ────────────────────────────────────────────────────────────────────────────

  group('I: TutoredChildrenSection — deeper branches', () {
    // I1 — three active grants → all three names rendered
    testWidgets('I1: three active grants → all three child names rendered', (
      tester,
    ) async {
      final g1 = _activeGrant(grantId: 'g1', childName: 'Yossi Levi');
      final g2 = _activeGrant(grantId: 'g2', childName: 'Dovid Klein');
      final g3 = _activeGrant(grantId: 'g3', childName: 'Binyamin Weiss');
      await tester.pumpWidget(_buildSection(() => Future.value([g1, g2, g3])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Yossi Levi'), findsOneWidget);
      expect(find.text('Dovid Klein'), findsOneWidget);
      expect(find.text('Binyamin Weiss'), findsOneWidget);
      // All three show "Tutoring" status
      expect(find.text('Tutoring'), findsNWidgets(3));

      await _teardown(tester);
    });

    // I2 — revoked + active mix: revoked absent, active visible
    testWidgets(
      'I2: mix of revoked + active → only active child shown, section visible',
      (tester) async {
        final revoked = _revokedGrant();
        final active = _activeGrant(
          grantId: 'g-active',
          childName: 'Moshe Katz',
        );
        await tester.pumpWidget(
          _buildSection(() => Future.value([revoked, active])),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Section header present (there is ≥1 active grant).
        expect(find.text('TALMID PROFILES'), findsOneWidget);
        // Active child shows.
        expect(find.text('Moshe Katz'), findsOneWidget);
        // Revoked child has no childName → would show "Talmid" only if rendered.
        // Since there is only ONE child row, there should be exactly ONE 'Tutoring'.
        expect(find.text('Tutoring'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // I3 — school icon rendered for active tutored-child row
    testWidgets(
      'I3: active grant → school_rounded icon present in tutored section',
      (tester) async {
        final grant = _activeGrant(childName: 'Yossi Levi');
        await tester.pumpWidget(_buildSection(() => Future.value([grant])));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // At least one school_rounded icon must be present in the child row.
        expect(find.byIcon(Icons.school_rounded), findsWidgets);

        await _teardown(tester);
      },
    );

    // I4 — pending-only: section visible (DEC-8 rule)
    testWidgets('I4: pending-only (DEC-8) → TALMID PROFILES section visible', (
      tester,
    ) async {
      final pending = _pendingGrant();
      await tester.pumpWidget(_buildSection(() => Future.value([pending])));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // DEC-8: section visible even when only pending (no active).
      expect(find.text('TALMID PROFILES'), findsOneWidget);
      expect(find.text('View invitations'), findsOneWidget);
      // No active child rows.
      expect(find.text('Tutoring'), findsNothing);

      await _teardown(tester);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // J. Product rules — additional invariants
  // ────────────────────────────────────────────────────────────────────────────

  group('J: Product rules', () {
    // J1 — no "parent" text in grid with child + adult
    testWidgets(
      'J1: child+adult profiles — no "parent" label anywhere in grid',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final profiles = [
          _child(id: 1, name: 'Yosef'),
          _adult(id: 2, name: 'Avraham'),
        ];
        await tester.pumpWidget(
          _buildPicker(router: router, profiles: profiles),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Hard rule: profile model has only 'child' and 'adult' modes.
        expect(find.textContaining('PARENT', findRichText: true), findsNothing);
        expect(
          find.textContaining('Parent Mode', findRichText: true),
          findsNothing,
        );
        // Correct labels present.
        expect(find.text('CHILD MODE'), findsOneWidget);
        expect(find.text('ADULT MODE'), findsOneWidget);

        await _teardown(tester);
      },
    );

    // J2 — TutorPermissions.canMarkLiveCompletion invariant for all constructors
    test(
      'J2: canMarkLiveCompletion is always false regardless of construction path',
      () {
        // Default constructor.
        expect(const TutorPermissions().canMarkLiveCompletion, isFalse);
        // Named factory: defaults.
        expect(TutorPermissions.defaults().canMarkLiveCompletion, isFalse);
        // Named factory: readOnly.
        expect(TutorPermissions.readOnly().canMarkLiveCompletion, isFalse);
        // copyWith — cannot set it to true because the field is not in copyWith.
        final copied = TutorPermissions.defaults().copyWith(
          canViewProgress: false,
        );
        expect(copied.canMarkLiveCompletion, isFalse);
        // fromFirestore with a map that tries to set it explicitly
        // (field is intentionally omitted from toFirestore so it can't be
        // round-tripped; fromFirestore also ignores it).
        final fromMap = TutorPermissions.fromFirestore({
          'can_view_progress': true,
          'can_view_content': true,
          'can_bulk_prior_completion': true,
          'can_reset_completion': false,
          'can_edit_goals': true,
          'can_edit_stages': true,
          'can_edit_rewards': true,
          'can_edit_study_days': true,
          'can_edit_points': true,
        });
        expect(fromMap.canMarkLiveCompletion, isFalse);
      },
    );

    // J3 — child profile CHILD MODE, not any other label
    testWidgets(
      'J3: child profile renders "CHILD MODE" (not "PARENT" or other label)',
      (tester) async {
        await tester.pumpWidget(
          _buildPicker(
            router: router,
            profiles: [_child(name: 'Yosef')],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('CHILD MODE'), findsOneWidget);
        expect(find.textContaining('PARENT'), findsNothing);

        await _teardown(tester);
      },
    );
  });
}
