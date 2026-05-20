/// Regression test: ensures every B1-tier vocabulary key (Task #13) is
/// present in BOTH `app_en.arb` AND `app_he.arb`.
///
/// If a key were ever removed from one locale but not the other, the
/// generated `AppLocalizations` would silently fall back to English — the
/// Hebrew Terms toggle would still appear to work because
/// `domain_term_labels.dart` carries the Hebrew string inline, but any
/// screen that pulls the same label through l10n directly would see the
/// wrong value. This test pins the ARB-side contract.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Vocabulary keys added by Task #13 (Vocabulary sweep). The list is the
/// authoritative source — adding a new B1-vocab key requires updating
/// this list AND both ARB files.
const _b1VocabKeys = <String>[
  // Tier lens labels + counters
  'tierLensRecentActivity',
  'tierLensSiyumimMilestones',
  'tierLensLifetimeKnowledge',
  'tierCounterStreakDays',
  'tierCounterSiyumimEarned',
  'tierCounterLifetimeItems',
  'tierCounterPoints',

  // Concept vocabulary (singular + plural)
  'limud',
  'chazara', // pre-existing key — still required in both locales
  'chazaros',
  'siyum',
  'siyumim',
  'milestone',
  'milestoneAggregate',
  'trackProgress',
  'lifetimeLabel',
  'recentActivityShort',
  'today',
  'streakLabel',
  'itemsLearnedCount',
  'totalChazaros',

  // Per-curriculum siyum labels (top + mid + unit)
  'siyumHaShas',
  'siyumHaTorah',
  'siyumHaMishnayos',
  'siyumHaYerushalmi',
  'siyumMishnaBerurah',
  'siyumMishnehTorah',
  'siyumNach',
  'siyumTanach',
  'siyumMussar',
  'siyumSeder',
  'siyumChelek',
  'siyumMasechta',
  'siyumSefer',
  'siyumSiman',
  'siyumHilchos',

  // Wave-5 copy (bulk-mark wizard + lifetime marking)
  'bulkMarkWizardSubtitle',
  'bulkMarkConfirmationToast',
  'lifetimeMarkingSubtitle',
  'recentActivityLiveOnlyDisclaimer',
];

Map<String, dynamic> _loadArb(String locale) {
  final file = File('lib/l10n/app_$locale.arb');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'ARB file for locale "$locale" must exist at ${file.path}',
  );
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('B1-tier vocabulary keys (Task #13) — present in both ARBs', () {
    late final Map<String, dynamic> enArb;
    late final Map<String, dynamic> heArb;

    setUpAll(() {
      enArb = _loadArb('en');
      heArb = _loadArb('he');
    });

    for (final key in _b1VocabKeys) {
      test('$key — present in app_en.arb', () {
        expect(
          enArb.containsKey(key),
          isTrue,
          reason: 'Key "$key" must exist in app_en.arb',
        );
        final value = enArb[key];
        expect(
          value is String && value.isNotEmpty,
          isTrue,
          reason:
              'Key "$key" in app_en.arb must be a non-empty string '
              '(got ${value.runtimeType}: $value)',
        );
      });
      test('$key — present in app_he.arb', () {
        expect(
          heArb.containsKey(key),
          isTrue,
          reason: 'Key "$key" must exist in app_he.arb',
        );
        final value = heArb[key];
        expect(
          value is String && value.isNotEmpty,
          isTrue,
          reason:
              'Key "$key" in app_he.arb must be a non-empty string '
              '(got ${value.runtimeType}: $value)',
        );
      });
    }
  });

  group('B1-tier vocabulary — placeholder shape parity (en vs he)', () {
    // For any key that has a `@<key>.placeholders` block in en, the he
    // block must declare the same placeholder names (so the generated
    // signature matches). If a key has no @-block in en, neither locale
    // should declare one.
    late final Map<String, dynamic> enArb;
    late final Map<String, dynamic> heArb;

    setUpAll(() {
      enArb = _loadArb('en');
      heArb = _loadArb('he');
    });

    for (final key in _b1VocabKeys) {
      test('$key — placeholders match across locales', () {
        final enMeta = enArb['@$key'] as Map<String, dynamic>?;
        final heMeta = heArb['@$key'] as Map<String, dynamic>?;
        // If neither locale defines placeholders, we're done — it's a
        // simple string key.
        final enPh = enMeta?['placeholders'] as Map<String, dynamic>?;
        final hePh = heMeta?['placeholders'] as Map<String, dynamic>?;
        if (enPh == null && hePh == null) return;
        expect(
          enPh,
          isNotNull,
          reason:
              'Key "$key" declares placeholders in he but not in en — '
              'add `@$key.placeholders` to app_en.arb',
        );
        expect(
          hePh,
          isNotNull,
          reason:
              'Key "$key" declares placeholders in en but not in he — '
              'add `@$key.placeholders` to app_he.arb',
        );
        expect(
          hePh!.keys.toSet(),
          equals(enPh!.keys.toSet()),
          reason:
              'Key "$key" placeholder names differ across locales: '
              'en=${enPh.keys.toSet()} he=${hePh.keys.toSet()}',
        );
      });
    }
  });
}
