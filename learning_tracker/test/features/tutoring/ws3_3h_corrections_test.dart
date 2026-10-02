// WS3.3h — Corrections (G3, DEC-33)
//
// Verifies that:
//   AC1 — AD-53 (DNI-487) superseded canBulkPriorCompletion: bulk-mark is a
//          learning edit gated by canEditLearning, which fails closed.
//   AC2 — parent_settings_screen.dart gates the bulk-mark tile on
//          canEditLearning (canBulkMark local var).
//   AC3 — accept_invite_screen.dart copy has been corrected: no longer says
//          "Configure curricula, goals, and study days" (too broad).
//          Now says "tracks, points, and rewards" (actual default editable set).
//   AC4 — manage_tutors_providers.dart no longer declares its own
//          tutorGrantRepositoryProvider (duplicate removed).
//          Instead it imports tutor_grant_providers.dart (the canonical one).

@Tags(['ws3', 'ws3_3h', 'tutor_mode'])
library;

import 'dart:io';

import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:test/test.dart';

void main() {
  group('WS3.3h — Corrections (G3, DEC-33)', () {
    late String parentSettingsSrc;
    late String acceptInviteSrc;
    late String manageTutorsProvidersSrc;
    // The accept-invite permission copy was localized (Rule 1): the user-facing
    // strings now live in the ARB, not as literals in the screen source.
    late String acceptInviteArbEn;

    setUpAll(() {
      parentSettingsSrc = File(
        'lib/features/profiles/presentation/screens/parent_settings_screen.dart',
      ).readAsStringSync();

      acceptInviteSrc = File(
        'lib/features/tutoring/presentation/screens/accept_invite_screen.dart',
      ).readAsStringSync();

      manageTutorsProvidersSrc = File(
        'lib/features/tutoring/presentation/providers/manage_tutors_providers.dart',
      ).readAsStringSync();

      acceptInviteArbEn = File('lib/l10n/app_en.arb').readAsStringSync();
    });

    // ── AC1: AD-53 single learning permission (DNI-487) ──────────────────────

    test('AC1: TutorPermissions default canEditLearning is false (AD-53)', () {
      const perms = TutorPermissions();
      expect(
        perms.canEditLearning,
        isFalse,
        reason:
            'AD-53: learning edits (incl. bulk-mark) need an explicit '
            'parent opt-in; a grant without the flag is read-only',
      );
    });

    test('AC1: canMarkLiveCompletion is always false (hard invariant)', () {
      const perms = TutorPermissions(canEditLearning: true);
      expect(
        perms.canMarkLiveCompletion,
        isFalse,
        reason:
            'canMarkLiveCompletion must always be false — '
            'tutors cannot mark live completions (cloud function enforces this)',
      );
    });

    test('AC1: TutorPermissions.readOnly() disables canEditLearning', () {
      final perms = TutorPermissions.readOnly();
      expect(
        perms.canEditLearning,
        isFalse,
        reason:
            'readOnly() factory must disable canEditLearning — '
            'a truly read-only grant can neither edit nor bulk-mark',
      );
    });

    // ── AC2: bulk-mark tile gated on canEditLearning (AD-53) ─────────────────

    test('AC2: parent_settings_screen gates bulk-mark tile on canBulkMark', () {
      expect(
        parentSettingsSrc,
        contains('canBulkMark'),
        reason:
            'parent_settings_screen.dart must compute canBulkMark from '
            'canEditLearning to gate the "Add What You Learned" tile '
            '(WS3.3h DEC-33)',
      );
    });

    test('AC2: canBulkMark is derived from the canEditLearning permission', () {
      expect(
        parentSettingsSrc,
        contains('final canBulkMark = canEditLearning;'),
        reason:
            'canBulkMark computation must reference canEditLearning '
            'from TutorPermissions',
      );
    });

    test('AC2: "Add What You Learned" tile is inside canBulkMark guard', () {
      final canBulkMarkIdx = parentSettingsSrc.indexOf('if (canBulkMark)');
      final addWhatYouLearnedIdx = parentSettingsSrc.indexOf(
        'addWhatYouLearned',
      );
      expect(canBulkMarkIdx, isNot(-1), reason: 'canBulkMark guard must exist');
      expect(
        addWhatYouLearnedIdx > canBulkMarkIdx,
        isTrue,
        reason:
            '"Add What You Learned" tile must appear after the canBulkMark '
            'guard (WS3.3h: bulk-mark UI gated on permission)',
      );
    });

    // ── AC3: accept-invite copy corrected ────────────────────────────────────

    test('AC3: accept-invite copy no longer says "curricula" (too broad)', () {
      // Checked across both the screen source and the localized ARB copy.
      expect(
        acceptInviteSrc,
        isNot(contains('Configure curricula, goals, and study days')),
        reason:
            'accept_invite_screen must not say "Configure curricula, goals, '
            'and study days" — those are optional permissions off by default, '
            'not part of the baseline editable set (WS3.3h)',
      );
      expect(
        acceptInviteArbEn,
        isNot(contains('Configure curricula, goals, and study days')),
      );
    });

    test(
      'AC3: accept-invite copy says "tracks, points, and rewards" (correct)',
      () {
        // The copy was localized (Rule 1) — assert the English ARB value.
        expect(
          acceptInviteArbEn,
          contains('tracks, points, and rewards'),
          reason:
              'acceptInvitePermissionConfigure (app_en.arb) must say "tracks, '
              'points, and rewards" — the actual default editable set '
              '(canEditLearning + canEditPoints + canEditRewards, parent-'
              'configurable) (WS3.3h DEC-33)',
        );
      },
    );

    test('AC3: Perform bulk-mark corrections copy remains', () {
      expect(
        acceptInviteArbEn,
        contains('Perform bulk-mark corrections'),
        reason:
            'acceptInvitePermissionBulkMark (app_en.arb) must still mention '
            'bulk-mark corrections (gated by canEditLearning, AD-53)',
      );
    });

    // ── AC4: Duplicate tutorGrantRepositoryProvider removed ──────────────────

    test('AC4: manage_tutors_providers.dart does not declare its own '
        'tutorGrantRepositoryProvider', () {
      // The old manual declaration:
      //   final tutorGrantRepositoryProvider = Provider<TutorGrantRepository>(...);
      // must be removed. The canonical one is in tutor_grant_providers.dart.
      expect(
        manageTutorsProvidersSrc,
        isNot(
          contains(
            'final tutorGrantRepositoryProvider = Provider<TutorGrantRepository>',
          ),
        ),
        reason:
            'manage_tutors_providers.dart must not declare its own '
            'tutorGrantRepositoryProvider — that was a duplicate causing two '
            'separate repository instances (WS3.3h)',
      );
    });

    test('AC4: manage_tutors_providers.dart imports tutor_grant_providers.dart '
        '(canonical repo provider)', () {
      expect(
        manageTutorsProvidersSrc,
        contains('tutor_grant_providers.dart'),
        reason:
            'manage_tutors_providers.dart must import tutor_grant_providers.dart '
            'to use the canonical tutorGrantRepositoryProvider',
      );
    });
  });
}
