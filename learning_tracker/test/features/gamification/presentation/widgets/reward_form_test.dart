/// Tests for [RewardForm] value equality (AUD-gamification-22).
///
/// RewardForm is held directly as [RewardConfigController]'s Notifier
/// state. Before this fix it was a hand-written class with no `==`/
/// `hashCode` override, so it fell back to identity equality: every
/// `copyWith()` call — including a no-op one — produced a referentially
/// distinct instance that Riverpod's default identity-based
/// `updateShouldNotify` always treated as changed, defeating
/// rebuild-skipping for every widget watching the controller.
@Tags(['gamification', 'reward_form'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/reward_form.dart';

void main() {
  group('RewardForm value equality', () {
    test(
      'two SEPARATELY-CONSTRUCTED instances (not const-canonicalized — see '
      'note below) with identical field values are == and share hashCode',
      () {
        // Deliberately NOT `const`: two `const RewardForm(...)` literals with
        // identical arguments are canonicalized to the SAME object by the
        // compiler, which would trivially pass under plain identity
        // equality and mask the exact bug this finding fixes (every
        // *runtime* copyWith() call producing a referentially distinct,
        // "unequal" instance). Routing both instances through a non-const
        // helper defeats that canonicalization so this test actually
        // exercises value equality.
        // The `RewardForm(` call below is intentionally non-const (see
        // above) — `const` would let the compiler canonicalize both calls
        // to the same object and defeat the point of this test.
        // ignore: prefer_const_constructors
        RewardForm build() => RewardForm(
          name: 'Gold Star',
          pointsText: '100',
          iconIndex: 3,
          editingMilestoneId: 'ms-1',
          loading: false,
        );
        final a = build();
        final b = build();

        expect(identical(a, b), isFalse); // sanity: genuinely distinct objects
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('separately-constructed default instances are == to each other', () {
      RewardForm build() => const RewardForm().copyWith();
      final a = build();
      final b = build();
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
    });

    test('a copyWith() no-op call produces a value equal to the original', () {
      const original = RewardForm(name: 'Silver Star', pointsText: '50');
      final copy = original.copyWith();
      expect(copy, equals(original));
      expect(copy.hashCode, equals(original.hashCode));
    });

    test('differing on a single field breaks equality', () {
      const a = RewardForm(name: 'Gold Star', pointsText: '100');
      const b = RewardForm(name: 'Silver Star', pointsText: '100');
      expect(a, isNot(equals(b)));
    });

    test('copyWith(editingMilestoneId: null) actually clears the field', () {
      const withMilestone = RewardForm(editingMilestoneId: 'ms-5');
      final cleared = withMilestone.copyWith(editingMilestoneId: null);
      expect(cleared.editingMilestoneId, isNull);
      expect(cleared, equals(const RewardForm()));
    });
  });
}
