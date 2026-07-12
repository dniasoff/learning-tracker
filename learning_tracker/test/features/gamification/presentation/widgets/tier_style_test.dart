/// Tests for [RewardTier.classify] and [TierStyle.forTier] (AUD-gamification-07).
///
/// Finding: [TierStyle.forTitle] (now [TierStyle.forTier]) used to key its
/// visual styling directly off the milestone's raw English display title --
/// a switch statement duplicating the 8 title strings that also live in
/// [RewardMilestoneService.defaultMilestoneLadder]. Nothing enforced that
/// the two stayed in sync: a future rename, typo fix, or localization of a
/// milestone title would silently fall through to the generic default
/// style, with zero test coverage to catch the regression.
///
/// This file pins:
///  - [RewardTier.classify] maps each of the 7 non-legend stock ladder
///    titles to its own distinct [RewardTier], and anything else
///    (including near-misses: wrong case, extra whitespace collapsed
///    differently, or a parent-configured custom title) to [RewardTier.custom].
///  - [TierStyle.forTier] returns a DISTINCT style for each of the 7 named
///    tiers.
///  - The legend override (`isLegend: true`) wins regardless of [RewardTier],
///    and [RewardTier.legend] / [RewardTier.custom] with `isLegend: false`
///    both resolve to the same neutral default style (this was already
///    true of the old `default:` switch branch -- [RewardTier.legend] never
///    reached the switch because the legend override always intercepted it
///    first for a real 'Legend Star' milestone).
@Tags(['gamification', 'tier_style'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_style.dart';

void main() {
  group('RewardTier.classify', () {
    const expected = {
      'Bronze Star': RewardTier.bronze,
      'Silver Star': RewardTier.silver,
      'Gold Star': RewardTier.gold,
      'Platinum Star': RewardTier.platinum,
      'Premium Star': RewardTier.premium,
      'Diamond Star': RewardTier.diamond,
      'Elite Star': RewardTier.elite,
      'Legend Star': RewardTier.legend,
    };

    expected.forEach((title, tier) {
      test('"$title" classifies as $tier', () {
        expect(RewardTier.classify(title), tier);
      });
    });

    test('classifies against the canonical ladder (no independent copy)', () {
      // The stock ladder has exactly 8 entries; classify must recognise
      // every one of them (sourced from the SAME
      // RewardMilestoneService.defaultMilestoneLadder, not a re-derived
      // duplicate list -- Evans re-derived-invariant fix).
      expect(RewardMilestoneService.defaultMilestoneLadder.length, 8);
      for (final tier in RewardMilestoneService.defaultMilestoneLadder) {
        expect(RewardTier.classify(tier.title), isNot(RewardTier.custom));
      }
    });

    test('trims surrounding whitespace before matching', () {
      expect(RewardTier.classify('  Bronze Star  '), RewardTier.bronze);
    });

    test('a parent-configured custom reward title classifies as custom', () {
      expect(RewardTier.classify('Ice Cream Trip'), RewardTier.custom);
    });

    test('a near-miss (wrong case) does NOT silently match a real tier', () {
      // Regression guard for the exact "why" in AUD-gamification-07: a
      // typo/case change must fall through to `custom`, not accidentally
      // keep matching, and not throw.
      expect(RewardTier.classify('bronze star'), RewardTier.custom);
    });

    test('empty title classifies as custom', () {
      expect(RewardTier.classify(''), RewardTier.custom);
    });
  });

  group('TierStyle.forTier — distinct styling per tier', () {
    const namedTiers = [
      RewardTier.bronze,
      RewardTier.silver,
      RewardTier.gold,
      RewardTier.platinum,
      RewardTier.premium,
      RewardTier.diamond,
      RewardTier.elite,
    ];

    test('all 7 named tiers produce pairwise-distinct card colors', () {
      final cardColors = <Color>{};
      for (final tier in namedTiers) {
        final style = TierStyle.forTier(tier, false);
        cardColors.add(style.cardBg);
      }
      expect(
        cardColors.length,
        namedTiers.length,
        reason:
            'Expected every named tier to render with a unique cardBg; a '
            'collision means two tiers are visually indistinguishable.',
      );
    });

    test('all 7 named tiers produce pairwise-distinct title colors', () {
      final titleColors = <Color>{};
      for (final tier in namedTiers) {
        final style = TierStyle.forTier(tier, false);
        titleColors.add(style.titleColor);
      }
      expect(titleColors.length, namedTiers.length);
    });

    test(
      'RewardTier.custom (isLegend: false) renders the neutral default style',
      () {
        final style = TierStyle.forTier(RewardTier.custom, false);
        expect(style.cardBg, Colors.white);
        expect(style.borderColor, const Color(0xFFE0E0E0));
      },
    );

    test('RewardTier.custom is visually distinct (by barFill accent) from all '
        '7 named tiers', () {
      // NOTE: cardBg/titleColor are NOT used for this check -- Silver
      // intentionally shares Colors.white/0xFF37474F with the neutral
      // default style (both are achromatic "steel grey" looks); that
      // overlap pre-dates this fix and is not something this finding
      // touches. barFill (the progress-bar accent) is the field that is
      // actually distinct for every named tier vs. the default.
      final defaultStyle = TierStyle.forTier(RewardTier.custom, false);
      for (final tier in namedTiers) {
        final style = TierStyle.forTier(tier, false);
        expect(
          style.barFill,
          isNot(defaultStyle.barFill),
          reason: '$tier must not share the default/custom barFill accent',
        );
      }
    });

    test('RewardTier.legend with isLegend:false resolves to the same neutral '
        'default style as RewardTier.custom (unreachable in practice: the '
        'legend override always intercepts a real Legend Star milestone '
        'first, see achievements_overview_provider.dart)', () {
      final legendFallback = TierStyle.forTier(RewardTier.legend, false);
      final customStyle = TierStyle.forTier(RewardTier.custom, false);
      expect(legendFallback.cardBg, customStyle.cardBg);
      expect(legendFallback.titleColor, customStyle.titleColor);
    });
  });

  group('TierStyle.forTier — isLegend override', () {
    test('isLegend:true wins regardless of tier', () {
      for (final tier in RewardTier.values) {
        final style = TierStyle.forTier(tier, true);
        expect(
          style.cardBg,
          Colors.transparent,
          reason: 'isLegend must override the tier-based lookup for $tier',
        );
        expect(style.titleColor, Colors.white);
      }
    });
  });
}
