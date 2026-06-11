// Regression tests for IL-5 (stage-name mapping: stage 1 shows "Learn" not "Limud").
//
// Root cause: stageLearn getter returns HebrewTerms.stageLearnEn='Learn' (legacy
// English DB value) instead of the canonical transliteration "Limud" that
// DomainTermLabels.limud already returns. resolveStoredStageName likewise passes
// the legacy "Learn" string straight through in English mode.
//
// Fix: stageLearn getter in English mode must return "Limud" (same as limud getter).
// resolveStoredStageName must normalise the stored "Learn" key to "Limud" in
// English mode (the stageNameMap key 'Learn' maps to the Hebrew form לימוד, so
// the reverse direction should normalise to "Limud", not the raw stored key).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';

void main() {
  group('IL-5 — stageLearn returns canonical "Limud" in English mode', () {
    test('stageLearn English mode returns "Limud"', () {
      const terms = DomainTermLabels(false); // English mode
      expect(
        terms.stageLearn,
        'Limud',
        reason:
            'English stage-0 label must be "Limud" (canonical transliteration), '
            'not "Learn" (legacy DB value)',
      );
    });

    test('stageLearn Hebrew mode returns Hebrew "לימוד"', () {
      const terms = DomainTermLabels(true); // Hebrew mode
      expect(terms.stageLearn, 'לימוד');
    });

    test('stageName(0) English mode returns "Limud"', () {
      const terms = DomainTermLabels(false);
      expect(terms.stageName(0), 'Limud');
    });

    test('stageName(0) Hebrew mode returns Hebrew', () {
      const terms = DomainTermLabels(true);
      expect(terms.stageName(0), 'לימוד');
    });

    test('stageNameFromStageId(1) English mode returns "Limud"', () {
      const terms = DomainTermLabels(false);
      // stageId=1 is the Learn stage (1-based).
      expect(terms.stageNameFromStageId(1), 'Limud');
    });
  });

  group('IL-5 — resolveStoredStageName normalises "Learn" to "Limud"', () {
    test('resolveStoredStageName("Learn") English mode returns "Limud"', () {
      const terms = DomainTermLabels(false);
      expect(
        terms.resolveStoredStageName('Learn'),
        'Limud',
        reason:
            '"Learn" is the legacy DB key; English display should be "Limud"',
      );
    });

    test('resolveStoredStageName("לימוד") English mode returns "Limud"', () {
      const terms = DomainTermLabels(false);
      // When the DB stores the Hebrew form, English mode should show "Limud".
      expect(
        terms.resolveStoredStageName('לימוד'),
        'Limud',
        reason:
            'Hebrew-stored stage 0 should render as "Limud" in English mode',
      );
    });

    test('resolveStoredStageName("Learn") Hebrew mode returns Hebrew', () {
      const terms = DomainTermLabels(true);
      expect(terms.resolveStoredStageName('Learn'), 'לימוד');
    });

    test('resolveStoredStageName("לימוד") Hebrew mode returns Hebrew', () {
      const terms = DomainTermLabels(true);
      expect(terms.resolveStoredStageName('לימוד'), 'לימוד');
    });

    test('resolveStoredStageName custom name is unchanged in both modes', () {
      const termsEn = DomainTermLabels(false);
      const termsHe = DomainTermLabels(true);
      expect(
        termsEn.resolveStoredStageName('My Custom Stage'),
        'My Custom Stage',
      );
      expect(
        termsHe.resolveStoredStageName('My Custom Stage'),
        'My Custom Stage',
      );
    });
  });
}
