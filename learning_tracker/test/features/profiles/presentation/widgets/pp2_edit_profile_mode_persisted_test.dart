/// Regression test for PP-2 — editProfileFlow silently drops the selected mode.
///
/// ROOT CAUSE: `editProfileFlow` in `profile_edit_delete_actions.dart` calls
/// `repo.updateProfile(id: …, displayName: …, avatarIndex: …)` but never
/// passes the `mode` from the dialog result. The [SegmentedButton] visibly
/// toggles `_mode` in `ProfileEditFormDialog`, but the value is discarded on
/// Save — only name and avatar are persisted.
///
/// This is a safety concern: a parent can believe they demoted an adult to child
/// (which gates adult surfaces behind a PIN) when nothing changed.
///
/// FIX: Pass `result.mode` to `repo.updateProfile(…, mode: result.mode)`.
@Tags(['unit', 'profiles', 'pp2'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_edit_delete_actions.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockProfileRepository extends Mock implements ProfileRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProfileModel _makeProfile({
  int id = 1,
  String displayName = 'Alice',
  String mode = 'adult',
  int avatarIndex = 0,
  int accountId = 10,
}) {
  return ProfileModel(
    id: id,
    ulid: 'ulid-$id',
    accountId: accountId,
    displayName: displayName,
    mode: mode,
    avatarIndex: avatarIndex,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

Widget _buildHarness({
  required ProfileRepository repo,
  required ProfileModel profile,
  required VoidCallback onEditPressed,
}) {
  return pumpApp(
    retry: (_, __) => null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      // Active profile + selected profile: needed by editProfileFlow invalidation.
      selectedProfileIdProvider.overrideWith(
        () => _FixedIdNotifier(profile.id),
      ),
      currentAccountIdProvider.overrideWithValue(profile.accountId),
    ],
    child: Consumer(
      builder: (ctx, ref, _) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              await editProfileFlow(ctx, ref, profile);
              onEditPressed();
            },
            child: const Text('edit'),
          ),
        ),
      ),
    ),
  );
}

class _FixedIdNotifier extends SelectedProfileId {
  _FixedIdNotifier(this._id);
  final int _id;
  @override
  int? build() => _id;
}

void main() {
  group('PP-2 — editProfileFlow persists selected mode', () {
    testWidgets(
      'PP-2 RED: changing mode from "adult" to "child" must pass mode to updateProfile',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _MockProfileRepository();
        final profile = _makeProfile(mode: 'adult');

        // Mock updateProfile to record the call — return same profile updated.
        when(
          () => repo.updateProfile(
            id: any(named: 'id'),
            displayName: any(named: 'displayName'),
            mode: any(named: 'mode'),
            avatarIndex: any(named: 'avatarIndex'),
          ),
        ).thenAnswer((_) async => _makeProfile(mode: 'child'));
        when(
          () => repo.getProfilesByAccount(any()),
        ).thenAnswer((_) async => [profile]);
        when(() => repo.getProfileById(any())).thenAnswer((_) async => profile);
        when(
          () => repo.countProfilesForAccount(any()),
        ).thenAnswer((_) async => 1);

        await tester.pumpWidget(
          _buildHarness(repo: repo, profile: profile, onEditPressed: () {}),
        );
        await tester.pump(const Duration(seconds: 1));

        // Open the edit dialog.
        await tester.tap(find.text('edit'));
        await tester.pump(const Duration(milliseconds: 300));

        // The dialog shows a SegmentedButton with "Child" and "Adult" segments.
        // Tap the "Child" segment to change mode from "adult" → "child".
        expect(
          find.textContaining('Child'),
          findsAtLeastNWidgets(1),
          reason: 'Edit dialog must show the mode SegmentedButton',
        );
        await tester.tap(find.textContaining('Child').first);
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Save.
        await tester.tap(find.text('Save'));
        await tester.pump(const Duration(milliseconds: 300));

        // The fix: updateProfile must have been called with mode: 'child'.
        // The bug: mode was not passed → updateProfile called without mode
        // (or with null mode) so the database kept 'adult'.
        final captured = verify(
          () => repo.updateProfile(
            id: 1,
            displayName: captureAny(named: 'displayName'),
            mode: captureAny(named: 'mode'),
            avatarIndex: captureAny(named: 'avatarIndex'),
          ),
        ).captured;

        // captured[1] is the mode value (second captureAny, named 'mode').
        // With the fix it must be 'child'.
        // With the bug it would be null or absent.
        expect(
          captured[1],
          equals('child'),
          reason:
              'updateProfile must be called with the newly-selected mode "child"; '
              'before the fix, mode was silently dropped from the call.',
        );
      },
    );
  });
}
