// Regression tests for PP-5: Curriculum-progress expanded breakdown shows
// two identical "Learn" stage columns.
//
// Root cause: DomainTermLabels.resolveStoredStageName has a defective
// _hebrewToEnglish reverse map.  The map is built from HebrewTerms.stageNameMap
// by iterating its entries and storing `hebrewValue → englishKey`.  Since both
// 'Chazara 1' and 'Review 1' map to 'חזרה א׳', the later entry ('Review 1')
// overwrites the earlier ('Chazara 1') in the reverse map.  The same applies
// to 'Chazara 2'/'Review 2'.  As a result:
//
//   resolveStoredStageName('חזרה א׳') in English mode → 'Review 1'
//                                                        (expected: 'Chazara 1')
//   resolveStoredStageName('חזרה ב׳') in English mode → 'Review 2'
//                                                        (expected: 'Chazara 2')
//
// The default DB seed stores stages as Hebrew ('לימוד', 'חזרה א׳', 'חזרה ב׳').
// In English mode the first two stages end up both reading wrong, producing a
// confusing breakdown row.  The curriculum-progress screen's StageBreakdownRow
// widget calls resolveStoredStageName for every StageBreakdownEntry.stageName
// field and renders whatever is returned.
//
// Fix: normalise 'Review N' → 'Chazara N' in _normaliseEnglishStageName so
// that the canonical transliteration is always used regardless of which
// English synonym the reverse map happened to land on.
@Tags(['core', 'labels', 'pp5'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';

void main() {
  group('PP-5 — resolveStoredStageName returns canonical Chazara N names', () {
    // ── English mode ─────────────────────────────────────────────────────────

    test('חזרה א׳ (DB default stage 2) resolves to "Chazara 1" in English mode',
        () {
      const terms = DomainTermLabels(false);
      expect(
        terms.resolveStoredStageName('חזרה א׳'),
        'Chazara 1',
        reason: 'Hebrew-stored stage 2 must display as "Chazara 1" in English '
            'mode, not the legacy alias "Review 1"',
      );
    });

    test('חזרה ב׳ (DB default stage 3) resolves to "Chazara 2" in English mode',
        () {
      const terms = DomainTermLabels(false);
      expect(
        terms.resolveStoredStageName('חזרה ב׳'),
        'Chazara 2',
        reason: 'Hebrew-stored stage 3 must display as "Chazara 2" in English '
            'mode, not the legacy alias "Review 2"',
      );
    });

    test('חזרה ג׳ resolves to "Chazara 3" in English mode', () {
      const terms = DomainTermLabels(false);
      expect(terms.resolveStoredStageName('חזרה ג׳'), 'Chazara 3');
    });

    // If the DB happens to have stored the English alias 'Review 1' directly,
    // that should also normalise to 'Chazara 1'.
    test('"Review 1" stored directly normalises to "Chazara 1"', () {
      const terms = DomainTermLabels(false);
      expect(
        terms.resolveStoredStageName('Review 1'),
        'Chazara 1',
        reason: '"Review 1" is a legacy alias; canonical display is "Chazara 1"',
      );
    });

    test('"Review 2" stored directly normalises to "Chazara 2"', () {
      const terms = DomainTermLabels(false);
      expect(terms.resolveStoredStageName('Review 2'), 'Chazara 2');
    });

    // 'Review' (without a number) maps to 'חזרה' (bare prefix). In English
    // mode this should resolve to 'Chazara' (canonical prefix).
    test('"Review" (bare) stored directly normalises to "Chazara"', () {
      const terms = DomainTermLabels(false);
      expect(
        terms.resolveStoredStageName('Review'),
        'Chazara',
        reason: '"Review" bare legacy alias must resolve to "Chazara"',
      );
    });

    // ── Hebrew mode — must be unchanged ──────────────────────────────────────

    test('חזרה א׳ stays חזרה א׳ in Hebrew mode', () {
      const terms = DomainTermLabels(true);
      expect(terms.resolveStoredStageName('חזרה א׳'), 'חזרה א׳');
    });

    test('חזרה ב׳ stays חזרה ב׳ in Hebrew mode', () {
      const terms = DomainTermLabels(true);
      expect(terms.resolveStoredStageName('חזרה ב׳'), 'חזרה ב׳');
    });

    // ── Full stage-name set: 4 stages should all be DISTINCT in English ──────

    test('four default stage names are all distinct in English mode', () {
      const terms = DomainTermLabels(false);
      // Default DB-stored Hebrew names as written by stage_definition_repository
      // ('לימוד' / 'חזרה א׳' / 'חזרה ב׳') plus a hypothetical third chazara.
      final resolved = [
        terms.resolveStoredStageName('לימוד'),   // stage 1
        terms.resolveStoredStageName('חזרה א׳'), // stage 2
        terms.resolveStoredStageName('חזרה ב׳'), // stage 3
        terms.resolveStoredStageName('חזרה ג׳'), // stage 4
      ];
      final distinct = resolved.toSet();
      expect(
        distinct.length,
        equals(4),
        reason: 'All four stage names must be distinct in English mode; '
            'got: $resolved',
      );
    });
  });
}
