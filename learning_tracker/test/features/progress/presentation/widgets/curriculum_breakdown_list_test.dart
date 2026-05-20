/// Widget tests for [CurriculumBreakdownTreeNode] — covers Wave 7-B / F9:
///
///   * Provenance labels route through `AppLocalizations` and
///     [DomainTermLabels.chazaros] so hardcoded English strings are gone.
///   * Hebrew Terms toggle ON swaps the plural to "חזרות" inside the
///     English locale (script change without locale change).
///   * Hebrew locale produces the all-Hebrew form.
@Tags(['progress', 'lifetime_knowledge'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/curriculum_breakdown_list.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

void main() {
  group('CurriculumBreakdownTreeNode.provenanceText — F9 l10n', () {
    final enL10n = AppLocalizationsEn();
    final heL10n = AppLocalizationsHe();
    const enTerms = DomainTermLabels(false);
    const enHebrewTerms = DomainTermLabels(true);
    const heTerms = DomainTermLabels(true);

    test('live with chazarosCount = 0 returns the l10n "Live" string '
        'in English locale', () {
      const p = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: 0,
      );
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: enL10n,
          terms: enTerms,
        ),
        'Live',
      );
    });

    test('live with N chazaros combines the l10n prefix with the '
        'DomainTermLabels.chazaros plural (English)', () {
      const p = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: 3,
      );
      // Hebrew Terms OFF in EN locale: full English form.
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: enL10n,
          terms: enTerms,
        ),
        'Live · 3 Chazaros',
      );
    });

    test('Hebrew Terms toggle ON in EN locale swaps the plural to '
        'Hebrew script while keeping the "Live" prefix in English', () {
      const p = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: 5,
      );
      // EN locale + Hebrew Terms ON: "Live · 5 חזרות".
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: enL10n,
          terms: enHebrewTerms,
        ),
        'Live · 5 חזרות',
      );
    });

    test('Hebrew locale renders the all-Hebrew form', () {
      const p = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: 5,
      );
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: heL10n,
          terms: heTerms,
        ),
        'בלמידה · 5 חזרות',
      );
    });

    test('bulkMarked maps to the l10n string in both locales', () {
      const p = LifetimeLeafProvenance(
        source: LifetimeLeafSource.bulkMarked,
        chazarosCount: 1,
      );
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: enL10n,
          terms: enTerms,
        ),
        'Bulk-marked',
      );
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: heL10n,
          terms: heTerms,
        ),
        'מסומן בקבוצה',
      );
    });

    test('lifetimeImported maps to the l10n string in both locales', () {
      const p = LifetimeLeafProvenance(
        source: LifetimeLeafSource.lifetimeImported,
        chazarosCount: 0,
      );
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: enL10n,
          terms: enTerms,
        ),
        'Lifetime · imported',
      );
      expect(
        CurriculumBreakdownTreeNode.provenanceText(
          p,
          l10n: heL10n,
          terms: heTerms,
        ),
        'ייבוא לכל החיים',
      );
    });

    test('no hardcoded English "chazara" / "chazaros" leaks through any '
        'live count in the Hebrew locale (regression for F9)', () {
      for (final n in [1, 2, 3, 5, 10, 100]) {
        final out = CurriculumBreakdownTreeNode.provenanceText(
          LifetimeLeafProvenance(
            source: LifetimeLeafSource.live,
            chazarosCount: n,
          ),
          l10n: heL10n,
          terms: heTerms,
        );
        expect(
          out,
          isNot(contains('Live')),
          reason:
              'Hebrew locale must not contain the English word "Live" '
              '(found "$out" for chazarosCount=$n)',
        );
        expect(
          out,
          isNot(contains('chazara')),
          reason:
              'Hebrew locale must not contain the English transliteration '
              '(found "$out" for chazarosCount=$n)',
        );
      }
    });
  });

}
