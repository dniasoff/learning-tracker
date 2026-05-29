// WS3.3d — Combined tutor surface: permissions gate (DEC-9, DEC-14) [gated by 3c]
//
// Verifies that:
//   AC1 — activeTutorPermissionsProvider is declared in
//          active_tutored_profile_provider.dart (reads from active selection).
//   AC2 — parent_settings_screen.dart gates edit tiles behind
//          activeTutorPermissionsProvider (canEditStages, canEditGoals,
//          canEditRewards).
//   AC3 — parent_settings_screen.dart hides owner-only tiles (manageTutors,
//          BackupSyncSection, sectionAccountSafety) when in tutored context.
//   AC4 — permissions_provider.dart is deleted (dead code — zero call sites).
//   AC5 — TutorPermissions domain logic: field defaults and copyWith round-trip.

@Tags(['ws3', 'ws3_3d', 'tutor_mode'])
library;

import 'dart:io';

import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:test/test.dart';

void main() {
  group('WS3.3d — Combined tutor surface (DEC-9, DEC-14)', () {
    late String activeTutoredSrc;
    late String parentSettingsSrc;

    setUpAll(() {
      activeTutoredSrc = File(
        'lib/features/tutoring/presentation/providers/active_tutored_profile_provider.dart',
      ).readAsStringSync();

      parentSettingsSrc = File(
        'lib/features/profiles/presentation/screens/parent_settings_screen.dart',
      ).readAsStringSync();
    });

    // ── AC1: activeTutorPermissionsProvider declared ──────────────────────────

    test(
      'AC1: activeTutorPermissionsProvider is declared in the provider file',
      () {
        expect(
          activeTutoredSrc,
          contains('activeTutorPermissionsProvider'),
          reason:
              'activeTutorPermissionsProvider must be declared in '
              'active_tutored_profile_provider.dart (WS3.3d DEC-9)',
        );
      },
    );

    test(
      'AC1: activeTutorPermissionsProvider reads activeTutoredProfileSelectionProvider',
      () {
        expect(
          activeTutoredSrc,
          contains('activeTutoredProfileSelectionProvider'),
          reason:
              'activeTutorPermissionsProvider must watch '
              'activeTutoredProfileSelectionProvider to derive TutorPermissions',
        );
      },
    );

    test(
      'AC1: activeTutorPermissionsProvider returns TutorPermissions type',
      () {
        expect(
          activeTutoredSrc,
          contains('TutorPermissions'),
          reason:
              'activeTutorPermissionsProvider must return TutorPermissions? '
              'to expose the active grant permissions to UI',
        );
      },
    );

    // ── AC2: parent_settings_screen gates edit tiles ──────────────────────────

    test(
      'AC2: parent_settings_screen watches activeTutorPermissionsProvider',
      () {
        expect(
          parentSettingsSrc,
          contains('activeTutorPermissionsProvider'),
          reason:
              'parent_settings_screen.dart must watch activeTutorPermissionsProvider '
              'to gate edit tiles in tutored mode (WS3.3d DEC-14)',
        );
      },
    );

    test('AC2: Manage Tracks tile gated on canEditStages', () {
      expect(
        parentSettingsSrc,
        contains('canEditStages'),
        reason:
            'parent_settings_screen.dart must gate the Manage Tracks tile '
            'on canEditStages (stage config = track config)',
      );
    });

    test('AC2: Point Configuration tile gated on canEditGoals', () {
      expect(
        parentSettingsSrc,
        contains('canEditGoals'),
        reason:
            'parent_settings_screen.dart must gate the Point Configuration tile '
            'on canEditGoals',
      );
    });

    test('AC2: Reward Configuration tile gated on canEditRewards', () {
      expect(
        parentSettingsSrc,
        contains('canEditRewards'),
        reason:
            'parent_settings_screen.dart must gate the Reward Configuration tile '
            'on canEditRewards',
      );
    });

    // ── AC3: Owner-only tiles hidden in tutored context ───────────────────────

    test('AC3: Manage Tutors tile hidden in tutored context', () {
      // Must use showOwnerOnlyTiles (or equivalent) to hide manageTutors.
      expect(
        parentSettingsSrc,
        contains('showOwnerOnlyTiles'),
        reason:
            'parent_settings_screen.dart must gate the Manage Tutors tile on '
            'showOwnerOnlyTiles (hidden when activeTutorPermissionsProvider is non-null)',
      );
    });

    test('AC3: BackupSyncSection hidden in tutored context', () {
      // BackupSyncSection must be inside the showOwnerOnlyTiles guard.
      // Simple proxy: both 'showOwnerOnlyTiles' and 'BackupSyncSection' appear
      // in the same file and the section guards the backup widget.
      expect(
        parentSettingsSrc,
        contains('BackupSyncSection'),
        reason: 'BackupSyncSection must still exist in the file',
      );
      // Verify that the backup section is guarded (appears after showOwnerOnlyTiles).
      final ownerIdx = parentSettingsSrc.indexOf('showOwnerOnlyTiles');
      final backupIdx = parentSettingsSrc.indexOf('BackupSyncSection');
      expect(
        backupIdx > ownerIdx,
        isTrue,
        reason:
            'BackupSyncSection must appear inside the showOwnerOnlyTiles guard '
            '(tutors must not see Backup & Sync)',
      );
    });

    test('AC3: sectionAccountSafety hidden in tutored context', () {
      final ownerIdx = parentSettingsSrc.indexOf('showOwnerOnlyTiles');
      final safetyIdx = parentSettingsSrc.indexOf('sectionAccountSafety');
      expect(
        safetyIdx > ownerIdx,
        isTrue,
        reason:
            'sectionAccountSafety (sign out / delete account) must appear '
            'inside the showOwnerOnlyTiles guard',
      );
    });

    // ── AC4: permissions_provider.dart deleted ────────────────────────────────

    test('AC4: permissions_provider.dart no longer exists', () {
      final file = File(
        'lib/features/tutoring/presentation/providers/permissions_provider.dart',
      );
      expect(
        file.existsSync(),
        isFalse,
        reason:
            'permissions_provider.dart must be deleted — it had zero real call '
            'sites and a stale "static owner session" header (WS3.3d clean-up)',
      );
    });

    // ── AC5: TutorPermissions domain logic ───────────────────────────────────

    test('AC5: TutorPermissions default constructor has expected defaults', () {
      const perms = TutorPermissions();
      expect(perms.canViewProgress, isTrue);
      expect(perms.canViewContent, isTrue);
      expect(perms.canBulkPriorCompletion, isTrue);
      expect(perms.canResetCompletion, isFalse);
      // DEC: tutor defaults now grant full parent-equivalent edit access
      // (manage the talmid's goals/stages/rewards/study-days/points). Only
      // live completion-marking is barred. TutorPermissions.readOnly() opts
      // every edit flag back out.
      expect(perms.canEditGoals, isTrue);
      expect(perms.canEditStages, isTrue);
      expect(perms.canEditRewards, isTrue);
      expect(perms.canEditStudyDays, isTrue);
      expect(perms.canEditPoints, isTrue);
      // Hard invariant.
      expect(perms.canMarkLiveCompletion, isFalse);
    });

    test('AC5: TutorPermissions.copyWith updates individual fields', () {
      // Start from readOnly() (all edit flags false) so we can prove copyWith
      // flips individual fields on without disturbing the rest. (The default
      // TutorPermissions() now has every edit flag true — see defaults test.)
      final base = TutorPermissions.readOnly();
      final updated = base.copyWith(canEditRewards: true, canEditGoals: true);
      expect(updated.canEditRewards, isTrue);
      expect(updated.canEditGoals, isTrue);
      // Unchanged fields preserved.
      expect(updated.canEditStages, isFalse);
      expect(updated.canEditStudyDays, isFalse);
      // Hard invariant survives copyWith.
      expect(updated.canMarkLiveCompletion, isFalse);
    });

    test('AC5: TutorPermissions equality and hash', () {
      const a = TutorPermissions(canEditRewards: true);
      const b = TutorPermissions(canEditRewards: true);
      const c = TutorPermissions(canEditRewards: false);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
