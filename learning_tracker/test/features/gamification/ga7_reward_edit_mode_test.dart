/// GA-7 regression test — Reward edit mode is indistinguishable from create;
/// empty-name save is a silent no-op.
///
/// Root cause:
///   1. Opening edit loads the reward but the heading/subtitle/button stay
///      "Configure New Reward" / new-reward copy even when editingMilestoneId
///      is set — the form provides no edit-mode state the UI can key off.
///   2. Save is always enabled (button not disabled when name is empty or cost
///      is invalid); tapping with empty name/cost returns RewardSaveInvalidInput
///      which is handled as a silent no-op.
///
/// Fix:
///   1. Expose an `isEditing` getter on RewardForm so the screen can switch
///      the heading/subtitle/button to edit-mode copy when editing.
///   2. The save button must be disabled when the form state is invalid
///      (name empty or cost 0). Expose `canSave` on RewardForm.
///
/// RED → GREEN: tests fail before isEditing/canSave are added, and pass after.
@Tags(['gamification', 'ga7'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';

void main() {
  group('GA-7: RewardForm.isEditing distinguishes edit from create', () {
    test('isEditing is false when editingMilestoneId is null (create mode)', () {
      const form = RewardForm();
      expect(
        form.isEditing,
        isFalse,
        reason:
            'Fresh form with no editingMilestoneId must report isEditing=false',
      );
    });

    test('isEditing is true when editingMilestoneId is set (edit mode)', () {
      const form = RewardForm(editingMilestoneId: 'ms-abc-123');
      expect(
        form.isEditing,
        isTrue,
        reason: 'Form with editingMilestoneId set must report isEditing=true',
      );
    });

    test('isEditing switches from false to true when milestone is applied', () {
      const createForm = RewardForm();
      expect(createForm.isEditing, isFalse);

      final editForm = createForm.copyWith(editingMilestoneId: 'ms-xyz');
      expect(editForm.isEditing, isTrue);
    });

    test(
      'isEditing switches back to false after clearForm (editingMilestoneId=null)',
      () {
        const editForm = RewardForm(editingMilestoneId: 'ms-clear-me');
        expect(editForm.isEditing, isTrue);

        final cleared = editForm.copyWith(editingMilestoneId: null);
        expect(cleared.isEditing, isFalse);
      },
    );
  });

  group('GA-7: RewardForm.canSave — Save button enabled/disabled logic', () {
    test('canSave is false when name is empty', () {
      const form = RewardForm(name: '', pointsText: '100');
      expect(form.canSave, isFalse, reason: 'Empty name must disable Save');
    });

    test('canSave is false when name is whitespace-only', () {
      const form = RewardForm(name: '   ', pointsText: '100');
      expect(
        form.canSave,
        isFalse,
        reason: 'Whitespace-only name must disable Save',
      );
    });

    test('canSave is false when pointsText is empty', () {
      const form = RewardForm(name: 'Gold Star', pointsText: '');
      expect(form.canSave, isFalse, reason: 'Empty points must disable Save');
    });

    test('canSave is false when pointsText is zero', () {
      const form = RewardForm(name: 'Gold Star', pointsText: '0');
      expect(form.canSave, isFalse, reason: 'Zero points must disable Save');
    });

    test('canSave is false when pointsText is non-numeric', () {
      const form = RewardForm(name: 'Gold Star', pointsText: 'abc');
      expect(
        form.canSave,
        isFalse,
        reason: 'Non-numeric points must disable Save',
      );
    });

    test('canSave is false when name is empty and points is also invalid', () {
      const form = RewardForm(name: '', pointsText: '0');
      expect(form.canSave, isFalse);
    });

    test(
      'canSave is true when name is non-empty and points is positive integer',
      () {
        const form = RewardForm(name: 'Silver Star', pointsText: '500');
        expect(
          form.canSave,
          isTrue,
          reason: 'Valid name + positive points must enable Save',
        );
      },
    );

    test('canSave is true for name="A" and points="1"', () {
      const form = RewardForm(name: 'A', pointsText: '1');
      expect(form.canSave, isTrue);
    });

    test('canSave works for edit mode (editingMilestoneId set)', () {
      const form = RewardForm(
        name: 'Renamed Reward',
        pointsText: '300',
        editingMilestoneId: 'ms-edit',
      );
      expect(
        form.canSave,
        isTrue,
        reason: 'Valid edit form should also report canSave=true',
      );
    });

    test('canSave is false for edit mode with empty name', () {
      const form = RewardForm(
        name: '',
        pointsText: '300',
        editingMilestoneId: 'ms-edit',
      );
      expect(form.canSave, isFalse);
    });
  });
}
