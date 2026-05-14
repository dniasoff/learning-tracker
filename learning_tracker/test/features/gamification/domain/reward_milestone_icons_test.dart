// Tests for RewardMilestoneIcons — covers clampIndex (lines 27-31)
// and iconForIndex (line 34).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';

void main() {
  group('RewardMilestoneIcons.clampIndex', () {
    test('valid index returns unchanged', () {
      expect(RewardMilestoneIcons.clampIndex(0), 0);
      expect(RewardMilestoneIcons.clampIndex(1), 1);
    });

    test('negative index returns 0', () {
      expect(RewardMilestoneIcons.clampIndex(-1), 0);
      expect(RewardMilestoneIcons.clampIndex(-100), 0);
    });

    test('index beyond list returns last valid index', () {
      final last = RewardMilestoneIcons.choices.length - 1;
      expect(RewardMilestoneIcons.clampIndex(1000), last);
    });

    test('choices list is non-empty', () {
      expect(RewardMilestoneIcons.choices, isNotEmpty);
    });
  });

  group('RewardMilestoneIcons.iconForIndex', () {
    test('returns icon for valid index', () {
      final icon = RewardMilestoneIcons.iconForIndex(0);
      expect(icon, RewardMilestoneIcons.choices[0]);
    });

    test('returns last icon for out-of-range index', () {
      final last = RewardMilestoneIcons.choices.length - 1;
      final icon = RewardMilestoneIcons.iconForIndex(9999);
      expect(icon, RewardMilestoneIcons.choices[last]);
    });

    test('returns first icon for negative index', () {
      final icon = RewardMilestoneIcons.iconForIndex(-5);
      expect(icon, RewardMilestoneIcons.choices[0]);
    });
  });
}
