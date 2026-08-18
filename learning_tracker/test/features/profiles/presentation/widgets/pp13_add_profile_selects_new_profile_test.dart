/// PP-13 regression test: After creating a child profile, the active-profile
/// context (selectedProfileIdProvider) must be updated to the new profile's id
/// before the forced Parent PIN setup dialog is shown.
///
/// RED → GREEN cycle:
///   RED:  showAddProfileDialog does NOT call selectedProfileIdProvider.select()
///         before showParentPinSetupDialog — the header behind the PIN dialog
///         still shows the previously-active profile's stale identity.
///   GREEN: selectedProfileIdProvider is set to the new child profile's id
///          before the PIN setup dialog runs.
@Tags(['profiles', 'pp13'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/add_profile_mode_pick_card.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(ProfileMode.adult);
  });

  group('PP-13 selectedProfileId updated before PIN setup', () {
    testWidgets('creates child profile: selectedProfileIdProvider switches to new id '
        'before PIN setup dialog opens', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const kPrevProfileId = 'ulid-prev-profile';
      const kNewProfileId = 'ulid-new-profile';

      final mockRepo = _MockProfileRepository();
      when(() => mockRepo.getProfiles()).thenAnswer((_) async => const []);
      when(
        () => mockRepo.createProfile(
          displayName: any(named: 'displayName'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer(
        (_) async => LearnerProfileEntity(
          profileId: kNewProfileId,
          displayName: 'Beni',
          mode: ProfileMode.child,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      // Capture selected id changes.
      final selectedIds = <String?>[];

      await tester.pumpWidget(
        pumpApp(
          overrides: [
            profileRepositoryProvider.overrideWithValue(mockRepo),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(kPrevProfileId),
            ),
          ],
          child: Consumer(
            builder: (ctx, ref, _) {
              final id = ref.watch(selectedProfileIdProvider);
              selectedIds.add(id);
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open'),
                    onPressed: () => showAddProfileDialog(ctx, ref),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      // Pre-condition: old profile is active (kPrevProfileId should be in captured list).
      expect(selectedIds.contains(kPrevProfileId), isTrue);

      // Open the dialog via onPressed callback to avoid InkSparkle shader.
      final openBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('open')),
      );
      openBtn.onPressed?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Type a profile name.
      await tester.enterText(find.byType(TextField).first, 'Beni');
      await tester.pump(const Duration(milliseconds: 400));

      // Child mode is the contract under test. Require the real mode card,
      // invoke its callback directly (avoids InkSparkle), and verify its
      // selected state changed before submitting.
      final childCard = find.ancestor(
        of: find.text('Child Mode'),
        matching: find.byType(AddProfileModePickCard),
      );
      expect(
        childCard,
        findsOneWidget,
        reason: 'The add-profile flow must expose the child-mode choice.',
      );
      expect(
        tester.widget<AddProfileModePickCard>(childCard).selected,
        isFalse,
      );
      tester.widget<AddProfileModePickCard>(childCard).onTap();
      await tester.pump();
      expect(
        tester.widget<AddProfileModePickCard>(childCard).selected,
        isTrue,
        reason: 'The child-mode choice must actually become selected.',
      );

      // Submit via Create Profile button callback (avoids InkSparkle).
      final createBtns = find.widgetWithText(FilledButton, 'Create Profile');
      expect(createBtns, findsOneWidget);
      final createButton = tester.widget<FilledButton>(createBtns);
      expect(
        createButton.onPressed,
        isNotNull,
        reason:
            'A named child profile should be creatable after mode selection.',
      );
      createButton.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PinKeypadDialogFrame), findsOneWidget);
      expect(find.text('Set Parent PIN'), findsOneWidget);

      // PP-13 fix: selectedProfileIdProvider must be updated to the new child.
      // The captured list should contain kNewProfileId after the create.
      expect(
        selectedIds.any((id) => id == kNewProfileId),
        isTrue,
        reason:
            'PP-13: selectedProfileIdProvider must be set to the newly-created '
            'child profile id ($kNewProfileId) before the PIN setup dialog runs. '
            'Observed ids: $selectedIds',
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}

class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._initial);
  final String? _initial;
  @override
  String? build() => _initial;
}
